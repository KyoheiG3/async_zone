import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';

/// Reads [scope.isPending] and pushes every observed value into [log], then
/// renders a [Text] of the current value. Useful for asserting the sequence
/// of `isPending` values descendants observe across rebuilds.
class IsPendingProbe extends StatelessWidget {
  const IsPendingProbe({super.key, required this.scope, required this.log});

  final TransitionZoneScope scope;
  final List<bool> log;

  @override
  Widget build(BuildContext context) {
    log.add(scope.isPending);
    return Text(
      scope.isPending ? 'pending' : 'idle',
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

/// Holds a swappable future and exposes a controller that the test uses to
/// trigger swaps. When constructed with a [scope], swaps performed in
/// transition mode route through [TransitionZoneScope.startTransition].
class FutureHost extends StatefulWidget {
  const FutureHost({
    super.key,
    required this.initial,
    required this.scope,
    required this.builder,
    required this.controllerOut,
  });

  final Future<String> initial;

  /// The transition scope captured from the surrounding
  /// [TransitionZoneWidget].
  final TransitionZoneScope scope;
  final Widget Function(BuildContext context, Future<String> future) builder;
  final void Function(FutureHostController controller) controllerOut;

  @override
  State<FutureHost> createState() => _FutureHostState();
}

class FutureHostController {
  FutureHostController._(this._swap);
  final void Function(Future<String> next, bool inTransition) _swap;

  void swap(Future<String> next, {bool inTransition = true}) =>
      _swap(next, inTransition);
}

class _FutureHostState extends State<FutureHost> {
  late Future<String> _future = widget.initial;

  @override
  void initState() {
    super.initState();
    widget.controllerOut(FutureHostController._(_swap));
  }

  void _swap(Future<String> next, bool inTransition) {
    void apply() {
      setState(() {
        _future = next;
      });
    }

    if (inTransition) {
      widget.scope.startTransition(apply);
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _future);
}
