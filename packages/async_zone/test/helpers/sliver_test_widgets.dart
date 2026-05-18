import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';

class SliverThrowingZoneWidget extends SliverZoneWidget {
  const SliverThrowingZoneWidget({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(future);
    return SliverToBoxAdapter(child: Text(value));
  }
}

class SliverMultipleFuturesZoneWidget extends SliverZoneWidget {
  const SliverMultipleFuturesZoneWidget({
    super.key,
    required this.future1,
    required this.future2,
  });

  final Future<String> future1;
  final Future<String> future2;

  @override
  Widget build(BuildContext context) {
    final zone = AsyncZone.of(context);
    final v1 = zone.use(future1);
    final v2 = zone.use(future2);
    return SliverList.list(children: [Text(v1), Text(v2)]);
  }
}

class SliverStatefulThrowingZoneWidget extends SliverStatefulZoneWidget {
  const SliverStatefulThrowingZoneWidget({super.key, required this.future});

  final Future<String> future;

  @override
  State<SliverStatefulThrowingZoneWidget> createState() =>
      _SliverStatefulThrowingZoneWidgetState();
}

class _SliverStatefulThrowingZoneWidgetState
    extends State<SliverStatefulThrowingZoneWidget> {
  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(widget.future);
    return SliverToBoxAdapter(child: Text(value));
  }
}

