# AsyncZone Design Specification

**English** | [日本語](DESIGN.ja.md)

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
│   ├── frozen_future.dart   # Future wrapper that signals freeze opt-in
│   ├── zone.dart            # Public API
│   ├── zone_provider.dart   # InheritedWidget & Element
│   └── zone_scope.dart      # Interface definitions
├── error/                   # Error Boundary implementation
│   ├── zone.dart            # Base classes for ErrorZoneWidget
│   ├── zone_element.dart    # ErrorZoneElement mixin
│   ├── zone_controller.dart # State management controller
│   └── zone_provider.dart   # Error propagation provider
├── foundation/
│   └── empty.dart           # Empty widget for placeholder
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

> **Note:** For simpler error boundary implementation, check out the separate [error_boundary](https://pub.dev/packages/error_boundary) package.

### 4. Freeze Mechanism (transition-style swap)

`AsyncZoneScope.use()` accepts an opt-in `freeze: true` flag. With it set, the AsyncZone keeps the previously rendered subtree on screen while the new future is pending, instead of swapping in the fallback. It is the closest Flutter equivalent to React 19's `useTransition` fallback suppression.

**Why a faithful port isn't possible.** React's transition behavior relies on its **render / commit separation** — a low-priority render can keep building the new tree in the background while the previously committed UI stays on screen, and React only commits the new tree once the suspension resolves. Flutter's build phase is synchronous and tightly coupled to commit; there is no notion of "build invisibly in the background". The simplification used here is therefore: **don't try to build a new subtree at all while frozen — just block the swap.**

**Implementation.**

- `FrozenFuture<T>` (in `async/frozen_future.dart`) wraps a `Future<T>` and is thrown by `use()` when `freeze: true`. It implements `Future<T>` so existing `on Future catch` handlers still pick it up; `ZoneElement` distinguishes it via a more specific `on FrozenFuture catch` clause and propagates the flag down to `AsyncZoneProviderScope.showFallback(future, freeze: true)`.
- `AsyncZoneProviderElement._tasks` is a `Map<Future, bool>` tracking the freeze flag per pending future.
- `AsyncZoneProviderElement.updateChild` returns the existing child element (skipping `super.updateChild`) whenever any task has `freeze == true`. That short-circuit is what keeps the old UI on screen.

**Limitations.**

- `isPending` cannot be reflected within the same frame as the trigger. The freeze flag is set during the very build that throws the future, so any widget upstream that would react to it has already built using the old value. (React's `useTransition` avoids this by committing `isPending = true` on a higher-priority lane *before* the transition begins.)
- Top-down propagation is blocked while frozen. Keeping the old subtree visible requires that no new widget configuration descends through the `AsyncZone`. `Listenable`-driven rebuilds inside the subtree still fire, but a suspending widget cannot update its display until the future resolves.
- Caching layers usually solve the same UX better. Libraries such as Riverpod or fquery expose previous data and `isFetching` flags directly, with no need for build-time freezing. The freeze flag is mainly useful for Suspense-pure architectures or simple cases — see the README for an example pattern (`useFreezing`).

## API Design

### AsyncZone

```dart
AsyncZone(
  allowParallelBuilds: true,
  fallback: LoadingWidget(),
  child: MyWidget(),
)

// Access from descendants
final zone = AsyncZone.of(context);
final data = zone.use(fetchData());
```

### ErrorZoneWidget

```dart
class MyErrorZone extends ErrorZoneWidget<({Object? error})> {
  const MyErrorZone({super.key, required this.child});

  final Widget child;

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
    if (state.error != null) {
      return ErrorView(
        error: state.error,
        onRetry: resetErrorBoundary,
      );
    }
    return child;
  }
}
```

### ZoneWidget

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    throw fetchData();  // Suspend until complete
  }
}

// With custom error handling
class MyErrorWidget extends ErrorZoneWidget<MyState> {
  @override
  MyState getDerivedStateFromError(Object? error) => MyState(error: error);

  @override
  Widget build(BuildContext context) {
    return state.error != null ? ErrorView() : NormalView();
  }
}
```

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
- **Double rebuild**: Immediate state reflection (see FAQ Q6)
- **Parallel builds**: Control with `allowParallelBuilds`

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
