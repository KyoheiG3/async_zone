# tanstack_query_sample

A Flutter sample app that mirrors `reference/expo-react-query-sample` by combining [`tanstack_query`](https://pub.dev/packages/tanstack_query) (state management) with `async_zone` (Suspense-style fallback) and `error_boundary` (error fallback).

## Concept mapping

- `useSuspenseQuery` → `useAsyncZoneQuery` — a small bridge hook in [lib/use_async_zone_query.dart](lib/use_async_zone_query.dart) that wraps `useQuery` and:
  - returns `query.data` when available,
  - throws `query.error` (caught by `ErrorBoundary`) on error,
  - throws a `Completer.future` (caught by `AsyncZone`) while loading.
- `<Suspense fallback>` → `AsyncZone(fallback: ...)`
- `<ErrorBoundary>` → `ErrorBoundary` (from this repo)
- `QueryClient` / `QueryClientProvider` → same names from `tanstack_query`

## How `useAsyncZoneQuery` works

The bridge in [lib/use_async_zone_query.dart](lib/use_async_zone_query.dart) is small but every line is load-bearing — this section explains why.

### Why we have to construct a future at all

`useQuery` doesn't expose a `Future` you can throw — it returns a `QueryResult` whose `data` / `error` / `isError` fields are populated reactively as the underlying fetch progresses. To suspend, `AsyncZone` needs a `Future<T>` that completes when the query reaches a terminal state. The bridge constructs one by listening to the `QueryCache` (the source of truth for query state) and completing a one-shot `Completer<T>` from there.

Subscribing to the cache — rather than trying to hang anything off the hook — keeps the bridge independent of how `useQuery`'s internal state evolves across a build that throws: the listener lives on a top-level singleton, fires once when the cache reflects a terminal state for our `cacheKey`, and self-unsubscribes.

### The shape of the hook

```dart
final query = useQuery<T>(queryKey: queryKey, queryFn: queryFn);

if (query.isError) throw query.error!;        // → ErrorBoundary
if (query.data != null) {
  return (data: query.data as T, query: query); // happy path
}

final client = useQueryClient();
throw _completerForQuery<T>(client.queryCache, query.key).future; // → AsyncZone
```

Three branches in order: error, data, otherwise suspend. The terminal-state checks (`isError`, `data != null`) match what the cache listener also checks, so the bridge stays consistent whether the query is resolved on first build or resolved later via the cache.

`useQuery` is still called on every build — that's what starts the fetch on first build and re-evaluates the cached query state on every subsequent rebuild. The returned `query` object is also handed back to callers so they can use `refetch`, `isFetching`, etc.

### `_completerForQuery` line-by-line

```dart
final c = Completer<T>();
late final void Function() unsubscribe;
void settle() => scheduleMicrotask(unsubscribe);
```

A fresh `Completer` per call. `cache.subscribe(listener)` returns the unsubscribe closure, so we capture it as `late` and call it via `settle()`. The `scheduleMicrotask` defer is important: the listener may fire while the cache is iterating its subscribers, and unsubscribing synchronously would mutate that collection mid-loop. Deferring to a microtask runs the removal after the current notify pass.

```dart
void listener(QueryCacheNotifyEvent event) {
  if (c.isCompleted) return settle();
  if (event.cacheKey != cacheKey) return;
  final res = event.entry?.result;
  if (res is! QueryResult) return;
  if (res.isError) {
    c.completeError(res.error ?? Exception('Query failed'));
    settle();
  } else if (res.data != null) {
    c.complete(res.data as T);
    settle();
  }
}
unsubscribe = cache.subscribe(listener);
```

- `if (c.isCompleted) return settle()` — defensive: a stray notification after the completer is done just unsubscribes again (idempotent).
- `if (event.cacheKey != cacheKey) return` — the cache emits for **every** query; we only care about events for *our* `cacheKey`.
- `if (res is! QueryResult) return` — the entry may exist without a result yet (e.g. just-created entries); wait for a real result.
- The same `isError` / `data != null` checks as the hook body, so a terminal state always resolves the completer exactly once.
- `c.completeError(res.error ?? Exception('Query failed'))` — `error` is nullable on the result type, so we fall back to a generic exception to ensure the surrounding `ErrorBoundary` always sees something.
- The listener **self-removes** after firing. The completer is one-shot, and any subsequent rebuild goes through `useQuery` directly (which will see `data` synchronously from the cache).

### Why `gcTime` matters

`gcTime` is left at the default (5 min in this sample) so completed query results stay in the cache long enough for the bridge to receive the terminal-state notification and for the next rebuild to read the cached `data` synchronously. Setting `gcTime: 0` makes the query eligible for GC the moment its observer count drops, which can race with the listener — any non-zero `gcTime` larger than a typical fetch avoids the race.

## Run

```sh
flutter pub get
flutter run
```
