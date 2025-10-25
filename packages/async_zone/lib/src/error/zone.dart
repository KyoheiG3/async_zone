import 'package:flutter/widgets.dart';

import 'zone_element.dart';

/// An abstract base class for stateless widgets with error zone capabilities.
///
/// [ErrorZone] extends [StatelessWidget] and mixes in [ErrorBoundaryMixin] to provide
/// error boundary functionality. It creates a [StatelessErrorZoneElement] which
/// manages error state and provides error handling.
///
/// Subclasses should:
/// - Implement [getDerivedStateFromError] to derive state from errors
/// - Optionally override [componentDidCatch] to handle caught errors
/// - Implement [build] to render UI based on the current state
///
/// See also:
/// - [ErrorBoundary], a concrete implementation of error boundaries.
/// - [ErrorBoundaryMixin], the mixin that provides error zone functionality.
abstract class ErrorZone<T> extends StatelessWidget with ErrorBoundaryMixin<T> {
  /// Creates an [ErrorZone].
  ErrorZone({super.key});

  @override
  StatelessErrorZoneElement<T> createElement() =>
      StatelessErrorZoneElement(this);
}

/// An element for [ErrorZone] that combines [StatelessElement] with [ErrorZoneElement].
///
/// This element provides error zone capabilities for stateless widgets.
class StatelessErrorZoneElement<T> extends StatelessElement
    with ErrorZoneElement<T> {
  /// Creates a [StatelessErrorZoneElement] for the given [widget].
  StatelessErrorZoneElement(super.widget);

  @override
  ErrorZone<T> get widget => super.widget as ErrorZone<T>;
}

/// An abstract base class for stateful widgets with error zone capabilities.
///
/// [StatefulErrorZone] extends [StatefulWidget] and mixes in [ErrorBoundaryMixin] to
/// provide error boundary functionality. It creates a [StatefulErrorZoneElement]
/// which manages error state and provides error handling.
///
/// This is typically used when you need stateful error boundaries, though in most
/// cases [ErrorZone] (stateless) is sufficient.
///
/// See also:
/// - [ErrorZone], the stateless version of error zones.
/// - [ErrorBoundaryMixin], the mixin that provides error zone functionality.
abstract class StatefulErrorZone<T> extends StatefulWidget
    with ErrorBoundaryMixin<T> {
  /// Creates a [StatefulErrorZone].
  StatefulErrorZone({super.key});

  @override
  StatefulErrorZoneElement<T> createElement() => StatefulErrorZoneElement(this);
}

/// An element for [StatefulErrorZone] that combines [StatefulElement] with [ErrorZoneElement].
///
/// This element provides error zone capabilities for stateful widgets.
class StatefulErrorZoneElement<T> extends StatefulElement
    with ErrorZoneElement<T> {
  /// Creates a [StatefulErrorZoneElement] for the given [widget].
  StatefulErrorZoneElement(super.widget);

  @override
  StatefulErrorZone<T> get widget => super.widget as StatefulErrorZone<T>;
}
