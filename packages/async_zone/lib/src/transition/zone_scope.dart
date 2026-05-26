/// Bridge consumed by `ZoneElement` to extend the lifetime of a transition.
///
/// Looked up via `TransitionZoneProvider.maybeOf` (pass `listen: true` to
/// subscribe so the caller rebuilds when [isPending] flips). The bridge
/// is decoupled from any specific async framework: the only contract is
/// "tell me about a future, and I will keep the transition pending until
/// it completes."
abstract class TransitionZoneBridge {
  /// Whether the surrounding transition scope is currently pending.
  ///
  /// Mirrors `TransitionZoneScope.isPending` and is what
  /// `TransitionZoneProvider.maybeOf(..., listen: true)` notifies on.
  /// Exposed here so `ZoneElement` can read it through the bridge without
  /// reaching into the provider widget.
  bool get isPending;

  /// Whether the surrounding transition scope is currently in a transition.
  bool get inTransition;

  /// Registers [future] with the current transition.
  ///
  /// `ZoneElement` calls this automatically for futures thrown during a
  /// build. The transition stays pending and keeps the previous subtree
  /// visible until the future completes.
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
