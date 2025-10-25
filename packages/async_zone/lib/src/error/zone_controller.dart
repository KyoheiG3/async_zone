/// A controller that manages error zone state and provides methods to control error boundaries.
///
/// This controller is used by [ErrorBoundaryMixin] to expose error boundary
/// functionality ([resetErrorBoundary] and [showErrorBoundary]) while keeping
/// the actual implementation in [ErrorZoneElement].
///
/// The controller acts as a bridge between the widget layer and the element layer,
/// allowing widgets to trigger error boundary actions without direct access to the element.
class ErrorZoneController<T> {
  /// Creates an [ErrorZoneController].
  ErrorZoneController();

  void Function()? _onReset;
  void Function(Object error, StackTrace stackTrace)? _onShowError;
  late T Function() _stateGetter;

  /// Returns the current state of the error zone.
  T get state => _stateGetter();

  /// Resets the error state, clearing any displayed errors.
  void resetError() => _onReset?.call();

  /// Shows an error in the error boundary.
  ///
  /// The [error] parameter is required. If [stackTrace] is not provided,
  /// the current stack trace is used.
  void showError(Object error, [StackTrace? stackTrace]) {
    _onShowError?.call(error, stackTrace ?? StackTrace.current);
  }

  /// Attaches callbacks and state getter to this controller.
  ///
  /// This method is called by [ErrorZoneElement] during the build phase to
  /// connect the controller to the element's state management.
  ///
  /// Parameters:
  /// - [onReset]: Called when [resetError] is invoked.
  /// - [onShowError]: Called when [showError] is invoked.
  /// - [stateGetter]: A function that returns the current state.
  void attach({
    required void Function() onReset,
    required void Function(Object error, StackTrace stackTrace) onShowError,
    required T Function() stateGetter,
  }) {
    _onReset = onReset;
    _onShowError = onShowError;
    _stateGetter = stateGetter;
  }
}
