import 'package:flutter/material.dart';

import 'error/zone.dart';

typedef ErrorBoundaryState = ({Object? error});

typedef ErrorFallbackBuilder =
    Widget Function(
      BuildContext context,
      Object error,
      void Function([Object? arg]) resetErrorBoundary,
    );

class ErrorBoundary extends ErrorZone<ErrorBoundaryState> {
  ErrorBoundary({
    super.key,
    required this.builder,
    this.onError,
    this.onReset,
    required this.child,
  });

  final ErrorFallbackBuilder builder;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final void Function(Object? arg)? onReset;
  final Widget child;

  static ErrorBoundaryProvider of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<ErrorBoundaryProvider>();

    if (provider == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No ErrorBoundary widget found in context.'),
        ErrorDescription(
          'ErrorBoundary.of() was called with a context that does not contain an ErrorBoundary widget.',
        ),
        ErrorHint(
          'Ensure that the context passed to ErrorBoundary.of() is a descendant of an ErrorBoundary widget.',
        ),
        context.describeElement('The context used was'),
      ]);
    }

    return provider;
  }

  @override
  void componentDidCatch(Object error, StackTrace stackTrace) {
    onError?.call(error, stackTrace);
  }

  @override
  ErrorBoundaryState getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  Widget build(BuildContext context) {
    void resetBoundary([Object? arg]) {
      resetErrorBoundary();
      onReset?.call(arg);
    }

    final error = state.error;
    if (error != null) {
      return builder(context, error, resetBoundary);
    }

    return ErrorBoundaryProvider(
      resetBoundary: resetBoundary,
      showBoundary: showErrorBoundary,
      child: child,
    );
  }
}

class ErrorBoundaryProvider extends InheritedWidget {
  const ErrorBoundaryProvider({
    super.key,
    required this.resetBoundary,
    required this.showBoundary,
    required super.child,
  });

  final void Function([Object? arg]) resetBoundary;
  final void Function(Object error, [StackTrace? stackTrace]) showBoundary;

  @override
  bool updateShouldNotify(ErrorBoundaryProvider oldWidget) => false;
}
