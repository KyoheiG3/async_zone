# riverpod_sample

A Flutter sample app that mirrors `reference/expo-react-query-sample` (and `examples/fquery_sample`) by combining [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) with `async_zone` (Suspense-style fallback) and `error_boundary` (error fallback).

## Architecture

Two new pieces:

1. **`ConsumerZoneWidget`** ([lib/consumer_zone_widget.dart](lib/consumer_zone_widget.dart)) — a `ConsumerWidget` whose `Element` fuses Riverpod's `ConsumerStatefulElement` with `ZoneElement`. Same fusion pattern that `hooks_riverpod`'s `HookConsumerWidget` uses for `HookElement`, just substituting `ZoneElement`. Inside, `ref.watch` / `ref.read` / `ref.listen` work as usual, and any `Future` or error thrown during build is caught by the surrounding `AsyncZone` / `ErrorBoundary`.
2. **`readOrSuspend`** ([lib/main.dart](lib/main.dart)) — a top-level function (not a hook) that reads the `AsyncValue` of a `FutureProvider` and translates it into:
   - return `value` when `AsyncData`,
   - throw `error` (caught by `ErrorBoundary`) when `AsyncError`,
   - while `AsyncLoading`, throw a `Completer.future` that is bridged to the `ProviderContainer` via `container.listen` and resolves on the next terminal state.

## Why a Completer + container.listen bridge

`ref.watch`'s subscription is tied to the widget — when `AsyncZone` swaps the suspended widget out for the fallback, the `Element` unmounts and `ref.watch` is closed. `provider.future` looks like a tempting shortcut but isn't safe either: Riverpod's default retry policy keeps a single fetch's `provider.future` *pending* for the entire retry window (up to ~52s), and there are subtle cases where it doesn't reject on the first failure even with `retry: null`. To keep the bridge robust regardless of `retry` configuration, `readOrSuspend` instead subscribes to the `ProviderContainer` directly (which outlives widgets) and completes a `Completer` when the `AsyncValue` reaches `AsyncData` or `AsyncError`. The listener self-closes once it fires.

Treating only the terminal `AsyncError` (not `AsyncLoading` mid-retry) as an error means retries — when enabled — are absorbed by the fallback as expected.

`FutureProvider.family` is used without `autoDispose` so the cached data survives between when the fetch completes and when `AsyncZone` rebuilds the (previously unmounted) widget.

## Run

From the repository root:

```sh
flutter pub get
flutter run -d <device> --target examples/riverpod_sample/lib/main.dart
```

Or from this directory:

```sh
flutter run
```
