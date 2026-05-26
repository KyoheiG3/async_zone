import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';

import 'transition_zone_scope.dart';

/// Namespace for looking up the surrounding [TransitionZoneScope].
///
/// Provides the static entrypoints [of] and [maybeOf] used to read the scope
/// from any descendant build context of a [TransitionBoundary]. Not
/// instantiable.
abstract final class TransitionZone {
  TransitionZone._();

  /// Returns the [TransitionZoneScope] from the closest enclosing
  /// `TransitionBoundary`.
  ///
  /// Subscribes [context] as a dependent so it rebuilds when the scope's
  /// `isPending` flag flips. Throws a [FlutterError] when no
  /// `TransitionBoundary` is present above [context].
  static TransitionZoneScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'TransitionZone.of called without an enclosing TransitionBoundary.',
        ),
        ErrorDescription(
          'No TransitionBoundary was found above the given context. Wrap '
          'the subtree that needs to call startTransition (or read '
          'isPending) with a TransitionBoundary widget.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scope;
  }

  /// Returns the [TransitionZoneScope] from the closest enclosing
  /// `TransitionBoundary`, or `null` when none is present.
  ///
  /// Subscribes [context] as a dependent so it rebuilds when the scope's
  /// `isPending` flag flips.
  static TransitionZoneScope? maybeOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<TransitionZoneProvider>();
    return provider?.bridge as TransitionZoneScope?;
  }
}
