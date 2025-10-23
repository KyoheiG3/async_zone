class ErrorZoneController<T> {
  ErrorZoneController();

  void Function()? _onReset;
  void Function(Object error, StackTrace stackTrace)? _onShowError;
  late T Function() _stateGetter;

  T get state => _stateGetter();

  void resetError() => _onReset?.call();

  void showError(Object error, [StackTrace? stackTrace]) {
    _onShowError?.call(error, stackTrace ?? StackTrace.current);
  }

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
