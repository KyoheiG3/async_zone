## 0.1.0

Initial release.

### Features

- `TransitionBoundary` widget that brings React `useTransition`-style transitions to `async_zone`: while a transition is in flight, the previously committed subtree stays on screen instead of flashing the surrounding `AsyncZone` fallback.
- `TransitionZone.of(context)` / `TransitionZone.maybeOf(context)` for resolving the nearest enclosing boundary's `TransitionZoneScope` from any descendant build context, with the context auto-subscribed so it rebuilds when `isPending` flips.
- `TransitionZoneScope.startTransition(action)` runs `action` synchronously so state changes apply on the very next build, then keeps the transition pending until every `Future` thrown by descendant `ZoneWidget`s resolves.
- `startTransition` automatically tracks `Future`-returning (`async`) actions, so transitions stay pending across explicit async work such as `compute()` without requiring a descendant `ZoneWidget` to suspend.
- `TransitionZoneScope.isPending` flag that descendants can subscribe to in order to dim, label, or disable the in-flight subtree.
- `forceSameFrameRebuild` opt-in on `TransitionBoundary` that force-rebuilds dirty descendants synchronously so `isPending` can flip in the same frame the transition starts, rather than one frame later via a post-frame callback.

### Documentation

- Bilingual README (English / Japanese) covering boundary placement, the `TransitionZoneBridge` collaboration with `async_zone`, auto-tracked async actions, and `forceSameFrameRebuild` trade-offs.
