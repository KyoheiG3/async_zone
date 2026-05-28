# sliver_zone_sample

A Flutter sample app that demonstrates the **sliver** flavor of `async_zone` — `SliverStatefulZoneWidget` — inside a `CustomScrollView`, together with `async_error_boundary` and `async_transition_boundary`.

## What it shows

The same user-card demo as [`async_zone_sample`](../async_zone_sample) (Prev / Next / Force error against `https://dummyjson.com/users/{id}`), but the suspending widget is a sliver instead of a box:

- The user card lives inside a `CustomScrollView` as a sliver.
- `AsyncZone` shows a `CircularProgressIndicator` fallback during the initial fetch.
- `TransitionBoundary` + `SliverOpacity` keeps the previous user visible (dimmed) on subsequent fetches, instead of falling back to the spinner.
- `ErrorBoundary` swaps in an error card on failure with a **Retry** button.

## Pieces involved

- **`SliverStatefulZoneWidget`** ([lib/main.dart](lib/main.dart)) — the sliver counterpart of `StatefulZoneWidget`. Its `Element` participates in the zone the same way, so `AsyncZone.of(context).use(future)` works identically inside a sliver build.
- **`AsyncZone(fallback: ...)`** — Suspense-style boundary; awaits any `Future` thrown during build of a descendant (including slivers) and shows `fallback` until it resolves.
- **`ErrorBoundary`** — catches errors thrown during build, including errors that propagate out of `AsyncZone` when a suspended `Future` rejects, and renders an error UI; `onReset` re-issues the fetch.
- **`TransitionBoundary` + `TransitionZone.of(context).startTransition(...)`** — wraps the state updates that swap the future; `isPending` is `true` while the new future is in flight, which `SliverOpacity` uses to dim the stale content.

This sample is the sliver-aware counterpart of [`async_zone_sample`](../async_zone_sample); see [`stateful_zone_sample`](../stateful_zone_sample) for the same idea with a non-sliver `StatefulZoneWidget`.

## Run

```sh
flutter pub get
flutter run
```
