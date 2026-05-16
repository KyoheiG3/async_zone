# fquery_sample

A Flutter sample app that mirrors `reference/expo-react-query-sample` by combining [`fquery`](https://pub.dev/packages/fquery) (state management) with `async_zone` (Suspense-style fallback) and `error_boundary` (error fallback).

## Concept mapping

- `useSuspenseQuery` → `useAsyncZoneQuery` — a small bridge hook in [lib/main.dart](lib/main.dart) that wraps `useQuery` and:
  - returns `query.data` when available,
  - throws `query.error` (caught by `ErrorBoundary`) on error,
  - throws a `Completer.future` (caught by `AsyncZone`) while loading.
- `<Suspense fallback>` → `AsyncZone(fallback: ...)`
- `<ErrorBoundary>` → `ErrorBoundary` (from this repo)
- `QueryClient` / `QueryClientProvider` → `QueryCache` / `CacheProvider`

## How the bridge works

`useQuery`'s reactive subscription is tied to the calling widget — when `AsyncZone` swaps the suspended widget out for the fallback, the subscription is disposed. To keep a `Future` alive across the suspend/remount cycle, `useAsyncZoneQuery` subscribes to the `QueryCache` directly (the cache outlives widgets) and completes a memoized `Completer` when the query reaches a terminal state. The listener self-removes after firing.

`cacheDuration` is left at the default (5 min) so the in-flight query survives while the widget is suspended; with `cacheDuration: 0`, the query would be GC'd before its fetch resolved into the cache.

## Run

From the repository root:

```sh
flutter pub get
flutter run -d <device> --target examples/fquery_sample/lib/main.dart
```

Or from this directory:

```sh
flutter run
```
