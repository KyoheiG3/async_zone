import 'package:flutter/widgets.dart';

import 'zone_provider.dart';
import 'zone_widget.dart';

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
    widget.controller.attach(
      onReset: () => _updateErrorState(null),
      stateGetter: () => _state,
    );

    return ErrorZoneProvider(
      canShowError: () => _isDuringPerformRebuild,
      onError: (error, stackTrace) {
        _updateErrorState(error);
        widget.componentDidCatch(error, stackTrace);
      },
      child: super.build(),
    );
  }

  @override
  void unmount() {
    _error = null;
    super.unmount();
  }
}
