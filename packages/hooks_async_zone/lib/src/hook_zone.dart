import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A base class for stateless widgets that support both hooks and zone functionality.
///
/// This widget combines [StatelessWidget] with [HookElement] and [ZoneElement] capabilities,
/// allowing you to use Flutter hooks within an async zone context.
///
/// Example:
/// ```dart
/// class MyWidget extends HookZoneWidget {
///   const MyWidget({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final future = useMemoized(() => asyncOperation());
///     final result = useAsyncZone().use(future);
///     return Text('Result: $result');
///   }
/// }
/// ```
abstract class HookZoneWidget extends StatelessWidget {
  const HookZoneWidget({super.key});

  @override
  HookZoneElement createElement() => HookZoneElement(this);
}

/// The element for [HookZoneWidget].
///
/// This element combines [StatelessElement] with [HookElement] and [ZoneElement],
/// providing the necessary infrastructure for hooks and zone management.
class HookZoneElement extends StatelessElement with HookElement, ZoneElement {
  HookZoneElement(super.widget);
}

/// A base class for stateful widgets that support both hooks and zone functionality.
///
/// This widget combines [StatefulWidget] with [HookElement] and [ZoneElement] capabilities,
/// allowing you to use Flutter hooks within an async zone context while maintaining state.
///
/// Example:
/// ```dart
/// class MyStatefulWidget extends StatefulHookZoneWidget {
///   const MyStatefulWidget({super.key});
///
///   @override
///   State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
/// }
///
/// class _MyStatefulWidgetState extends State<MyStatefulWidget> {
///   @override
///   Widget build(BuildContext context) {
///     final future = useMemoized(() => asyncOperation());
///     final result = useAsyncZone().use(future);
///     return Text('Result: $result');
///   }
/// }
/// ```
abstract class StatefulHookZoneWidget extends StatefulWidget {
  const StatefulHookZoneWidget({super.key});

  @override
  StatefulHookZoneElement createElement() => StatefulHookZoneElement(this);
}

/// The element for [StatefulHookZoneWidget].
///
/// This element combines [StatefulElement] with [HookElement] and [ZoneElement],
/// providing the necessary infrastructure for hooks and zone management in stateful widgets.
class StatefulHookZoneElement extends StatefulElement
    with HookElement, ZoneElement {
  StatefulHookZoneElement(StatefulHookZoneWidget super.hooks);
}

/// A convenience widget that provides hooks and zone functionality through a builder pattern.
///
/// This widget is useful when you want to use hooks and zones without creating a custom widget class.
/// It's similar to [HookBuilder] from flutter_hooks but with zone support.
///
/// Example:
/// ```dart
/// HookZoneBuilder(
///   builder: (context) {
///     final future = useMemoized(() => fetchData());
///     final result = useAsyncZone().use(future);
///     return Text('Data: $result');
///   },
/// )
/// ```
class HookZoneBuilder extends HookZoneWidget {
  const HookZoneBuilder({super.key, required this.builder});

  /// The builder function that creates the widget tree.
  ///
  /// This function is called whenever the widget needs to rebuild.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return builder(context);
  }
}
