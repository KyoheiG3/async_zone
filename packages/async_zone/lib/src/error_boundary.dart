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
  final void Function([Object? arg])? onReset;
  final Widget child;

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
    final error = state.error;
    if (error != null) {
      return builder(context, error, ([arg]) {
        resetErrorBoundary();
        onReset?.call(arg);
      });
    }

    return child;
  }
}
