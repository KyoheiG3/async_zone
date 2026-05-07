import 'package:flutter/widgets.dart';

import 'zone_element.dart';

/// An abstract base class for stateless widgets with zone-based async and error handling.
///
/// [ZoneWidget] extends [StatelessWidget] and creates a [StatelessZoneElement]
/// which provides automatic handling of async operations and errors during the build phase.
///
/// Subclasses should implement the [build] method and can throw futures or errors
/// which will be caught and handled by the [ZoneElement] mixin.
///
/// Example:
/// ```dart
/// class MyZoneWidget extends ZoneWidget {
///   const MyZoneWidget({super.key, required this.future});
///
///   final Future<String> future;
///
///   @override
///   Widget build(BuildContext context) {
///     final data = AsyncZone.of(context).use(future);
///     return Text(data);
///   }
/// }
/// ```
abstract class ZoneWidget extends StatelessWidget {
  const ZoneWidget({super.key});

  @override
  StatelessZoneElement createElement() => StatelessZoneElement(this);
}

/// An element for [ZoneWidget] that combines [StatelessElement] with [ZoneElement].
///
/// This element provides zone-based async and error handling capabilities
/// for stateless widgets.
class StatelessZoneElement extends StatelessElement with ZoneElement {
  /// Creates a [StatelessZoneElement] for the given [widget].
  StatelessZoneElement(super.widget);
}

/// An abstract base class for stateful widgets with zone-based async and error handling.
///
/// [StatefulZoneWidget] extends [StatefulWidget] and creates a [StatefulZoneElement]
/// which provides automatic handling of async operations and errors during the build phase.
///
/// Subclasses should implement [createState] to return a [State] object, and the state's
/// [build] method can throw futures or errors which will be caught and handled by
/// the [ZoneElement] mixin.
///
/// Example:
/// ```dart
/// class MyStatefulZoneWidget extends StatefulZoneWidget {
///   const MyStatefulZoneWidget({super.key});
///
///   @override
///   State<MyStatefulZoneWidget> createState() => _MyStatefulZoneWidgetState();
/// }
///
/// class _MyStatefulZoneWidgetState extends State<MyStatefulZoneWidget> {
///   late final _future = myAsyncOperation();
///
///   @override
///   Widget build(BuildContext context) {
///     final data = AsyncZone.of(context).use(_future);
///     return Text(data);
///   }
/// }
/// ```
abstract class StatefulZoneWidget extends StatefulWidget {
  const StatefulZoneWidget({super.key});

  @override
  StatefulZoneElement createElement() => StatefulZoneElement(this);
}

/// An element for [StatefulZoneWidget] that combines [StatefulElement] with [ZoneElement].
///
/// This element provides zone-based async and error handling capabilities
/// for stateful widgets.
class StatefulZoneElement extends StatefulElement with ZoneElement {
  /// Creates a [StatefulZoneElement] for the given [widget].
  StatefulZoneElement(super.widget);
}

/// A widget that builds itself using a builder callback with zone-based async handling.
///
/// [ZoneBuilder] is a convenience widget that combines [ZoneWidget] with a builder pattern,
/// allowing you to create zone-aware widgets inline without defining a separate class.
///
/// When a [Future] is thrown within the [builder], the zone mechanism catches it and
/// coordinates with [AsyncZone] to show fallback UI while the operation is pending.
///
/// Example:
/// ```dart
/// final future = fetchData(); // hold the same instance across rebuilds
///
/// AsyncZone(
///   fallback: const CircularProgressIndicator(),
///   child: ZoneBuilder(
///     builder: (context) {
///       final data = AsyncZone.of(context).use(future);
///       return Text(data);
///     },
///   ),
/// )
/// ```
///
/// This is equivalent to creating a custom [ZoneWidget] subclass but more concise
/// for simple use cases.
///
/// See also:
/// - [ZoneWidget], the base class for zone-aware widgets.
/// - [AsyncZone], which provides fallback UI during async operations.
class ZoneBuilder extends ZoneWidget {
  /// Creates a [ZoneBuilder].
  ///
  /// The [builder] parameter must not be null and is called to obtain the child widget.
  const ZoneBuilder({super.key, required this.builder});

  /// Called to obtain the child widget.
  ///
  /// This function is called whenever this widget is included in its parent's build.
  /// Throwing a [Future] within this builder will trigger zone-based async handling.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return builder(context);
  }
}
