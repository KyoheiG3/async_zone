import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';

/// Widget that throws a synchronous error on build
class ThrowingWidget extends ZoneWidget {
  const ThrowingWidget({
    super.key,
    this.shouldThrow = true,
    required this.message,
  });

  final bool shouldThrow;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (shouldThrow) {
      throw message;
    }
    return Text('Normal: $message');
  }
}

/// Widget that uses AsyncZone and throws from a Future
class AsyncThrowingWidget extends ZoneWidget {
  const AsyncThrowingWidget({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(future);
    return Text(value);
  }
}

/// StatelessErrorZoneWidget for testing stateless error handling
typedef StatelessErrorState = ({int errorCount, Object? lastError});

class TestStatelessErrorZoneWidget
    extends ErrorZoneWidget<StatelessErrorState> {
  TestStatelessErrorZoneWidget({super.key, required this.child});

  final Widget child;

  @override
  StatefulErrorState getDerivedStateFromError(Object? error) {
    return (errorCount: error != null ? 1 : 0, lastError: error);
  }

  @override
  Widget build(BuildContext context) {
    if (state.lastError != null) {
      return Column(
        children: [
          Text('Stateless Error: ${state.lastError}'),
          ElevatedButton(
            onPressed: () {
              resetErrorBoundary();
            },
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              showErrorBoundary('Stateless reset test');
            },
            child: const Text('Throw'),
          ),
        ],
      );
    }

    return child;
  }
}

/// StatefulErrorZoneWidget for testing stateful error handling
typedef StatefulErrorState = ({int errorCount, Object? lastError});

class TestStatefulErrorZoneWidget
    extends StatefulErrorZoneWidget<StatefulErrorState> {
  TestStatefulErrorZoneWidget({super.key, required this.child});

  final Widget child;

  @override
  StatefulErrorState getDerivedStateFromError(Object? error) {
    return (errorCount: error != null ? 1 : 0, lastError: error);
  }

  @override
  State<TestStatefulErrorZoneWidget> createState() =>
      _StatefulErrorZoneWidgetState();
}

class _StatefulErrorZoneWidgetState extends State<TestStatefulErrorZoneWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.state.lastError != null) {
      return Column(
        children: [
          Text('Stateful Error: ${widget.state.lastError}'),
          ElevatedButton(
            onPressed: () {
              widget.resetErrorBoundary();
            },
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.showErrorBoundary('Stateful reset test');
            },
            child: const Text('Throw'),
          ),
        ],
      );
    }

    return widget.child;
  }
}

/// ErrorZoneWidget whose fallback is provided by a builder. Used to construct
/// custom fallbacks (including ones that throw or that contain a throwing
/// descendant) for nested escalation tests.
class CustomFallbackErrorZoneWidget
    extends ErrorZoneWidget<({Object? error})> {
  CustomFallbackErrorZoneWidget({
    super.key,
    required this.fallback,
    required this.child,
  });

  final Widget Function(Object error) fallback;
  final Widget child;

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  Widget build(BuildContext context) {
    final error = state.error;
    if (error != null) {
      return fallback(error);
    }
    return child;
  }
}

/// StatefulZoneWidget that throws Exception when button is pressed
/// This tests the case where error occurs outside of initial performRebuild
class ButtonThrowingFutureErrorWidget extends StatefulZoneWidget {
  const ButtonThrowingFutureErrorWidget({
    super.key,
    required this.errorMessage,
  });

  final String errorMessage;

  @override
  State<ButtonThrowingFutureErrorWidget> createState() =>
      _ButtonThrowingFutureErrorWidgetState();
}

class _ButtonThrowingFutureErrorWidgetState
    extends State<ButtonThrowingFutureErrorWidget> {
  bool _shouldThrow = false;

  @override
  Widget build(BuildContext context) {
    if (_shouldThrow) {
      // Throw Exception after initial build
      // At this point, _isDuringPerformRebuild is false
      throw Exception(widget.errorMessage);
    }

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _shouldThrow = true;
        });
      },
      child: const Text('Throw Exception'),
    );
  }
}
