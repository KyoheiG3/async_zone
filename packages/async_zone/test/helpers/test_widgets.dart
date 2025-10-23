import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';

class TestWidget extends ZoneWidget {
  const TestWidget({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(future);
    return Text(value);
  }
}

class MultipleFuturesWidget extends ZoneWidget {
  const MultipleFuturesWidget({
    super.key,
    required this.future1,
    required this.future2,
  });

  final Future<String> future1;
  final Future<String> future2;

  @override
  Widget build(BuildContext context) {
    final value1 = AsyncZone.of(context).use(future1);
    final value2 = AsyncZone.of(context).use(future2);
    return Column(children: [Text(value1), Text(value2)]);
  }
}

class CachedTestWidget extends ZoneWidget {
  const CachedTestWidget({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final value1 = AsyncZone.of(context).use(future);
    final value2 = AsyncZone.of(context).use(future);
    return Text('$value1-$value2');
  }
}

class InvalidateCacheTestWidget extends StatefulZoneWidget {
  const InvalidateCacheTestWidget({
    super.key,
    required this.future,
    required this.onInvalidate,
  });

  final Future<String> future;
  final VoidCallback onInvalidate;

  @override
  State<InvalidateCacheTestWidget> createState() =>
      _InvalidateCacheTestWidgetState();
}

class _InvalidateCacheTestWidgetState extends State<InvalidateCacheTestWidget> {
  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(widget.future);
    return Column(
      children: [
        Text(value),
        ElevatedButton(
          onPressed: () {
            AsyncZone.of(context).invalidateCache();
            widget.onInvalidate();
          },
          child: const Text('Invalidate'),
        ),
      ],
    );
  }
}

class ThrowingZoneWidget extends ZoneWidget {
  const ThrowingZoneWidget({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(future);
    return Text(value);
  }
}

class StatefulThrowingWidget extends StatefulZoneWidget {
  const StatefulThrowingWidget({super.key, required this.future});

  final Future<String> future;

  @override
  State<StatefulThrowingWidget> createState() => _StatefulThrowingWidgetState();
}

class _StatefulThrowingWidgetState extends State<StatefulThrowingWidget> {
  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(widget.future);
    return Text(value);
  }
}

/// Widget that directly throws Future without using AsyncZone.of()
class DirectThrowingZoneWidget extends ZoneWidget {
  const DirectThrowingZoneWidget({super.key, required this.future});

  final Future future;

  @override
  Widget build(BuildContext context) {
    throw future;
  }
}
