import 'package:async_zone/async_zone.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A Flutter hook that returns the [AsyncZoneScope] from the widget tree.
///
/// Unlike a typical "use" hook, this does not consume a future itself. It
/// only locates the nearest [AsyncZone] ancestor and exposes its
/// [AsyncZoneScope.use] method, which mirrors React's `use()` API: you can
/// call `zone.use(future)` inside conditionals, loops, or after early
/// returns — it does not need to obey the Rules of Hooks.
///
/// Returns:
///   The [AsyncZoneScope] for the surrounding [AsyncZone].
///
/// Example:
/// ```dart
/// class MyWidget extends HookZoneWidget {
///   const MyWidget({super.key, required this.showUser});
///
///   final bool showUser;
///
///   @override
///   Widget build(BuildContext context) {
///     final zone = useAsyncZone();
///     final future = useMemoized(() => fetchUserData());
///
///     if (!showUser) return const SizedBox.shrink();
///
///     final user = zone.use(future);
///     return Text('User: ${user.name}');
///   }
/// }
/// ```
///
/// Throws:
///   - [FlutterError]: If no [AsyncZone] is found in the widget tree.
AsyncZoneScope useAsyncZone() {
  final context = useContext();

  return AsyncZone.of(context);
}
