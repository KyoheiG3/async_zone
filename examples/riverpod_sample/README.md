# riverpod_sample

A Flutter sample app that mirrors `reference/expo-react-query-sample` (and `examples/fquery_sample`) by combining [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) with `async_zone` (Suspense-style fallback) and `error_boundary` (error fallback).

## Concept mapping

- `useSuspenseQuery` → `watchOrSuspend` — a small bridge in [lib/watch_or_suspend.dart](lib/watch_or_suspend.dart) that reads a `FutureProvider`'s `AsyncValue` and:
  - returns `data` + `AsyncData` (so callers see `isLoading` / `isRefreshing` during background refresh) when data is available,
  - throws `error` (caught by `ErrorBoundary`) on `AsyncError`,
  - throws `provider.future` (caught by `AsyncZone`) while `AsyncLoading`.
- `<Suspense fallback>` → `AsyncZone(fallback: ...)`
- `<ErrorBoundary>` → `ErrorBoundary` (from this repo)
- `<Suspense>`-aware widget → `ConsumerZoneWidget` ([lib/consumer_zone_widget.dart](lib/consumer_zone_widget.dart))
- `QueryClient` / `QueryClientProvider` → `ProviderContainer` / `ProviderScope`

## How the pieces fit together

There are two small pieces in this sample. The first one lets a Riverpod `ConsumerWidget` participate in the zone; the second one is the Suspense bridge itself.

### `ConsumerZoneWidget` — Element fusion

[lib/consumer_zone_widget.dart](lib/consumer_zone_widget.dart)

```dart
abstract class ConsumerZoneWidget extends ConsumerWidget {
  const ConsumerZoneWidget({super.key});

  @override
  _ConsumerZoneElement createElement() => _ConsumerZoneElement(this);
}

final class _ConsumerZoneElement extends ConsumerStatefulElement with ZoneElement {
  _ConsumerZoneElement(ConsumerZoneWidget super.widget);
}
```

This is the same fusion pattern that `hooks_riverpod`'s `HookConsumerWidget` uses to combine `HookElement` with Riverpod's `ConsumerStatefulElement` — here we substitute `ZoneElement` instead. The result is an element that:

- knows how to drive `ref.watch` / `ref.read` / `ref.listen` (from `ConsumerStatefulElement`), and
- intercepts `Future`s and errors thrown during build so `AsyncZone` / `ErrorBoundary` can catch them (from `ZoneElement`).

Without this fusion, you would have to choose one or the other — using a plain `ConsumerWidget` would mean nothing catches a thrown `Future`, and using `HookZoneWidget` would mean no `ref` API.

> The `flutter_riverpod` internal `ConsumerStatefulElement` is reached via `package:flutter_riverpod/src/internals.dart` because it is not part of the public API. This is the same workaround that `hooks_riverpod` uses; the `ignore: implementation_imports` comment makes the lint exception explicit.

### `watchOrSuspend` — three branches

[lib/watch_or_suspend.dart](lib/watch_or_suspend.dart)

```dart
({T data, AsyncData<T> asyncData}) watchOrSuspend<T>(
  WidgetRef ref,
  FutureProvider<T> provider,
) {
  final value = ref.watch(provider);
  if (value is AsyncError<T>) throw value.error;        // → ErrorBoundary
  if (value is AsyncData<T>) {
    return (data: value.value, asyncData: value);       // happy path
  }
  throw ref.watch(provider.future);                     // → AsyncZone
}
```

Three branches in order: error, data, otherwise suspend. A few details:

- **Returning `AsyncData` alongside `data`** — `value` is narrowed to `AsyncData<T>`, which carries flags like `isLoading` and `isRefreshing`. Callers use this to render an inline spinner during a background refresh (`ref.invalidate(...)` → stale data + `isLoading: true`) while still showing the previous result. This is the Riverpod equivalent of tanstack/fquery's `query.isFetching`.
- **`throw value.error`** — `value.error` is `Object`, so `ErrorBoundary` always receives a real error (no nullable fallback needed).
- **`throw ref.watch(provider.future)`** — `provider.future` is a `Future<T>` exposed by Riverpod that completes when the provider transitions to a terminal `AsyncValue`. Throwing it lets the enclosing `AsyncZone` await the same completion that `ref.watch(provider)` is reactively tracking.

### Why this can be so much simpler than the fquery / tanstack bridges

Riverpod's `provider.future` is bound to the `ProviderContainer`, not to any one widget — it's a `Future<T>` that completes when the provider itself reaches a terminal `AsyncValue`. Throwing it gives `AsyncZone` exactly the signal it needs to clear the fallback; no external `Completer` is required.

`AsyncZone` also wraps its hidden subtree in `Visibility(visible: false, maintainState: true)`, so the `ref.watch` subscription that will trigger the next rebuild (the one that returns `AsyncData`) stays alive throughout the suspend cycle.

The `fquery` / `tanstack_query` samples don't have an equivalent throwable future — their `useQuery` hooks expose only a reactive `QueryResult` — so those bridges have to construct a `Completer` from cache notifications. Riverpod hands us the future for free.

## Run

```sh
flutter pub get
flutter run
```
