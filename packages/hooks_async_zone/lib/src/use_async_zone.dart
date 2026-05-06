import 'package:async_zone/async_zone.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A Flutter hook that executes an asynchronous operation within an async zone.
///
/// This hook retrieves the [AsyncZone] from the widget tree and uses it to manage
/// the provided [future]. It's a convenient way to integrate async operations with
/// Flutter hooks and zone management.
///
/// The hook automatically handles the lifecycle of the async operation and updates
/// the widget when the future completes.
///
/// Parameters:
///   - [future]: The asynchronous operation to execute within the zone.
///
/// Returns:
///   The result of type [T] from the future once it completes.
///
/// Example:
/// ```dart
/// class MyWidget extends HookZoneWidget {
///   const MyWidget({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final userData = useAsyncZone(fetchUserData());
///     return Text('User: ${userData.name}');
///   }
/// }
/// ```
///
/// Throws:
///   - [StateError]: If no [AsyncZone] is found in the widget tree.
T useAsyncZone<T>(Future<T> future) {
  final context = useContext();

  return AsyncZone.of(context).use(future);
}
