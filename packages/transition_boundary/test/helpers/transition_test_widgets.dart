import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';
import 'package:transition_boundary/transition_boundary.dart';

/// Reads `TransitionZone.of(context).isPending` and pushes every observed
/// value into [log], then renders a [Text] of the current value.
class IsPendingProbe extends StatelessWidget {
  const IsPendingProbe({super.key, required this.log});

  final List<bool> log;

  @override
  Widget build(BuildContext context) {
    final isPending = TransitionZone.of(context).isPending;
    log.add(isPending);
    return Text(
      isPending ? 'pending' : 'idle',
      textDirection: TextDirection.ltr,
    );
  }
}

/// A [ZoneWidget] that throws [future] via `AsyncZone.of(context).use(...)`.
class DataView extends ZoneWidget {
  const DataView({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(future);
    return Text(value, textDirection: TextDirection.ltr);
  }
}

/// A [ZoneWidget] that itself does *not* suspend but reads `isPending` from
/// the surrounding transition. Used to verify that an outer [ZoneElement]
/// which only depends on `isPending` still propagates its rebuild to its
/// subtree while the transition is pending.
class IsPendingZoneProbe extends ZoneWidget {
  const IsPendingZoneProbe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isPending = TransitionZone.of(context).isPending;
    return Column(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(isPending ? 'PENDING' : 'IDLE', textDirection: TextDirection.ltr),
        child,
      ],
    );
  }
}

/// Holds a swappable future and exposes a controller that the test uses to
/// trigger swaps. Swaps in `inTransition` mode route through
/// `TransitionZone.of(context).startTransition`.
class FutureHost extends StatefulWidget {
  const FutureHost({
    super.key,
    required this.initial,
    required this.builder,
    required this.controllerOut,
  });

  final Future<String> initial;
  final Widget Function(BuildContext context, Future<String> future) builder;
  final void Function(FutureHostController controller) controllerOut;

  @override
  State<FutureHost> createState() => _FutureHostState();
}

class FutureHostController {
  FutureHostController._(this._swap);
  final void Function(
    Future<String> next,
    bool inTransition,
    bool asyncAction,
    Duration? actionDelay,
  )
  _swap;

  void swap(
    Future<String> next, {
    bool inTransition = true,
    bool asyncAction = false,
    Duration? actionDelay,
  }) => _swap(next, inTransition, asyncAction, actionDelay);
}

class _FutureHostState extends State<FutureHost> {
  late Future<String> _future = widget.initial;

  @override
  void initState() {
    super.initState();
    widget.controllerOut(FutureHostController._(_swap));
  }

  void _swap(
    Future<String> next,
    bool inTransition,
    bool asyncAction,
    Duration? actionDelay,
  ) {
    void apply() {
      setState(() {
        _future = next;
      });
    }

    if (inTransition) {
      final scope = TransitionZone.of(context);
      if (asyncAction) {
        scope.startTransition(() async {
          apply();
          if (actionDelay != null) await Future.delayed(actionDelay);
        });
      } else {
        scope.startTransition(apply);
      }
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _future);
}
