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

## How the bridge works

`useQuery`'s observer is tied to the calling widget — when `AsyncZone` swaps the suspended widget out for the fallback, the observer is destroyed. To keep a `Future` alive across the suspend/remount cycle, `useAsyncZoneQuery` subscribes to the `QueryCache` directly (the cache outlives widgets) and completes a per-call `Completer` when the cache emits an `added` / `updated` event whose `cacheKey` matches and whose `QueryResult` has reached a terminal state. The listener self-removes after firing.

`gcTime` is left at the default (5 min) so the in-flight query survives while the widget is suspended; with `gcTime: 0`, the query would be GC'd before its fetch resolved into the cache.

## Run

From the repository root:

```sh
flutter pub get
flutter run -d <device> --target examples/tanstack_query_sample/lib/main.dart
```

Or from this directory:

```sh
flutter run
```
