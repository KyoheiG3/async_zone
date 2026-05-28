<img width="1600" height="640" alt="async_zone Logo" src="https://github.com/user-attachments/assets/9b85aa6e-8137-4994-a757-14b0060e4d53" />

# async_zone

**English** | [日本語](README.ja.md)

A Flutter monorepo that brings React's **Suspense**, **Error Boundary**, and **useTransition** primitives to Flutter — declarative async UI without `FutureBuilder` ladders or manual loading-state plumbing.

In React, you `throw` a promise from render to suspend a component, you wrap it in `<Suspense>` to show a fallback, you wrap it in an `<ErrorBoundary>` to recover from errors, and you call `startTransition()` from `useTransition` to keep the previous UI on screen while a new state is being prepared. These four packages give you the same primitives in Flutter — the API surface is intentionally a near-literal mapping:

| React                                                 | This monorepo                                                                                                       |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `<Suspense fallback={...}>`                           | `AsyncZone(fallback: ...)`                                                                                          |
| `use(promise)` (React 19)                             | `AsyncZone.of(context).use(future)` (or `useAsyncZone().use(future)`)                                               |
| `<ErrorBoundary>`                                     | `ErrorBoundary(builder: ..., child: ...)`                                                                           |
| `componentDidCatch` / `getDerivedStateFromError`      | Same names on `ErrorZoneWidget<T>` lifecycle                                                                        |
| `useTransition` / `startTransition`                   | `TransitionBoundary` + `TransitionZone.of(context).startTransition(...)`                                            |
| `useTransition`'s `isPending`                         | `TransitionZone.of(context).isPending`                                                                              |
| React Hooks (`useState`, `useEffect`, ...) + Suspense | [`flutter_hooks`](https://pub.dev/packages/flutter_hooks) + `hooks_async_zone` (`HookZoneWidget`, `useAsyncZone()`) |

Throw a `Future` from a zone-aware widget's `build()` — the enclosing `AsyncZone` shows its fallback, errors propagate to the nearest `ErrorBoundary`, and a surrounding `TransitionBoundary` can hold the previous subtree on screen instead of flashing the fallback. The semantics are React's; only the keyword changes (`Future` instead of `Promise`).

## Limitations and differences from React

The API surface mirrors React's, but Flutter's rendering model is not. Two architectural differences cascade into everything else:

- **No render interruption.** React's `useTransition` can discard a partial render mid-tree — that is concurrent rendering. Flutter renders synchronously, so `TransitionBoundary` _simulates_ the visible part (previous subtree stays on screen, `isPending` flips on) but cannot abandon work that has already started. The same constraint rules out a `useDeferredValue` equivalent — there is no time-slicing to defer onto.
- **No `Future` cancellation.** Dart's `Future` has no cancel primitive. When a suspended subtree unmounts or a transition supersedes an in-flight fetch, the bridge just stops _tracking_ the future — the underlying I/O keeps running. Use `CancelableOperation` from `package:async` if you need real cancellation.

`use(future)` itself is identity-based, same as React's `use(promise)` — pass a stable `Future` instance (`late final`, `useMemoized`, parent state) or it suspends forever. For value-based caching by a query key, layer a state-management library on top; the [`fquery_sample`](examples/fquery_sample) / [`tanstack_query_sample`](examples/tanstack_query_sample) / [`riverpod_sample`](examples/riverpod_sample) examples show small bridges, mirroring React's split between `use()` and TanStack Query / SWR.

## Packages

| Package                                               | Description                                                                                                                                                                   |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`async_zone`](packages/async_zone)                   | Core. `AsyncZone`, `ZoneWidget` / `StatefulZoneWidget` / `SliverZoneWidget` / `ZoneBuilder`, and the `ErrorZoneWidget` lifecycle base. Everything else depends on this.       |
| [`async_error_boundary`](packages/async_error_boundary)           | High-level `ErrorBoundary` widget — `builder(context, error, reset)`, `onError` / `onReset` callbacks, `resetKeys` auto-reset, manual `showBoundary`.                         |
| [`transition_boundary`](packages/transition_boundary) | React `useTransition`-style transitions. Wraps a subtree with `TransitionBoundary` so descendant suspends are absorbed without flashing the surrounding `AsyncZone` fallback. |
| [`hooks_async_zone`](packages/hooks_async_zone)       | `flutter_hooks` integration — `HookZoneWidget`, `useAsyncZone()`, sliver/error variants. Use this if your codebase already uses hooks.                                        |

## Quick start

Install the pieces you need. Most apps want at least `async_zone` + `async_error_boundary`:

```sh
flutter pub add async_zone async_error_boundary
# Optional, pick as needed:
flutter pub add transition_boundary
flutter pub add hooks_async_zone
```

Minimal example — a suspending data card with an error fallback:

```dart
import 'package:async_zone/async_zone.dart';
import 'package:async_error_boundary/async_error_boundary.dart';
import 'package:flutter/material.dart';

class UserCard extends ZoneWidget {
  const UserCard({super.key, required this.future});

  final Future<User> future;

  @override
  Widget build(BuildContext context) {
    // Throws `future` until it resolves — the enclosing AsyncZone shows
    // its fallback. Errors propagate to the enclosing ErrorBoundary.
    final user = AsyncZone.of(context).use(future);
    return Text(user.name);
  }
}

// usage
final userFuture = fetchUser(1); // hold the same Future instance across rebuilds

ErrorBoundary(
  builder: (context, error, reset) => ErrorView(error: error, onRetry: reset),
  child: AsyncZone(
    fallback: const CircularProgressIndicator(),
    child: UserCard(future: userFuture),
  ),
)
```

## Choose your starting point

| You want…                                                                          | Add                                                                |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Suspense + `use()` only                                                            | `async_zone`                                                       |
| A drop-in `ErrorBoundary` widget (recommended over hand-rolling `ErrorZoneWidget`) | `async_zone` + `async_error_boundary`                                    |
| React `useTransition`-style "keep previous UI while new state suspends"            | `+ transition_boundary`                                            |
| Already using `flutter_hooks`                                                      | `+ hooks_async_zone` (provides `HookZoneWidget`, `useAsyncZone()`) |

Each package's own README has detailed API references, common pitfalls (especially around `use()`'s identity-based caching), and longer examples.

## Architecture

Everything is built on a single primitive — the `ZoneElement` mixin in `async_zone`. Any `Element` that mixes it in catches `Future` and `Object` throws during `build()` and routes them to the appropriate provider via `InheritedWidget` lookup:

- A thrown `Future` goes to `AsyncZoneProvider` (set up by `AsyncZone`) → fallback rendering, identity-based result cache keyed on the future instance.
- An `Object` error goes to `ErrorZoneProvider` (set up by `ErrorZoneWidget` / `ErrorBoundary`) → fallback builder, escalation to outer error zones.
- During an active transition, the future is registered with `TransitionZoneProvider` (set up by `TransitionBoundary`) instead of the async fallback — the previous subtree stays visible, `isPending` flips on.

Composition is "via inheritance" in two senses: `Element` mixin composition (e.g. `HookZoneWidget` = `HookElement` + `ZoneElement`, `ConsumerZoneWidget` in the riverpod sample = `ConsumerStatefulElement` + `ZoneElement`), and `InheritedWidget` nesting (zones / boundaries / transitions can nest, with the same outer-catches-what-inner-cannot semantics as React's boundaries).

## Examples

The [`examples/`](examples) directory has six runnable samples. The first three demonstrate the core packages directly; the latter three show how state-management libraries can plug into the same Suspense pattern via small bridge implementations:

| Sample                                                    | Demonstrates                                                                                            |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| [`async_zone_sample`](examples/async_zone_sample)         | Reference app — `AsyncZone` + `use()` + `ErrorBoundary` + `TransitionBoundary` with `hooks_async_zone`. |
| [`stateful_zone_sample`](examples/stateful_zone_sample)   | Same UX as above with plain `StatefulZoneWidget` (no Hooks dependency).                                 |
| [`sliver_zone_sample`](examples/sliver_zone_sample)       | Same UX inside a `CustomScrollView` using `SliverStatefulZoneWidget`.                                   |
| [`fquery_sample`](examples/fquery_sample)                 | `fquery` bridge — Suspense + `use()` over a TanStack-style cache via a `useAsyncZoneQuery` hook.        |
| [`tanstack_query_sample`](examples/tanstack_query_sample) | `tanstack_query` bridge — same pattern as `fquery_sample`, against the Dart port of TanStack Query.     |
| [`riverpod_sample`](examples/riverpod_sample)             | Riverpod bridge — `ConsumerZoneWidget` (`ConsumerStatefulElement` + `ZoneElement`) + `watchOrSuspend`.  |

The fquery / tanstack / riverpod samples are particularly useful as reference patterns for adding Suspense to any reactive state library: the bridge is usually small (~60 lines).

## Development

This repo is a Dart workspace ([`pubspec.yaml`](pubspec.yaml)) — all packages and examples resolve from a single lockfile:

```sh
flutter pub get              # resolves the whole workspace
flutter test                 # from any package directory
```

Each example can be launched by `cd`-ing into it and running `flutter run`.

## Inspiration

- React's [Suspense](https://react.dev/reference/react/Suspense) and the [`use()`](https://react.dev/reference/react/use) hook
- React's [Error Boundary](https://react.dev/reference/react/Component#catching-rendering-errors-with-an-error-boundary) and [`react-error-boundary`](https://github.com/bvaughn/react-error-boundary)
- React's [`useTransition`](https://react.dev/reference/react/useTransition)

## License

BSD 3-Clause — see [LICENSE](LICENSE).
