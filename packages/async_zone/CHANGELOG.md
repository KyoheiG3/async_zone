## 0.1.0

Initial release.

### Features

- `AsyncZone` widget that renders a fallback while descendants are suspended on a pending `Future`, inspired by React Suspense. Exposes `alignment` and `fit` to control the internal `Stack` layout.
- `ZoneWidget` and `StatefulZoneWidget` base classes, plus the inline `ZoneBuilder`, for using `AsyncZone.of(context).use(future)` during build.
- `AsyncZone.of` throws a descriptive `FlutterError` both when no `AsyncZone` ancestor exists and when called from an element that does not mix in `ZoneElement`.
- Identity-based caching: repeated `use()` calls with the same `Future` instance return the resolved value without re-suspending, and entries are reclaimed automatically when the future is no longer referenced.
- Pending futures are superseded when the calling element rebuilds with a new future or is unmounted, so stale completions never replace fresh results.
- Sliver-shaped variants `SliverZoneWidget`, `SliverStatefulZoneWidget`, and `SliverZoneBuilder`, plus the `SliverZoneElementMixin` for composing custom sliver elements with `ZoneElement`.
- Low-level `ErrorZoneWidget` / `StatefulErrorZoneWidget` base classes with React-style `getDerivedStateFromError`, `componentDidCatch`, `resetErrorBoundary`, and `showErrorBoundary`, plus the `ErrorBoundaryMixin` and `ErrorZoneElement` for composing the lifecycle into custom widgets.
- Errors thrown inside an inner error zone's fallback (or by `ZoneWidget` descendants of that fallback) escalate to the next outer error zone, mirroring React's error boundary semantics.
- `TransitionZoneBridge` / `TransitionZoneProvider` bridge interface that lets external coordinators (such as the companion `async_transition_boundary` package) keep the previous subtree visible while a new state suspends.

### Documentation

- Bilingual README (English / Japanese), architecture overview, and dartdoc with runnable examples for every public API.
