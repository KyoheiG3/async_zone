import 'package:flutter/widgets.dart';

import 'zone_controller.dart';

mixin ErrorZoneWidget<T> on Widget {
  final controller = ErrorZoneController<T>();

  void componentDidCatch(Object error, StackTrace stackTrace) {}

  T getDerivedStateFromError(Object? error);

  void resetErrorBoundary() => controller.resetErrorBoundary();

  T get state => controller.state;
}
