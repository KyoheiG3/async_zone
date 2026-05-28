# stateful_zone_sample

A Flutter sample app that demonstrates `async_zone`, `async_error_boundary`, and `transition_boundary` working together using plain `StatefulZoneWidget` — **no `flutter_hooks` dependency**.

## What it shows

The same user-card demo as [`async_zone_sample`](../async_zone_sample) (Prev / Next / Force error against `https://dummyjson.com/users/{id}`), rewritten with vanilla `StatefulWidget`:

- `AsyncZone` shows a `CircularProgressIndicator` fallback during the initial fetch.
- `TransitionBoundary` + `Opacity` keeps the previous user visible (dimmed) on subsequent fetches, instead of falling back to the spinner.
- `ErrorBoundary` swaps in an error card on failure with a **Retry** button.

## Pieces involved

- **`StatefulZoneWidget`** ([lib/main.dart](lib/main.dart)) — the no-Hooks entry point into the zone. The `State` builds normally; calling `AsyncZone.of(context).use(future)` inside `build` suspends until the future resolves.
- **`AsyncZone(fallback: ...)`** — Suspense-style boundary; awaits any `Future` thrown during build of a descendant and shows `fallback` until it resolves.
- **`ErrorBoundary`** — catches errors thrown during build, including errors that propagate out of `AsyncZone` when a suspended `Future` rejects, and renders an error UI; `onReset` re-issues the fetch.
- **`TransitionBoundary` + `TransitionZone.of(context).startTransition(...)`** — wraps the `setState` that swaps the future; `isPending` is `true` while the new future is in flight, which `Opacity` uses to dim the stale content.

This sample is the no-Hooks counterpart of [`async_zone_sample`](../async_zone_sample); see [`sliver_zone_sample`](../sliver_zone_sample) for the same idea inside a `CustomScrollView` with `SliverStatefulZoneWidget`.

## Run

```sh
flutter pub get
flutter run
```
