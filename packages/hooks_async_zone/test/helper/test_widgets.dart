import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_async_zone/hooks_async_zone.dart';

// Helper widgets for useZone tests

class SimpleHookZoneWidget extends HookZoneWidget {
  const SimpleHookZoneWidget({
    super.key,
    required this.future,
    required this.builder,
  });

  final Future<String> future;
  final Widget Function(String data) builder;

  @override
  Widget build(BuildContext context) {
    final data = useZone(future);
    return builder(data);
  }
}

class MultipleHookZoneWidget extends HookZoneWidget {
  const MultipleHookZoneWidget({
    super.key,
    required this.future1,
    required this.future2,
  });

  final Future<String> future1;
  final Future<String> future2;

  @override
  Widget build(BuildContext context) {
    final data1 = useZone(future1);
    final data2 = useZone(future2);
    return Text('$data1 - $data2');
  }
}

// Helper widgets for HookZoneWidget tests

class TestHookZoneWidget extends HookZoneWidget {
  const TestHookZoneWidget({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final counter = useState(0);
    final data = useZone(future);

    return Column(
      children: [
        Text('Counter: ${counter.value}'),
        Text(data),
        ElevatedButton(
          onPressed: () => counter.value++,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}

// Helper widgets for StatefulHookZoneWidget tests

class TestStatefulHookZoneWidget extends StatefulHookZoneWidget {
  const TestStatefulHookZoneWidget({super.key, required this.future});

  final Future<String> future;

  @override
  State<TestStatefulHookZoneWidget> createState() =>
      _TestStatefulHookZoneWidgetState();
}

class _TestStatefulHookZoneWidgetState
    extends State<TestStatefulHookZoneWidget> {
  String _stateValue = 'Initial';

  @override
  Widget build(BuildContext context) {
    final data = useZone(widget.future);

    return Column(
      children: [
        Text('State: $_stateValue'),
        Text(data),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _stateValue = 'Updated';
            });
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

// Helper widgets for error handling tests

class ErrorThrowingWidget extends ZoneWidget {
  const ErrorThrowingWidget({
    super.key,
    required this.shouldThrow,
    this.errorMessage = 'Test error',
  });

  final bool shouldThrow;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return const Text('Normal');
  }
}

// Helper widgets for HookErrorZoneWidget tests

class TestHookErrorZoneWidgetWithError
    extends HookErrorZoneWidget<({Object? error})> {
  TestHookErrorZoneWidgetWithError({
    super.key,
    required this.shouldThrow,
    this.onReset,
  });

  final bool shouldThrow;
  final VoidCallback? onReset;

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Column(
        children: [
          Text('Error: ${state.error}'),
          ElevatedButton(
            onPressed: () {
              resetErrorBoundary();
              onReset?.call();
            },
            child: const Text('Reset'),
          ),
        ],
      );
    }
    return ErrorThrowingWidget(shouldThrow: shouldThrow);
  }
}

class TestHookErrorZoneWidgetWithCounter
    extends HookErrorZoneWidget<({Object? error})> {
  TestHookErrorZoneWidgetWithCounter({super.key});

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  Widget build(BuildContext context) {
    final counter = useState(0);

    if (state.error != null) {
      return Text('Error: ${state.error}');
    }

    return Column(
      children: [
        Text('Counter: ${counter.value}'),
        ElevatedButton(
          onPressed: () => counter.value++,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}

// Helper widgets for StatefulHookErrorZoneWidget tests

class TestStatefulHookErrorZoneWidgetWithError
    extends StatefulHookErrorZoneWidget<({Object? error})> {
  TestStatefulHookErrorZoneWidgetWithError({
    super.key,
    required this.shouldThrow,
  });

  final bool shouldThrow;

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  State<TestStatefulHookErrorZoneWidgetWithError> createState() =>
      _TestStatefulHookErrorZoneWidgetWithErrorState();
}

class _TestStatefulHookErrorZoneWidgetWithErrorState
    extends State<TestStatefulHookErrorZoneWidgetWithError> {
  @override
  Widget build(BuildContext context) {
    if (widget.state.error != null) {
      return Text('Stateful Error: ${widget.state.error}');
    }
    return ErrorThrowingWidget(
      shouldThrow: widget.shouldThrow,
      errorMessage: 'Stateful error',
    );
  }
}

class TestStatefulHookErrorZoneWidgetWithCounter
    extends StatefulHookErrorZoneWidget<({Object? error})> {
  TestStatefulHookErrorZoneWidgetWithCounter({super.key});

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  State<TestStatefulHookErrorZoneWidgetWithCounter> createState() =>
      _TestStatefulHookErrorZoneWidgetWithCounterState();
}

class _TestStatefulHookErrorZoneWidgetWithCounterState
    extends State<TestStatefulHookErrorZoneWidgetWithCounter> {
  @override
  Widget build(BuildContext context) {
    final counter = useState(0);

    if (widget.state.error != null) {
      return Text('Error: ${widget.state.error}');
    }

    return Text('Hook Counter: ${counter.value}');
  }
}
