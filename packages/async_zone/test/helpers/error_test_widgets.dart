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

/// Widget that conditionally throws or shows normal state
class ConditionalThrowingWidget extends StatefulZoneWidget {
  const ConditionalThrowingWidget({super.key});

  @override
  State<ConditionalThrowingWidget> createState() =>
      _ConditionalThrowingWidgetState();
}

class _ConditionalThrowingWidgetState extends State<ConditionalThrowingWidget> {
  var _shouldThrow = true;

  @override
  Widget build(BuildContext context) {
    if (_shouldThrow) {
      _shouldThrow = false;
      throw 'Test error';
    }
    return const Text('Normal state');
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

/// Widget that throws multiple errors
class MultipleThrowingWidget extends StatelessWidget {
  const MultipleThrowingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    throw 'First error';
  }
}

/// Custom ErrorZoneWidget implementation with state tracking
typedef CustomErrorState = ({int errorCount, Object? lastError});

class CustomErrorZoneWidget extends ErrorZoneWidget<CustomErrorState> {
  CustomErrorZoneWidget({super.key});

  @override
  CustomErrorState getDerivedStateFromError(Object? error) {
    return (errorCount: error != null ? 1 : 0, lastError: error);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Error count: ${state.errorCount}'),
        if (state.lastError != null)
          Text('Last error: ${state.lastError}')
        else
          const Text('No error'),
        Text(state.lastError != null ? 'Has error' : 'No error'),
        ElevatedButton(
          onPressed: () => throw 'Test error',
          child: const Text('Throw Error'),
        ),
      ],
    );
  }
}

/// ErrorZoneWidget that tracks componentDidCatch calls
typedef ComponentDidCatchState = ({Object? error});

class ComponentDidCatchWidget extends ErrorZoneWidget<ComponentDidCatchState> {
  ComponentDidCatchWidget({super.key});

  @override
  ComponentDidCatchState getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  void componentDidCatch(Object error, StackTrace stackTrace) {
    // componentDidCatch is called when error occurs
    // In a real app, you might log to analytics here
  }

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Text('Error: ${state.error}');
    }

    return ElevatedButton(
      onPressed: () => throw 'Test error',
      child: const Text('Throw'),
    );
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
        ],
      );
    }

    return widget.child;
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
