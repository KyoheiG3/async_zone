# AsyncZone Design Specification

**English** | [日本語](ARCHITECTURE.ja.md)

## Overview

AsyncZone is a Flutter library that provides React Suspense-like async handling and Error Boundary functionality. It allows throwing `Future` objects from the build method and catching them at a higher level to display fallback UI while loading.

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────┐
│                     Application                         │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐    │
│  │      ErrorZoneWidget (ErrorBoundary)            │    │
│  │  ┌───────────────────────────────────────────┐  │    │
│  │  │       AsyncZone (Suspense)                │  │    │
│  │  │  ┌─────────────────────────────────────┐  │  │    │
│  │  │  │        ZoneWidget                   │  │  │    │
│  │  │  │  - Throws Future from build()       │  │  │    │
│  │  │  │  - Handles async operations         │  │  │    │
│  │  │  └─────────────────────────────────────┘  │  │    │
│  │  └───────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Module Structure

```
lib/src/
├── async/                   # AsyncZone (Suspense) implementation
│   ├── zone.dart            # Public API
│   ├── zone_provider.dart   # InheritedWidget & Element
│   └── zone_scope.dart      # Interface definitions
├── error/                   # Error Boundary implementation
│   ├── zone.dart            # Base classes for ErrorZoneWidget
│   ├── zone_element.dart    # ErrorZoneElement mixin
│   ├── zone_controller.dart # State management controller
│   └── zone_provider.dart   # Error propagation provider
├── foundation/
│   ├── empty.dart           # Empty widget for placeholder (box)
│   └── sliver_empty.dart    # Empty sliver for placeholder
├── transition/              # Transition integration surface (bridge only)
│   ├── zone_provider.dart   # TransitionZoneProvider (InheritedWidget)
│   └── zone_scope.dart      # TransitionZoneBridge interface
├── sliver_zone.dart         # Sliver-shaped ZoneWidget variants & mixin
├── zone_element.dart        # ZoneElement base
└── zone.dart                # ZoneWidget base
```

## Design Patterns

### 1. Async Handling (Suspense-like)

Widgets throw `Future` objects, which are caught by `ZoneElement` and handled by parent `AsyncZone`.

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    throw fetchData(); // Suspend until Future completes
  }
}
```

**Key mechanism**: ZoneElement catches thrown Futures, notifies AsyncZone to show fallback, and rebuilds when complete.

### 2. Cache Management with Expando

Uses weak references for automatic garbage collection:

```dart
final _cache = Expando<Object>('AsyncZone cache');
final _errors = Expando<Object>('AsyncZone errors');
```

**Benefits**:

- Automatic GC when Future is no longer referenced
- No memory leaks
- No manual cleanup needed

**Tradeoff**: Cannot manually clear cache (by design).

### 3. Custom Error Zones

Create custom error handling with React-like lifecycle methods:

```dart
class MyErrorZone extends ErrorZoneWidget<({Object? error})> {
  @override
  void componentDidCatch(Object error, StackTrace stackTrace) {
    log(error);
  }

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  Widget build(BuildContext context) {
    return state.error != null ? ErrorView(state.error) : child;
  }
}
```

**Controller Pattern**: Widget holds controller (ephemeral), Element attaches to it (persistent).

> **Note:** For simpler error boundary implementation, check out the separate [error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/error_boundary) package.

### 4. Sliver-Shaped Variants

`AsyncZone` is a box widget (its element wraps the child in `Stack`/`Visibility`), but a suspending widget may need to render a `RenderSliver` to live inside a `CustomScrollView`. Sliver-shaped variants — `SliverZoneWidget`, `SliverStatefulZoneWidget`, `SliverZoneBuilder` — return slivers from `build()` while still mixing in `ZoneElement`.

**Implementation.**

- `ZoneElement.emptyPlaceholder` is a protected getter, default `const Empty()`. It is returned only when an exception has been routed to a fallback this frame.
- `SliverZoneElementMixin on ZoneElement` overrides it to `const SliverEmpty()`, a leaf `RenderSliver` with `SliverGeometry.zero`.
- `StatelessSliverZoneElement` / `StatefulSliverZoneElement` mix in the override; external packages (e.g. `hooks_async_zone`, custom `ConsumerStatefulElement` combinations) reuse the same mixin to obtain sliver-shaped placeholders.

The boundary itself stays box-shaped: any error boundary (`ErrorBoundary`, `ErrorZoneWidget`) and the enclosing `AsyncZone` are placed in box context (outside or above the `CustomScrollView`). Granular sliver-level error boundaries are not provided.

### 5. Transition Integration

The `transition` module exposes only an integration surface — `TransitionZoneBridge` (the contract) and `TransitionZoneProvider` (the `InheritedWidget` that publishes a bridge to descendants). `ZoneElement` consults these during build to coordinate with any active transition coordinator above it.

**Integration with `ZoneElement`.**

- During build, `ZoneElement` looks up the closest bridge via `TransitionZoneProvider.maybeOf(context)`.
- When a descendant throws a future, `ZoneElement` consults `bridge.inTransition`. If `true` and a prior committed build exists, the future is forwarded to `bridge.track(future)` instead of routing to the surrounding `AsyncZone` fallback — preserving the previous subtree.
- On future replacement (e.g. a state change swaps the suspending future before the old one resolved), `ZoneElement` calls `bridge.supersede(oldFuture)` to drop it from tracking. The future itself is never cancelled.
- `ZoneElement._hasCommittedBuild` gates the transition extension: while `false` (fresh mount), the suspending future falls through to the `AsyncZone` fallback as a normal Suspense render — mirrors React's downgrade-to-Suspense behavior when there is no prior subtree to preserve.

> **Note:** `async_zone` doesn't ship a transition coordinator itself. For React `useTransition`-style transitions that keep the previous subtree visible while a new state suspends, see the separate [transition_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/transition_boundary) package.

## Public API at a glance

| Type                  | Role                                                                  |
| --------------------- | --------------------------------------------------------------------- |
| `AsyncZone`           | Boundary widget; shows `fallback` while descendants suspend.          |
| `AsyncZoneScope`      | Returned by `AsyncZone.of(context)`; exposes `use<T>(future)`.        |
| `ZoneWidget`          | `StatelessWidget` whose `Element` mixes in `ZoneElement`.             |
| `StatefulZoneWidget`  | `StatefulWidget` counterpart.                                         |
| `ZoneBuilder`         | Convenience for inline `ZoneWidget` use without subclassing.          |
| `SliverZoneWidget` / `SliverStatefulZoneWidget` / `SliverZoneBuilder` | Sliver-shaped counterparts of the above, for use inside `CustomScrollView`. |
| `SliverZoneElementMixin` | `on ZoneElement` — substitutes `SliverEmpty` for the suspended placeholder; mix in when building custom sliver-shaped elements. |
| `ErrorZoneWidget<T>`  | Custom error boundary with `getDerivedStateFromError` / `componentDidCatch`. |
| `ErrorBoundaryMixin<T>` | Same lifecycle, mixin form for custom widget hierarchies.           |
| `TransitionZoneBridge` | Interface `ZoneElement` calls to extend a transition's lifetime (`track` / `supersede`). Looked up via `TransitionZoneProvider.maybeOf`. |
| `TransitionZoneProvider` | `InheritedWidget` that publishes a `TransitionZoneBridge` to descendants. Implementations such as `TransitionBoundary` (from the `transition_boundary` package) construct it. |

Detailed signatures and end-user examples live in the package README — this
document is intentionally the design counterpart, not the API reference.

## Error Handling Strategy

| Scenario             | Has ErrorZoneWidget? | Behavior                                         |
| -------------------- | -------------------- | ------------------------------------------------ |
| Sync error           | Yes                  | Caught by ErrorZoneWidget                        |
| Sync error           | No                   | Rethrow (Flutter handles)                        |
| Async error (Future) | Yes                  | Caught by ErrorZoneWidget after Future completes |
| Async error (Future) | No                   | Stored, thrown on next build                     |

## Performance Considerations

### Memory Management

- **Expando**: Automatic GC prevents memory leaks
- **unmount()**: Clear task references

### Rendering Optimization

- **Skip child updates**: Prevent ErrorWidget flash during loading (see FAQ Q1)
- **Double rebuild**: Immediate state reflection (see FAQ Q5)

### Build Optimization

```dart
// ✅ Good: Reuse Future instances
final _dataFuture = fetchData();
throw _dataFuture;  // Cache hit

// ❌ Bad: Create new Future every build
throw fetchData();  // Cache miss
```

## Frequently Asked Questions (FAQ)

### Q1: Why skip child updates in `updateChild` when tasks are running?

Prevents ErrorWidget from flashing for one frame before AsyncZone shows the fallback.

**Timeline with skip**:

- Frame N: Future thrown → Old child remains (no flash)
- Frame N+1: AsyncZone shows fallback

### Q2: Why call `controller.attach()` on every build?

Element is persistent, but Widget is rebuilt frequently. Each new Widget has a new controller, so Element must re-attach.

**Lifecycle**:

- Element: Created once, lives until unmount
- Widget: New instance on every rebuild

### Q3: Why use `postFrameCallback` instead of calling `markNeedsBuild()` directly?

The child widget calling `showFallback()` is still building. Synchronous `markNeedsBuild()` would cause:

```
setState() or markNeedsBuild() called during build
```

`postFrameCallback` waits until the current frame completes.

### Q4: Why doesn't `use()` cache errors?

**Separation of Concerns**:

- `use()`: Simple cache lookup, throws Future
- `showFallback()`: Complete state management (success + error)

Error caching is `showFallback()`'s responsibility. This makes error handling logic centralized and easier to understand.

### Q5: Why rebuild twice in `performRebuild()`?

To immediately reflect error state changes in the same frame.

**Without double rebuild**: Error → Old UI (1 frame) → Fallback
**With double rebuild**: Error → Fallback (same frame)

This prevents visual delay when errors occur.

### Q6: Why doesn't a transition extend over a fresh mount?

Transition future-handling preserves the previous subtree, so it needs one to preserve. On a fresh mount (an `ErrorBoundary` just swapped back to children after retry, a newly inserted route) the suspending future falls through to the `AsyncZone` fallback as a normal Suspense render. `ZoneElement._hasCommittedBuild` gates this per element.

## Related Patterns

### React Suspense

- Throwing promises from render
- Fallback UI during loading
- Automatic state management

### Flutter Patterns

- **InheritedWidget**: Context propagation
- **Element lifecycle**: Persistent state
- **Mixin composition**: Reusable behaviors

## Conclusion

AsyncZone provides declarative async and error handling in Flutter:

1. **Simplicity**: Throw Future, catch at boundary
2. **Safety**: Automatic memory management
3. **Performance**: Optimized rendering
4. **Composability**: Mix async and error boundaries

The design prioritizes developer experience while maintaining Flutter's performance characteristics.
