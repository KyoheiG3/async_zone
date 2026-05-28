# fquery_sample

A Flutter sample app that mirrors `reference/expo-react-query-sample` by combining [`fquery`](https://pub.dev/packages/fquery) (state management) with `async_zone` (Suspense-style fallback) and `async_error_boundary` (error fallback).

## Concept mapping

- `useSuspenseQuery` → `useAsyncZoneQuery` — a small bridge hook in [lib/use_async_zone_query.dart](lib/use_async_zone_query.dart) that wraps `useQuery` and:
  - returns `query.data` when available,
  - throws `query.error` (caught by `ErrorBoundary`) on error,
  - throws a `Completer.future` (caught by `AsyncZone`) while loading.
- `<Suspense fallback>` → `AsyncZone(fallback: ...)`
- `<ErrorBoundary>` → `ErrorBoundary` (from this repo)
- `QueryClient` / `QueryClientProvider` → `QueryCache` / `CacheProvider`

## How `useAsyncZoneQuery` works

The bridge in [lib/use_async_zone_query.dart](lib/use_async_zone_query.dart) is small but every line is load-bearing — this section explains why.

### Why we have to construct a future at all

`useQuery` doesn't expose a `Future` you can throw — it returns a `QueryResult` whose `data` / `error` / `isError` fields are populated reactively as the underlying fetch progresses. To suspend, `AsyncZone` needs a `Future<T>` that completes when the query reaches a terminal state. The bridge constructs one by listening to the `QueryCache` (the source of truth for query state) and completing a one-shot `Completer<T>` from there.

Subscribing to the cache — rather than trying to hang anything off the hook — keeps the bridge independent of how `useQuery`'s internal state evolves across a build that throws: the listener lives on a top-level singleton, fires once when the cache reflects a terminal state for our `queryKey`, and self-unsubscribes.

### The shape of the hook

```dart
final query = useQuery<T, E>(queryKey, queryFn, context: ctx);

if (query.isError) throw query.error!;     // → ErrorBoundary
if (query.data != null) {
  return (data: query.data!, query: query); // happy path
}

final cache = CacheProvider.get(ctx);
throw _completerForQuery<T, E>(cache, QueryKey(queryKey)).future; // → AsyncZone
```

Three branches in order: error, data, otherwise suspend. The terminal-state checks (`isError`, `data != null`) match what the cache listener also checks, so the bridge stays consistent whether the query is resolved on first build or resolved later via the cache.

`useQuery` is still called on every build — that's what kicks off the fetch on first build and re-evaluates the cached query state on every subsequent rebuild. The returned `query` object is also handed back to callers so they can use `refetch`, `isFetching`, etc.

### `_completerForQuery` line-by-line

```dart
final c = Completer<T>();
final subId = identityHashCode(c);
```

Each call gets a fresh `Completer` and a unique `subId`. Using `identityHashCode(c)` ties the subscription's lifetime to the completer object — different calls get different ids, so unrelated listeners don't collide.

```dart
void unsub() => scheduleMicrotask(() => cache.unsubscribe(subId));
```

`unsubscribe` is deferred via `scheduleMicrotask` because the listener may be invoked while the cache is iterating its subscribers. Removing during iteration would mutate the collection mid-loop; deferring to a microtask runs the removal after the current notify pass.

```dart
void listener() {
  if (c.isCompleted) return unsub();
  final q = cache.queries[queryKey];
  if (q == null) return;
  if (q.isError) {
    c.completeError(q.error!);
    unsub();
  } else if (q.data != null) {
    c.complete(q.data as T);
    unsub();
  }
}
cache.subscribe(subId, listener);
```

- `if (c.isCompleted) return unsub()` — defensive: a stray notification after the completer is done just unsubscribes again (idempotent).
- `if (q == null) return` — the cache notifies on any change; the entry for our key may not exist yet, so just wait.
- The same `isError` / `data != null` checks as the hook body, so a terminal state always resolves the completer exactly once.
- The listener **self-removes** after firing. The completer is one-shot, and any subsequent rebuild goes through `useQuery` directly (which will see `data` synchronously from the cache).

### Why `cacheDuration` matters

`cacheDuration` is left at the default (5 min) so completed query results stay in the cache long enough for the bridge to receive the terminal-state notification and for the next rebuild to read the cached `data` synchronously. Setting `cacheDuration: 0` makes the query eligible for GC the moment its subscriber count drops, which can race with the listener — any non-zero `cacheDuration` larger than a typical fetch avoids the race.

## Run

```sh
flutter pub get
flutter run
```
