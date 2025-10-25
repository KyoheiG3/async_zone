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
///   @override
///   Widget build(BuildContext context) {
///     final data = AsyncZone.of(context).use(myAsyncOperation());
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
///   @override
///   State<MyStatefulZoneWidget> createState() => _MyStatefulZoneWidgetState();
/// }
///
/// class _MyStatefulZoneWidgetState extends State<MyStatefulZoneWidget> {
///   @override
///   Widget build(BuildContext context) {
///     final data = AsyncZone.of(context).use(myAsyncOperation());
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
