import 'package:flutter/widgets.dart';

import 'zone_controller.dart';
import 'zone_provider.dart';

/// A mixin that provides error zone functionality to widgets.
///
/// This mixin is used with [ErrorZone] and [StatefulErrorZone] to add error boundary
/// capabilities to widgets. It provides methods for handling errors and managing
/// error state through an [ErrorZoneController].
///
/// Subclasses must implement:
/// - [getDerivedStateFromError]: To derive state from errors
///
/// Subclasses can optionally override:
/// - [componentDidCatch]: To handle caught errors (e.g., for logging)
///
/// The mixin provides:
/// - [resetErrorBoundary]: Method to reset the error state
/// - [showErrorBoundary]: Method to manually show an error
/// - [state]: Getter to access the current error state
mixin ErrorBoundaryMixin<T> on Widget {
  final _controller = ErrorZoneController<T>();

  /// Called when an error is caught by this error zone.
  ///
  /// This is similar to React's `componentDidCatch` lifecycle method.
  /// Override this method to handle errors, such as logging them to an
  /// error reporting service.
  ///
  /// The default implementation does nothing.
  void componentDidCatch(Object error, StackTrace stackTrace) {}

  /// Derives the error state from an error object.
  ///
  /// This is similar to React's `getDerivedStateFromError` lifecycle method.
  /// This method is called with `null` initially and with the error object
  /// when an error occurs.
  ///
  /// Return the state object that should be used when rendering with the given error.
  T getDerivedStateFromError(Object? error);

  /// Resets the error boundary, clearing any error state.
  ///
  /// After calling this method, the error zone will return to its normal state
  /// and render the child widget instead of the error fallback.
  void resetErrorBoundary() => _controller.resetError();

  /// Manually shows an error in the error boundary.
  ///
  /// This can be used to programmatically trigger the error boundary's
  /// fallback UI without actually throwing an error.
  void showErrorBoundary(Object error, [StackTrace? stackTrace]) {
    _controller.showError(error, stackTrace);
  }

  /// Returns the current error state.
  T get state => _controller.state;
}

/// A mixin that provides error zone element functionality for managing error state.
///
/// This mixin is used with [StatelessErrorZoneElement] and [StatefulErrorZoneElement]
/// to implement the element-level error handling logic. It manages:
/// - Error state tracking
/// - Error state updates
/// - Rebuild coordination when errors occur or are cleared
/// - Integration with [ErrorZoneProvider] for descendant error handling
///
/// This mixin works in conjunction with [ErrorBoundaryMixin] to provide complete
/// error boundary functionality.
mixin ErrorZoneElement<T> on ComponentElement {
  @override
  ErrorBoundaryMixin<T> get widget;

  late T _state = widget.getDerivedStateFromError(null);

  Object? _error;

  /// Returns whether this element currently has an error.
  bool get hasError => _error != null;

  var _isDuringPerformRebuild = false;

  @override
  void performRebuild() {
    _isDuringPerformRebuild = true;
    final hasErrorBefore = hasError;

    try {
      super.performRebuild();

      // If error display is needed, rebuild again to show the fallback
      if (hasErrorBefore != hasError) {
        super.performRebuild();
      }
    } finally {
      _isDuringPerformRebuild = false;
    }
  }

  void _updateErrorState(Object? error) {
    _error = error;
    _state = widget.getDerivedStateFromError(error);

    if (!_isDuringPerformRebuild) {
      markNeedsBuild();
    }
  }

  @override
  Widget build() {
    widget._controller.attach(
      onReset: () => _updateErrorState(null),
      onShowError: (error, stackTrace) {
        _updateErrorState(error);
        widget.componentDidCatch(error, stackTrace);
      },
      stateGetter: () => _state,
    );

    return ErrorZoneProvider(
      canShowError: () => _isDuringPerformRebuild,
      onError: widget._controller.showError,
      child: super.build(),
    );
  }

  @override
  void unmount() {
    _error = null;
    super.unmount();
  }
}
