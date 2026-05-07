import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

/// A base class for stateless widgets that support hooks, zones, and error boundaries.
///
/// This widget combines [StatelessWidget] with [HookElement], [ErrorZoneElement], and
/// [ErrorBoundaryMixin] capabilities, allowing you to use Flutter hooks within an async
/// zone context while providing error handling through error boundaries.
///
/// The type parameter [T] represents the type of errors this widget can handle.
///
/// Example:
/// ```dart
/// class MyErrorBoundary extends HookErrorZoneWidget<({Object? error})> {
///   MyErrorBoundary({super.key, required this.child});
///
///   final Widget child;
///
///   @override
///   ({Object? error}) getDerivedStateFromError(Object? error) => (error: error);
///
///   @override
///   Widget build(BuildContext context) {
///     final retryCount = useState(0);
///
///     if (state.error != null) {
///       return TextButton(
///         onPressed: () {
///           retryCount.value++;
///           resetErrorBoundary();
///         },
///         child: Text('Error: ${state.error} (retried ${retryCount.value})'),
///       );
///     }
///     return child;
///   }
/// }
/// ```
abstract class HookErrorZoneWidget<T> extends StatelessWidget
    with ErrorBoundaryMixin<T> {
  HookErrorZoneWidget({super.key});

  @override
  StatelessHookErrorZoneElement<T> createElement() =>
      StatelessHookErrorZoneElement(this);
}

/// The element for [HookErrorZoneWidget].
///
/// This element combines [StatelessElement] with [HookElement] and [ErrorZoneElement],
/// providing the necessary infrastructure for hooks, zone management, and error handling.
class StatelessHookErrorZoneElement<T> extends StatelessElement
    with HookElement, ErrorZoneElement<T> {
  StatelessHookErrorZoneElement(super.widget);

  @override
  HookErrorZoneWidget<T> get widget => super.widget as HookErrorZoneWidget<T>;
}

/// A base class for stateful widgets that support hooks, zones, and error boundaries.
///
/// This widget combines [StatefulWidget] with [HookElement], [ErrorZoneElement], and
/// [ErrorBoundaryMixin] capabilities, allowing you to use Flutter hooks within an async
/// zone context while maintaining state and providing error handling through error boundaries.
///
/// The type parameter [T] represents the type of errors this widget can handle.
///
/// Example:
/// ```dart
/// class MyStatefulErrorBoundary extends StatefulHookErrorZoneWidget<({Object? error})> {
///   MyStatefulErrorBoundary({super.key, required this.child});
///
///   final Widget child;
///
///   @override
///   ({Object? error}) getDerivedStateFromError(Object? error) => (error: error);
///
///   @override
///   State<MyStatefulErrorBoundary> createState() => _MyStatefulErrorBoundaryState();
/// }
///
/// class _MyStatefulErrorBoundaryState extends State<MyStatefulErrorBoundary> {
///   @override
///   Widget build(BuildContext context) {
///     final retryCount = useState(0);
///
///     if (widget.state.error != null) {
///       return TextButton(
///         onPressed: () {
///           retryCount.value++;
///           widget.resetErrorBoundary();
///         },
///         child: Text('Error: ${widget.state.error} (retried ${retryCount.value})'),
///       );
///     }
///     return widget.child;
///   }
/// }
/// ```
abstract class StatefulHookErrorZoneWidget<T> extends StatefulWidget
    with ErrorBoundaryMixin<T> {
  StatefulHookErrorZoneWidget({super.key});

  @override
  StatefulHookErrorZoneElement<T> createElement() =>
      StatefulHookErrorZoneElement(this);
}

/// The element for [StatefulHookErrorZoneWidget].
///
/// This element combines [StatefulElement] with [HookElement] and [ErrorZoneElement],
/// providing the necessary infrastructure for hooks, zone management, and error handling
/// in stateful widgets.
class StatefulHookErrorZoneElement<T> extends StatefulElement
    with HookElement, ErrorZoneElement<T> {
  StatefulHookErrorZoneElement(super.widget);

  @override
  StatefulHookErrorZoneWidget<T> get widget =>
      super.widget as StatefulHookErrorZoneWidget<T>;
}
