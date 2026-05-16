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

class NullableTestWidget extends ZoneWidget {
  const NullableTestWidget({super.key, required this.future});

  final Future<String?> future;

  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(future);
    return Text(value ?? 'NULL');
  }
}

class NullableCachedTestWidget extends ZoneWidget {
  const NullableCachedTestWidget({super.key, required this.future});

  final Future<String?> future;

  @override
  Widget build(BuildContext context) {
    final value1 = AsyncZone.of(context).use(future);
    final value2 = AsyncZone.of(context).use(future);
    return Text('${value1 ?? 'NULL'}-${value2 ?? 'NULL'}');
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

/// Widget that calls `use()` with the `freeze` flag exposed.
class FreezingTestWidget extends ZoneWidget {
  const FreezingTestWidget({
    super.key,
    required this.future,
    this.freeze = false,
  });

  final Future<String> future;
  final bool freeze;

  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(future, freeze: freeze);
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

