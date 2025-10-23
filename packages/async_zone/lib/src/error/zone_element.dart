import 'package:flutter/widgets.dart';

import 'zone_controller.dart';
import 'zone_provider.dart';

mixin ErrorZoneWidget<T> on Widget {
  final _controller = ErrorZoneController<T>();

  void componentDidCatch(Object error, StackTrace stackTrace) {}

  T getDerivedStateFromError(Object? error);

  void resetErrorBoundary() => _controller.resetError();

  void showErrorBoundary(Object error, [StackTrace? stackTrace]) {
    _controller.showError(error, stackTrace);
  }

  T get state => _controller.state;
}

mixin ErrorZoneElement<T> on ComponentElement {
  @override
  ErrorZoneWidget<T> get widget;

  late T _state = widget.getDerivedStateFromError(null);

  Object? _error;
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
