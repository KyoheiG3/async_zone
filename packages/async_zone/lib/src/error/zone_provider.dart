import 'package:flutter/widgets.dart';

abstract class ErrorZoneProviderScope {
  bool get isDuringPerformRebuild;
  void markShowError(Object error, StackTrace stackTrace);
}

class ErrorZoneProvider extends InheritedWidget {
  const ErrorZoneProvider({
    super.key,
    required this.isDuringPerformRebuild,
    required this.onError,
    required super.child,
  });

  final bool Function() isDuringPerformRebuild;
  final Function(Object error, StackTrace stackTrace) onError;

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

class ErrorZoneProviderElement extends InheritedElement
    implements ErrorZoneProviderScope {
  ErrorZoneProviderElement(this._widget) : super(_widget);

  final ErrorZoneProvider _widget;

  @override
  bool get isDuringPerformRebuild => _widget.isDuringPerformRebuild();

  @override
  void markShowError(Object error, StackTrace stackTrace) {
    _widget.onError(error, stackTrace);
  }
}
