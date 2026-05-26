import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';

/// Minimal [TransitionZoneBridge] for tests that just need an identity to
/// pass through [TransitionZoneProvider].
class FakeTransitionZoneBridge implements TransitionZoneBridge {
  FakeTransitionZoneBridge({this.inTransition = false, this.isPending = false});

  @override
  bool isPending;

  @override
  bool inTransition;

  final List<Future<dynamic>> tracked = [];
  final List<Future<dynamic>> superseded = [];

  @override
  void track(Future<dynamic> future) {
    tracked.add(future);
  }

  @override
  void supersede(Future<dynamic> future) {
    superseded.add(future);
    tracked.remove(future);
  }
}

/// Hosts a [TransitionZoneProvider] whose `isPending` can be flipped from a
/// test via [PendingHostState.setPending], without rebuilding [child]. The
/// host keeps the [FakeTransitionZoneBridge]'s `isPending` in sync with the
/// provider's value so a `ZoneElement` reading either sees the same state.
class PendingHost extends StatefulWidget {
  const PendingHost({super.key, required this.bridge, required this.child});

  final FakeTransitionZoneBridge bridge;
  final Widget child;

  @override
  State<PendingHost> createState() => PendingHostState();
}

class PendingHostState extends State<PendingHost> {
  bool _isPending = false;

  void setPending(bool value) {
    setState(() {
      _isPending = value;
      widget.bridge.isPending = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TransitionZoneProvider(
      bridge: widget.bridge,
      isPending: _isPending,
      child: widget.child,
    );
  }
}
