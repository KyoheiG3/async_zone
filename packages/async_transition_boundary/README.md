# async_transition_boundary

**English** | [日本語](README.ja.md)

A Flutter package that brings React `useTransition`-style transitions to [async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone). Wrap a subtree with `TransitionBoundary` to keep its previous content visible while a new asynchronous state is being prepared, instead of flashing the surrounding `AsyncZone` fallback.

## Overview

`TransitionBoundary` brings `useTransition`-style updates to Flutter: the previous UI stays visible while the new state suspends, instead of flashing a fallback. Wrap a subtree once, then trigger a transition from any descendant via `TransitionZone.of(context)`. `startTransition` automatically tracks both descendant suspends and `Future`-returning actions (such as `compute()`), and any descendant can read the `isPending` flag to dim, label, or disable the in-flight subtree.

## Installation

```bash
flutter pub add async_transition_boundary
```

Or add it manually to your `pubspec.yaml`:

```yaml
dependencies:
  async_transition_boundary:
```

Then run:

```bash
flutter pub get
```

## Quick Start

Place `TransitionBoundary` **above any `ZoneWidget` that should freeze during the transition**. While a transition is active, suspending descendants are tracked by the boundary instead of firing the surrounding `AsyncZone` fallback — the previous subtree stays visible.

Typically you put `TransitionBoundary` above `AsyncZone` with the trigger between them. This isn't a technical requirement (the bridge lookup only cares about the `ZoneWidget` relationship), but it keeps the trigger outside the `AsyncZone` fallback target — useful for fresh mounts and `ErrorBoundary` retries, where the transition can't extend over a not-yet-committed subtree and the `AsyncZone` fallback does fire as usual. The trigger stays mounted and can observe `scope.isPending` to disable a button or dim the in-flight view:

```dart
import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:async_transition_boundary/async_transition_boundary.dart';

class ProfileSwitcher extends StatefulWidget {
  const ProfileSwitcher({super.key});

  @override
  State<ProfileSwitcher> createState() => _ProfileSwitcherState();
}

class _ProfileSwitcherState extends State<ProfileSwitcher> {
  int _id = 1;

  @override
  Widget build(BuildContext context) {
    return TransitionBoundary(
      child: Builder(
        builder: (context) {
          final scope = TransitionZone.of(context);
          return Column(children: [
            AsyncZone(
              fallback: const CircularProgressIndicator(),
              child: ProfileCard(userId: _id), // a ZoneWidget that suspends on fetch
            ),
            ElevatedButton(
              onPressed: () => scope.startTransition(() {
                setState(() => _id++);
              }),
              child: Text(scope.isPending ? 'Loading…' : 'Next'),
            ),
          ]);
        },
      ),
    );
  }
}
```

`TransitionZone.of(context)` resolves the nearest enclosing `TransitionBoundary` via `InheritedWidget`, so it can be called from any descendant build context — there is no need to capture the scope in an outer build and pass it down. Use `TransitionZone.maybeOf(context)` when the boundary may be absent.

## Core Concepts

### How a transition works

`TransitionBoundary` collaborates with `async_zone` through the `TransitionZoneBridge` interface that `async_zone` exports. When a descendant `ZoneWidget` throws a `Future` during a transition, the bridge:

1. Registers the future with the in-flight transition.
2. Keeps the previously committed subtree on screen instead of falling back to the `AsyncZone` fallback.
3. Flips `isPending` to `true` while at least one tracked future is unresolved, and back to `false` once everything settles.

The lookup only requires `TransitionBoundary` to be above the `ZoneWidget`; placing it above `AsyncZone` is a UX convention so the trigger stays outside the `AsyncZone` fallback target.

### Auto-tracking async actions

When `action` itself returns a `Future` (typically by being declared `async`), `startTransition` automatically tracks it. This keeps `isPending` true across explicit asynchronous work — for example heavy preparation routed through `compute()` — without needing a descendant `ZoneWidget` to suspend:

```dart
scope.startTransition(() async {
  final data = await api.fetchUser(id);
  final result = await compute(_expensiveTransform, data);
  setState(() => _data = result);
});
```

### `forceSameFrameRebuild`

By default, `isPending` surfaces **one frame after** the transition starts: the boundary rebuilds on the next frame, the suspending future lands in the tracked set, and a post-frame callback flips `isPending`. The extra frame is conservative and rarely visible.

Pass `forceSameFrameRebuild: true` to force dirty descendants to build synchronously during the boundary's rebuild — futures land in the tracked set before the same-frame settle, so `isPending` flips in the very frame the transition starts:

```dart
TransitionBoundary(
  forceSameFrameRebuild: true,
  child: ...,
)
```

Enable it opt-in only when the extra frame is visually noticeable; the synchronous walk does more work per transition start.

## Advanced Usage

### Behavior notes

- **`isPending` only surfaces when there is actual work to wait on.** A no-op transition — one where no descendant `ZoneWidget` throws and `action` does not return a `Future` — ends silently without a one-frame flicker.
- **Rapid same-target updates auto-supersede.** When a descendant `ZoneWidget` rebuilds with a new future, the bridge releases the previous one and tracks the new one. `isPending` reflects the latest work, not the union of overlapping calls. Futures themselves are not cancelled — see *Lifecycle*.
- **Async-action futures are merged, not superseded.** When `action` returns a `Future`, overlapping `startTransition` calls keep all of them tracked until each one resolves. Cancellation of in-flight async work is the caller's responsibility.
- **No `useDeferredValue` equivalent.** Flutter's renderer is synchronous, so there is no render interruptibility. Offload heavy CPU work via `compute()` / `Isolate.run`, and compose state + effects for deferred-value semantics.

### Nested `startTransition`

A `startTransition` call while a transition is already in progress is collapsed into the outer one: the inner action runs synchronously and any future it produces is tracked on the existing transition. There is no separate inner transition state.

### Fresh mount falls back

When the suspending element has no previously committed build — an `ErrorBoundary` that just swapped back to children after retry, a freshly inserted route, the very first build of a newly mounted `AsyncZone` — there is nothing to extend over. The suspending future falls through to the surrounding `AsyncZone` fallback as a normal Suspense render.

### Lifecycle

- **Pending futures are not cancelled on unmount.** Dart's `Future` has no cancel primitive. The bridge stops tracking outstanding futures when the boundary unmounts, but the underlying work (HTTP request, file I/O, etc.) keeps running. Use `CancelableOperation` from `package:async` if you need true cancellation.
- **Combine with hooks.** To use hooks (e.g. `useState`) inside a transition, wrap the hook-using widget with `TransitionBoundary` and read the scope via `TransitionZone.of(context)` from any descendant.

## API Reference

### TransitionBoundary

| Property                | Type     | Description                                                                                 |
| ----------------------- | -------- | ------------------------------------------------------------------------------------------- |
| `child`                 | `Widget` | The subtree placed inside this transition scope.                                            |
| `forceSameFrameRebuild` | `bool`   | When `true`, surfaces `isPending` in the same frame the transition starts. Default `false`. |

### TransitionZone

Namespace for looking up the surrounding scope. Not instantiable.

- `TransitionZone.of(context)` — returns the `TransitionZoneScope` from the nearest enclosing `TransitionBoundary`. Subscribes `context` to `isPending` changes. Throws a `FlutterError` when no boundary is present.
- `TransitionZone.maybeOf(context)` — same as `of`, but returns `null` when no boundary is present.

### TransitionZoneScope

The scope returned by `TransitionZone.of`.

- `bool get isPending` — `true` while at least one future tracked by the in-flight transition is unresolved.
- `void startTransition(FutureOr<void> Function() action)` — runs `action` synchronously inside the transition. State updates become visible on the next build; futures thrown by descendant `ZoneWidget`s, and a `Future` returned by `action` itself, are tracked automatically.

## Related Packages

- [async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone) — Declarative async operations and error boundaries (exports the `TransitionZoneBridge` / `TransitionZoneProvider` interface this package implements)
- [async_error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_error_boundary) — Declarative error handling
- [hooks_async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/hooks_async_zone) — `flutter_hooks` integration for `async_zone`

## License

This project is licensed under the BSD 3-Clause License — see the [LICENSE](LICENSE) file for details.

## Inspiration

This package is inspired by React's `useTransition` hook, which keeps previous UI on screen while a new state suspends.
