import 'package:flutter/material.dart';

import 'error/zone.dart';

/// The state for [ErrorBoundary], containing the current error if any.
///
/// This record type holds:
/// - [error]: The error object that was caught, or `null` if no error is present.
typedef ErrorBoundaryState = ({Object? error});

/// A builder function for creating fallback UI when an error is caught.
///
/// Parameters:
/// - [context]: The build context for creating widgets.
/// - [error]: The error object that was caught.
/// - [resetErrorBoundary]: A function to reset the error boundary state,
///   optionally passing an argument that will be forwarded to [ErrorBoundary.onReset].
///
/// Returns a widget to display as the fallback UI when an error occurs.
typedef ErrorFallbackBuilder =
    Widget Function(
      BuildContext context,
      Object error,
      void Function([Object? arg]) resetErrorBoundary,
    );

/// A widget that catches errors from its child widget tree and displays fallback UI.
///
/// [ErrorBoundary] provides a declarative way to handle errors in Flutter,
/// similar to React's error boundaries. When an error occurs in the child widget tree,
/// the boundary catches it and displays a fallback UI instead of crashing the app.
///
/// Example:
/// ```dart
/// ErrorBoundary(
///   builder: (context, error, reset) => Column(
///     children: [
///       Text('Error: $error'),
///       ElevatedButton(
///         onPressed: reset,
///         child: Text('Retry'),
///       ),
///     ],
///   ),
///   onError: (error, stackTrace) {
///     print('Error caught: $error');
///   },
///   onReset: (_) {
///     print('Error boundary reset');
///   },
///   child: MyWidget(),
/// )
/// ```
///
/// See also:
/// - [ErrorFallbackBuilder], which defines the signature for the fallback builder.
/// - [ErrorBoundaryProvider], which provides access to reset and show boundary functions.
class ErrorBoundary extends ErrorZone<ErrorBoundaryState> {
  /// Creates an [ErrorBoundary] widget.
  ///
  /// The [builder] and [child] parameters are required.
  /// The [builder] is called with the caught error to create fallback UI.
  /// The [onError] callback is called when an error is caught.
  /// The [onReset] callback is called when the error boundary is reset.
  ErrorBoundary({
    super.key,
    required this.builder,
    this.onError,
    this.onReset,
    required this.child,
  });

  /// A builder function that creates the fallback UI when an error is caught.
  final ErrorFallbackBuilder builder;

  /// Called when an error is caught by this boundary.
  ///
  /// This callback receives the error object and stack trace for logging or
  /// error reporting purposes.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Called when the error boundary is reset.
  ///
  /// This callback receives an optional argument that was passed to the
  /// reset function from the fallback builder.
  final void Function(Object? arg)? onReset;

  /// The widget below this widget in the tree.
  ///
  /// Errors thrown by this widget or its descendants will be caught by
  /// this error boundary.
  final Widget child;

  /// Returns the [ErrorBoundaryProvider] from the closest [ErrorBoundary] ancestor.
  ///
  /// This method can be used to access the reset and show boundary functions
  /// from anywhere within the error boundary's child tree.
  ///
  /// If no [ErrorBoundary] is found in the widget tree, this method throws a [FlutterError].
  ///
  /// Example:
  /// ```dart
  /// final provider = ErrorBoundary.of(context);
  /// provider.resetBoundary(); // Reset the error boundary
  /// provider.showBoundary(error); // Show an error
  /// ```
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

/// An [InheritedWidget] that provides access to error boundary functions.
///
/// This widget is created by [ErrorBoundary] and provides two main functions:
/// - [resetBoundary]: Clears the error state and shows the child widget again.
/// - [showBoundary]: Manually triggers the error boundary to show an error.
///
/// Use [ErrorBoundary.of] to access this provider from descendant widgets.
class ErrorBoundaryProvider extends InheritedWidget {
  /// Creates an [ErrorBoundaryProvider].
  ///
  /// All parameters are required.
  const ErrorBoundaryProvider({
    super.key,
    required this.resetBoundary,
    required this.showBoundary,
    required super.child,
  });

  /// Resets the error boundary, clearing any error state.
  ///
  /// An optional argument can be passed that will be forwarded to
  /// the [ErrorBoundary.onReset] callback.
  final void Function([Object? arg]) resetBoundary;

  /// Manually shows an error in the error boundary.
  ///
  /// This can be used to programmatically trigger the error boundary's
  /// fallback UI from descendant widgets.
  final void Function(Object error, [StackTrace? stackTrace]) showBoundary;

  @override
  bool updateShouldNotify(ErrorBoundaryProvider oldWidget) => false;
}
