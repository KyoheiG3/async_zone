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

