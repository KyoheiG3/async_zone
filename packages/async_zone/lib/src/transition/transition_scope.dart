import 'dart:async';

/// The scope exposed by a [TransitionZoneWidget] (or any element mixed in
/// with [TransitionZoneElement]) to its descendants.
///
/// Obtained via [TransitionZone.of]. Provides the read-only [isPending]
/// flag and the [startTransition] entry point for triggering a
/// transition-style state update.
abstract class TransitionZoneScope {
  /// Whether a transition is currently in progress.
  ///
  /// Flips to `true` synchronously when [startTransition] is called and stays
  /// `true` until every future registered through the bridge resolves.
  bool get isPending;

  /// Starts a transition.
  ///
  /// [action] runs synchronously so any state updates it performs take
  /// effect on the very next build. During that rebuild, any [Future]
  /// thrown by a `ZoneWidget` is registered with this scope, keeping the
  /// surrounding subtree showing its previous content until the future
  /// resolves. `isPending` flips to `true` in the same frame, and only
  /// when there is actually work to wait on.
  ///
  /// When [action] returns a [Future] (typically by being declared `async`),
  /// that future is automatically tracked via [TransitionZoneBridge.track],
  /// keeping the transition pending across explicit asynchronous work —
  /// for example heavy data preparation run on another isolate via
  /// `compute()` — without requiring a surrounding `ZoneWidget`.
  void startTransition(FutureOr<void> Function() action);
}

/// Bridge consumed by external systems (typically `ZoneElement`) to extend
/// the lifetime of a transition.
///
/// Looked up via [TransitionZone.bridgeOf]. The bridge is decoupled from any
/// specific async framework: the only contract is "tell me about a future,
/// and I will keep the transition pending until it completes."
abstract class TransitionZoneBridge {
  /// Whether the surrounding transition scope is currently in a transition.
  bool get inTransition;

  /// Registers [future] with the current transition.
  ///
  /// `ZoneElement` calls this automatically for futures thrown during a
  /// build, but callers may also register their own — for example a
  /// `compute()` future kicked off inside
  /// [TransitionZoneScope.startTransition] — to keep `isPending` true and
  /// the previous subtree visible until that work completes.
  ///
  /// No-op when called outside a transition.
  void track(Future<dynamic> future);

  /// Releases a previously [track]ed [future] from this transition.
  ///
  /// Called by `ZoneElement` when its build replaces the previously
  /// suspending future (a state change made the widget throw a different
  /// future, or the cached value resolved), so the transition no longer
  /// needs to wait on the old one. The future is **not** cancelled — it
  /// continues running in the background; the transition just stops
  /// tracking it.
  void supersede(Future<dynamic> future);
}
