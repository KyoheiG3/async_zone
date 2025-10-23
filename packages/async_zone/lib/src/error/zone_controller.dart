class ErrorZoneController<T> {
  ErrorZoneController();

  void Function()? _onReset;
  late T Function() _stateGetter;

  T get state => _stateGetter();

  void resetErrorBoundary() => _onReset?.call();

  void attach({
    required void Function() onReset,
    required T Function() stateGetter,
  }) {
    _onReset = onReset;
    _stateGetter = stateGetter;
  }
}
