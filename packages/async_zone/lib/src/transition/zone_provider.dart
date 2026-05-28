import 'package:flutter/widgets.dart';

import 'zone_scope.dart';

/// An [InheritedWidget] that publishes a [TransitionZoneBridge] to
/// descendants.
///
/// Constructed by the `TransitionBoundary` widget (from the
/// `async_transition_boundary` package) to expose its bridge so `ZoneElement`
/// instances below can extend their suspensions through the transition.
class TransitionZoneProvider extends InheritedWidget {
  const TransitionZoneProvider({
    super.key,
    required this.bridge,
    required this.isPending,
    required super.child,
  });

  /// The bridge exposed to `ZoneElement` descendants.
  final TransitionZoneBridge bridge;

  final bool isPending;

  /// Returns the [TransitionZoneBridge] from the closest ancestor, if any.
  ///
  /// Pass `listen: true` to subscribe [context] so it rebuilds when
  /// `isPending` flips. Defaults to a plain lookup that does not register
  /// the caller as a dependent.
  static TransitionZoneBridge? maybeOf(
    BuildContext context, {
    bool listen = false,
  }) {
    final widget = listen
        ? context.dependOnInheritedWidgetOfExactType<TransitionZoneProvider>()
        : context.getInheritedWidgetOfExactType<TransitionZoneProvider>();
    return widget?.bridge;
  }

  @override
  bool updateShouldNotify(TransitionZoneProvider old) =>
      isPending != old.isPending;
}
