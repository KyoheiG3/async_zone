import 'package:flutter/widgets.dart';

import 'transition_provider.dart';
import 'transition_scope.dart';

/// Namespace for accessing the surrounding [TransitionZoneScope].
///
/// Provides the static entrypoints [of] and [bridgeOf] used to look up the
/// scope (or bridge) from a build context. Not instantiable — extend
/// [TransitionZoneWidget] (or use [TransitionZoneBuilder]) to create a
/// widget that carries a transition scope.
abstract final class TransitionZone {
  TransitionZone._();

  /// Returns the [TransitionZoneScope] of the surrounding
  /// [TransitionZoneElement].
  ///
  /// [context] must be the build context received by a [TransitionZoneWidget]
  /// subclass (or by [TransitionZoneBuilder]'s builder). Calling from a
  /// descendant context — e.g. a nested [Builder] or stateful child — throws
  /// a [FlutterError]; capture the scope in the outer build and pass it down
  /// instead.
  static TransitionZoneScope of(BuildContext context) {
    if (context is TransitionZoneScope) {
      return context as TransitionZoneScope;
    }
    throw FlutterError.fromParts([
      ErrorSummary(
        'TransitionZone.of must be called with a TransitionZoneWidget '
        'context.',
      ),
      ErrorDescription(
        'TransitionZone.of(context) was called with a context that is not the '
        'build context of a TransitionZoneWidget. The transition scope is '
        'only directly reachable from the build method of a '
        'TransitionZoneWidget subclass or from the builder of a '
        'TransitionZoneBuilder.',
      ),
      ErrorHint(
        'Wrap the trigger with a TransitionZoneBuilder (or subclass '
        'TransitionZoneWidget) and call TransitionZone.of with the build '
        'context that subclass receives. If you need the scope deeper in the '
        'tree, capture it in the outer build and pass it down as a parameter '
        'or via a closure.',
      ),
      context.describeElement('The context used was'),
    ]);
  }

  /// Returns the [TransitionZoneBridge] of the nearest enclosing scope, or
  /// `null` when none is present. Intended for internal use by zone
  /// elements that need to inspect or extend an in-flight transition.
  ///
  /// Does not register [context] as a dependent.
  static TransitionZoneBridge? bridgeOf(BuildContext context) {
    if (context is TransitionZoneBridge) {
      return context as TransitionZoneBridge;
    }
    return TransitionZoneProvider.maybeOf(context);
  }
}

/// A widget whose surrounding element coordinates a transition.
///
/// Subclass [TransitionZoneWidget] and override [build] to create a dedicated
/// transition-bearing widget, or use [TransitionZoneBuilder] for an
/// anonymous inline form. Either way the build context received by `build`
/// (or the builder) is the [TransitionZoneElement] itself, so
/// `TransitionZone.of(context)` returns the scope directly.
///
/// Pair with a `ZoneWidget` to drive transitions from futures thrown during
/// build:
/// ```dart
/// class ProfileScreen extends TransitionZoneWidget {
///   const ProfileScreen({super.key, required this.userId});
///   final int userId;
///
///   @override
///   Widget build(BuildContext context) {
///     final scope = TransitionZone.of(context);
///     return Column(children: [
///       UserContent(userId: userId),
///       ElevatedButton(
///         onPressed: () => scope.startTransition(() {/* state change */}),
///         child: const Text('Next'),
///       ),
///     ]);
///   }
/// }
/// ```
///
abstract class TransitionZoneWidget extends StatelessWidget {
  /// Creates a [TransitionZoneWidget].
  const TransitionZoneWidget({super.key});

  @override
  StatelessTransitionZoneElement createElement() =>
      StatelessTransitionZoneElement(this);
}

/// A [StatefulWidget] counterpart to [TransitionZoneWidget].
///
/// Subclass [StatefulTransitionZoneWidget] when the widget that owns the
/// transition scope also owns mutable state. The created element mixes in
/// [TransitionZoneElement], so the [State]'s build context is itself a
/// [TransitionZoneScope] and can be passed straight to [TransitionZone.of].
///
/// Example:
/// ```dart
/// class ProfileScreen extends StatefulTransitionZoneWidget {
///   const ProfileScreen({super.key});
///
///   @override
///   State<ProfileScreen> createState() => _ProfileScreenState();
/// }
///
/// class _ProfileScreenState extends State<ProfileScreen> {
///   int _userId = 1;
///
///   @override
///   Widget build(BuildContext context) {
///     final scope = TransitionZone.of(context);
///     return ElevatedButton(
///       onPressed: () => scope.startTransition(() {
///         setState(() => _userId += 1);
///       }),
///       child: const Text('Next'),
///     );
///   }
/// }
/// ```
abstract class StatefulTransitionZoneWidget extends StatefulWidget {
  /// Creates a [StatefulTransitionZoneWidget].
  const StatefulTransitionZoneWidget({super.key});

  @override
  StatefulTransitionZoneElement createElement() =>
      StatefulTransitionZoneElement(this);
}

/// A [TransitionZoneWidget] that builds itself using a builder callback,
/// allowing inline use without defining a subclass.
///
/// Example:
/// ```dart
/// TransitionZoneBuilder(
///   builder: (context) {
///     final scope = TransitionZone.of(context);
///     return Opacity(
///       opacity: scope.isPending ? 0.5 : 1.0,
///       child: ElevatedButton(
///         onPressed: () => scope.startTransition(() {/* state change */}),
///         child: const Text('Next'),
///       ),
///     );
///   },
/// )
/// ```
class TransitionZoneBuilder extends TransitionZoneWidget {
  /// Creates a [TransitionZoneBuilder].
  const TransitionZoneBuilder({super.key, required this.builder});

  /// Called with the surrounding [TransitionZoneElement] as its context.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}
