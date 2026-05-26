import 'dart:async';

/// The transition scope exposed to descendants of a [TransitionBoundary].
///
/// Obtained via `TransitionZone.of(context)`. Provides the read-only
/// [isPending] flag and the [startTransition] entry point for triggering a
/// transition-style state update.
abstract class TransitionZoneScope {
  /// Whether a transition is currently in progress.
  ///
  /// Flips to `true` (in the same frame when `forceSameFrameRebuild` is on,
  /// otherwise the next frame) once a descendant `ZoneWidget` throws a
  /// future inside the transition, and stays `true` until every future
  /// registered through the bridge resolves.
  bool get isPending;

  /// Starts a transition.
  ///
  /// [action] runs synchronously so any state updates it performs take
  /// effect on the very next build. During that rebuild, any [Future]
  /// thrown by a `ZoneWidget` is registered with this scope, keeping the
  /// surrounding subtree showing its previous content until the future
  /// resolves.
  ///
  /// When [action] returns a [Future] (typically by being declared `async`),
  /// that future is automatically tracked, keeping the transition pending
  /// across explicit asynchronous work — for example heavy data preparation
  /// run on another isolate via `compute()` — without requiring a
  /// surrounding `ZoneWidget`.
  void startTransition(FutureOr<void> Function() action);
}
