import 'package:async_zone/async_zone.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A Flutter hook that returns the [TransitionZoneScope] of the surrounding
/// [HookTransitionZoneElement].
///
/// Must be called from the build method of a [HookTransitionZoneWidget]
/// subclass (such as [HookTransitionZoneBuilder]); that is, an element that
/// mixes in [TransitionZoneElement]. Calling it from a descendant context —
/// e.g. inside a separate [HookBuilder] or a stateful child — throws a
/// [FlutterError], because triggering transitions from outside the scope's
/// own build can leave the rebuild chain unable to surface `isPending` on
/// the same frame.
///
/// To use a scope from a deeper widget, capture it from the enclosing
/// [HookTransitionZoneWidget]'s `build` and pass it down (via closure or
/// constructor argument).
///
/// Returns:
///   The [TransitionZoneScope] for the surrounding
///   [HookTransitionZoneElement].
///
/// Example:
/// ```dart
/// class UserPage extends HookTransitionZoneWidget {
///   const UserPage({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final scope = useTransitionZone();
///     final id = useState(1);
///     final userFuture = useState<Future<User>>(() => fetchUser(1));
///
///     return Column(children: [
///       Opacity(
///         opacity: scope.isPending ? 0.5 : 1.0,
///         child: UserCard(future: userFuture.value),
///       ),
///       ElevatedButton(
///         onPressed: () => scope.startTransition(() {
///           id.value++;
///           userFuture.value = fetchUser(id.value);
///         }),
///         child: const Text('Next'),
///       ),
///     ]);
///   }
/// }
/// ```
///
/// Throws:
///   - [FlutterError]: If the surrounding context is not a
///     [HookTransitionZoneElement].
TransitionZoneScope useTransitionZone() {
  final context = useContext();

  return TransitionZone.of(context);
}
