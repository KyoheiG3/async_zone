## 0.1.0

Initial release.

### Features

- `HookZoneWidget` and `StatefulHookZoneWidget` base classes, plus the inline `HookZoneBuilder`, that combine `HookElement` and `ZoneElement` in a single widget — no need to hand-roll a custom `Element` to use `flutter_hooks` alongside `async_zone`.
- `useAsyncZone()` hook that returns the surrounding `AsyncZoneScope`, so `zone.use(future)` can be called inside conditionals, loops, or after early returns (mirroring React's `use()` semantics rather than the Rules of Hooks).
- Sliver-shaped variants `SliverHookZoneWidget`, `SliverStatefulHookZoneWidget`, and `SliverHookZoneBuilder` for hook-enabled suspending widgets that must live directly inside a `CustomScrollView`.
- `HookErrorZoneWidget<T>` and `StatefulHookErrorZoneWidget<T>` base classes for writing React-style error zones with hooks (`getDerivedStateFromError`, `componentDidCatch`, `resetErrorBoundary`, `showErrorBoundary`).
- Element classes (`HookZoneElement`, `StatefulHookZoneElement`, sliver counterparts, and the hook error zone elements) are exported so consumers can extend them when composing with additional element mixins.

### Documentation

- Bilingual README (English / Japanese) with hook usage examples and a side-by-side comparison against hand-rolling a `HookElement` + `ZoneElement` widget.
