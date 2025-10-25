import 'package:flutter/widgets.dart';

/// Internal scope interface for error zone provider functionality.
///
/// This interface is used by [ZoneElement] to interact with error zones.
/// It is not intended to be used directly by application code.
abstract class ErrorZoneProviderScope {
  /// Returns whether errors can currently be shown.
  ///
  /// Returns `true` during the rebuild phase when errors can be displayed immediately.
  bool get canShowError;

  /// Marks an error to be shown in the error zone.
  ///
  /// This method is called when an error occurs during the build phase.
  void markShowError(Object error, StackTrace stackTrace);
}

/// An [InheritedWidget] that provides error zone functionality to descendant widgets.
///
/// This widget is created by [ErrorZoneElement] and provides error handling
/// capabilities to the widget tree. It implements [ErrorZoneProviderScope]
/// through its element.
///
/// This class is typically not used directly. Use [ErrorZoneWidget] or [ErrorBoundary] instead.
class ErrorZoneProvider extends InheritedWidget {
  /// Creates an [ErrorZoneProvider].
  ///
  /// All parameters are required.
  const ErrorZoneProvider({
    super.key,
    required this.canShowError,
    required this.onError,
    required super.child,
  });

  /// A function that returns whether errors can currently be shown.
  final bool Function() canShowError;

  /// A callback that is invoked when an error should be shown.
  final Function(Object error, StackTrace stackTrace) onError;

  /// Returns the [ErrorZoneProviderScope] from the closest [ErrorZoneProvider] ancestor, if any.
  ///
  /// This method is used internally by the framework to access error zone functionality.
  /// Returns `null` if no [ErrorZoneProvider] is found in the widget tree.
  static ErrorZoneProviderScope? maybeOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<ErrorZoneProvider>();
    return element as ErrorZoneProviderScope?;
  }

  @override
  ErrorZoneProviderElement createElement() => ErrorZoneProviderElement(this);

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// The element for [ErrorZoneProvider] that implements error zone functionality.
///
/// This element implements [ErrorZoneProviderScope] to provide error handling
/// capabilities to the widget tree.
class ErrorZoneProviderElement extends InheritedElement
    implements ErrorZoneProviderScope {
  /// Creates an [ErrorZoneProviderElement] for the given [widget].
  ErrorZoneProviderElement(this._widget) : super(_widget);

  final ErrorZoneProvider _widget;

  @override
  bool get canShowError => _widget.canShowError();

  @override
  void markShowError(Object error, StackTrace stackTrace) {
    _widget.onError(error, stackTrace);
  }
}
