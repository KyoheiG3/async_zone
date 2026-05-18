import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/transition_test_widgets.dart';

void main() {
  group('TransitionZone.of', () {
    testWidgets(
        'throws a FlutterError when context is not a TransitionZoneWidget '
        'context', (tester) async {
      late Object? caught;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              try {
                TransitionZone.of(context);
              } catch (error) {
                caught = error;
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(caught, isA<FlutterError>());
      expect(
        (caught! as FlutterError).toString(),
        contains('must be called with a TransitionZoneWidget context'),
      );
    });

    testWidgets(
      'throws when called from a descendant context even with a '
      'TransitionZoneWidget ancestor',
      (tester) async {
        late Object? caught;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: TransitionZoneBuilder(
              builder: (_) {
                return Builder(
                  builder: (descendantContext) {
                    try {
                      TransitionZone.of(descendantContext);
                    } catch (error) {
                      caught = error;
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        );
        expect(caught, isA<FlutterError>());
      },
    );

    testWidgets('returns the element itself when called with the bearing '
        'element', (tester) async {
      late BuildContext bearingContext;
      late TransitionZoneScope captured;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _ContextProbeTransitionZone(
            onBuild: (context) {
              bearingContext = context;
              captured = TransitionZone.of(context);
            },
          ),
        ),
      );
      // The build context passed to a TransitionZoneWidget subclass's build
      // is the mixed-in element itself, which implements TransitionZoneScope.
      expect(bearingContext, isA<TransitionZoneScope>());
      expect(identical(captured, bearingContext), isTrue);
    });
  });

  group('TransitionZone.bridgeOf', () {
    testWidgets('returns null when no TransitionZoneWidget is in the tree',
        (tester) async {
      late TransitionZoneBridge? bridge;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              bridge = TransitionZone.bridgeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(bridge, isNull);
    });

    testWidgets('returns the scope and short-circuits when context is itself '
        'a bridge', (tester) async {
      late TransitionZoneBridge? bridgeFromBearing;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TransitionZoneBuilder(
            builder: (context) {
              bridgeFromBearing = TransitionZone.bridgeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(bridgeFromBearing, isNotNull);
      expect(bridgeFromBearing!.inTransition, isFalse);
    });

    testWidgets('finds the bridge from a descendant context', (tester) async {
      late TransitionZoneBridge? bridgeFromDescendant;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TransitionZoneBuilder(
            builder: (_) {
              return Builder(
                builder: (descendantContext) {
                  bridgeFromDescendant =
                      TransitionZone.bridgeOf(descendantContext);
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      );
      expect(bridgeFromDescendant, isNotNull);
      expect(bridgeFromDescendant!.inTransition, isFalse);
    });
  });

  group('startTransition without a tracked future', () {
    testWidgets('runs action synchronously and never surfaces isPending',
        (tester) async {
      final log = <bool>[];
      late TransitionZoneScope scope;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TransitionZoneBuilder(
            builder: (context) {
              scope = TransitionZone.of(context);
              return IsPendingProbe(scope: scope, log: log);
            },
          ),
        ),
      );
      expect(log, [false]);

      var actionRan = false;
      scope.startTransition(() => actionRan = true);
      // [action] runs synchronously regardless of whether anything ends up
      // tracked.
      expect(actionRan, isTrue);

      // Without a tracked future the transition ends silently — descendants
      // never observe isPending == true, mirroring React's useTransition.
      // The two-phase performRebuild still triggers a follow-up build that
      // the probe observes, but only ever as false.
      await tester.pumpAndSettle();
      expect(scope.isPending, isFalse);
      expect(log.contains(true), isFalse);
    });

    testWidgets('runs nested startTransition action synchronously',
        (tester) async {
      late TransitionZoneScope scope;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TransitionZoneBuilder(
            builder: (context) {
              scope = TransitionZone.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      var outerActionRan = false;
      var innerActionRan = false;
      var innerRanInsideOuter = false;
      scope.startTransition(() {
        // Calling startTransition inside a transition runs the inner
        // synchronously.
        scope.startTransition(() => innerActionRan = true);
        innerRanInsideOuter = innerActionRan;
        outerActionRan = true;
      });
      await tester.pumpAndSettle();
      expect(outerActionRan, isTrue);
      expect(innerActionRan, isTrue);
      expect(innerRanInsideOuter, isTrue);
    });
  });

  group('startTransition with AsyncZone integration', () {
    testWidgets(
      'keeps the previous subtree visible and never shows the AsyncZone '
      'fallback while the new future is pending',
      (tester) async {
        final futureA = Future.value('A');
        final futureB = Future.delayed(
          const Duration(milliseconds: 200),
          () => 'B',
        );

        late FutureHostController controller;
        late TransitionZoneScope scope;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: TransitionZoneBuilder(
              builder: (context) {
                scope = TransitionZone.of(context);
                return AsyncZone(
                  fallback: const Text(
                    'FALLBACK',
                    textDirection: TextDirection.ltr,
                  ),
                  child: FutureHost(
                    initial: futureA,
                    scope: scope,
                    controllerOut: (c) => controller = c,
                    builder: (context, future) => DataView(future: future),
                  ),
                );
              },
            ),
          ),
        );

        // Resolve the initial future.
        await tester.pump();
        await tester.pump();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('FALLBACK'), findsNothing);

        // Swap to a pending future from inside a transition.
        controller.swap(futureB);
        await tester.pump();
        expect(scope.isPending, isTrue);

        // While the transition is in flight, the previous data stays visible
        // and the AsyncZone fallback is suppressed.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('A'), findsOneWidget);
        expect(find.text('FALLBACK'), findsNothing);
        expect(scope.isPending, isTrue);

        // After the future resolves the new UI shows and isPending clears.
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('B'), findsOneWidget);
        expect(find.text('A'), findsNothing);
        expect(scope.isPending, isFalse);
      },
    );

    testWidgets(
      'a second startTransition supersedes the previous future so the '
      'transition ends when the latest future resolves, not when both do',
      (tester) async {
        final futureA = Future.value('A');
        final futureB = Future.delayed(
          const Duration(milliseconds: 500),
          () => 'B',
        );
        final futureC = Future.delayed(
          const Duration(milliseconds: 100),
          () => 'C',
        );

        late FutureHostController controller;
        late TransitionZoneScope scope;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: TransitionZoneBuilder(
              builder: (context) {
                scope = TransitionZone.of(context);
                return AsyncZone(
                  fallback: const Text(
                    'FALLBACK',
                    textDirection: TextDirection.ltr,
                  ),
                  child: FutureHost(
                    initial: futureA,
                    scope: scope,
                    controllerOut: (c) => controller = c,
                    builder: (context, future) => DataView(future: future),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump();
        expect(find.text('A'), findsOneWidget);

        // Start a transition with the slow futureB.
        controller.swap(futureB);
        await tester.pump();
        expect(scope.isPending, isTrue);

        // Before futureB resolves, supersede it with the faster futureC.
        controller.swap(futureC);
        await tester.pump();
        expect(scope.isPending, isTrue);

        // After futureC resolves (~100ms), the transition should end even
        // though futureB (500ms) is still pending. If supersede weren't
        // wired up, isPending would stay true until futureB also resolved.
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('C'), findsOneWidget);
        expect(scope.isPending, isFalse);

        // Let the still-pending futureB resolve so the test framework
        // doesn't flag a leftover timer at teardown.
        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    testWidgets(
      'without a surrounding transition, swapping shows the AsyncZone '
      'fallback as usual',
      (tester) async {
        final futureA = Future.value('A');
        final futureB = Future.delayed(
          const Duration(milliseconds: 200),
          () => 'B',
        );

        late FutureHostController controller;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: TransitionZoneBuilder(
              builder: (context) {
                final scope = TransitionZone.of(context);
                return AsyncZone(
                  fallback: const Text(
                    'FALLBACK',
                    textDirection: TextDirection.ltr,
                  ),
                  child: FutureHost(
                    initial: futureA,
                    scope: scope,
                    controllerOut: (c) => controller = c,
                    builder: (context, future) => DataView(future: future),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('A'), findsOneWidget);

        controller.swap(futureB, inTransition: false);
        // FutureHost rebuilds and the descendant DataView throws; AsyncZone
        // tracks the future and schedules its fallback rebuild for the next
        // frame. The follow-up pump lets the fallback materialise.
        await tester.pump();
        await tester.pump();
        expect(find.text('FALLBACK'), findsOneWidget);
        expect(find.text('A', skipOffstage: true), findsNothing);

        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('B'), findsOneWidget);
        expect(find.text('FALLBACK'), findsNothing);
      },
    );
  });

  group('startTransition that mounts a fresh suspending subtree', () {
    testWidgets(
      'shows the AsyncZone fallback and never surfaces isPending when there '
      'is no previously committed subtree to preserve',
      (tester) async {
        final future = Future.delayed(
          const Duration(milliseconds: 200),
          () => 'NEW',
        );

        final pendingValues = <bool>[];
        late TransitionZoneScope scope;
        late void Function(VoidCallback fn) setOuterState;
        var showZone = false;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: TransitionZoneBuilder(
              builder: (context) {
                scope = TransitionZone.of(context);
                pendingValues.add(scope.isPending);
                return StatefulBuilder(
                  builder: (context, setState) {
                    setOuterState = setState;
                    if (!showZone) {
                      return const Text(
                        'GATE',
                        textDirection: TextDirection.ltr,
                      );
                    }
                    return AsyncZone(
                      fallback: const Text(
                        'FALLBACK',
                        textDirection: TextDirection.ltr,
                      ),
                      child: DataView(future: future),
                    );
                  },
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(find.text('GATE'), findsOneWidget);
        expect(pendingValues, [false]);

        // Toggle the gate inside a transition: the AsyncZone + DataView
        // mount fresh for the first time. There is no previously committed
        // subtree to preserve, so the transition's fallback-suppression
        // should be skipped — the AsyncZone fallback surfaces and the
        // transition ends silently without flipping isPending.
        scope.startTransition(() {
          setOuterState(() => showZone = true);
        });
        await tester.pump();
        await tester.pump();
        expect(find.text('FALLBACK'), findsOneWidget);
        expect(find.text('GATE'), findsNothing);
        expect(scope.isPending, isFalse);
        expect(pendingValues.contains(true), isFalse);

        // After the future resolves the AsyncZone swaps in the new content.
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('NEW'), findsOneWidget);
        expect(find.text('FALLBACK'), findsNothing);
        expect(scope.isPending, isFalse);
      },
    );
  });

  group('TransitionZoneElement mixin', () {
    testWidgets(
      'can be composed onto a custom StatefulElement and the produced '
      'BuildContext acts as a TransitionZoneScope',
      (tester) async {
        late BuildContext capturedBuildContext;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: _StatefulTransitionHost(
              onBuild: (context) => capturedBuildContext = context,
            ),
          ),
        );
        expect(capturedBuildContext, isA<TransitionZoneScope>());
        expect(capturedBuildContext, isA<TransitionZoneBridge>());
      },
    );
  });

  group('TransitionZoneProvider.maybeOf', () {
    testWidgets('returns null when there is no provider', (tester) async {
      late TransitionZoneBridge? bridge;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              bridge = TransitionZoneProvider.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(bridge, isNull);
    });
  });
}

/// A [TransitionZoneWidget] subclass that forwards its build context to a
/// hook.
class _ContextProbeTransitionZone extends TransitionZoneWidget {
  const _ContextProbeTransitionZone({required this.onBuild});

  final ValueChanged<BuildContext> onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return const SizedBox.shrink();
  }
}

/// A [StatefulWidget] whose element mixes in [TransitionZoneElement]
/// directly.
class _StatefulTransitionHost extends StatefulWidget {
  const _StatefulTransitionHost({required this.onBuild});

  final ValueChanged<BuildContext> onBuild;

  @override
  StatefulElement createElement() => StatefulTransitionZoneElement(this);

  @override
  State<_StatefulTransitionHost> createState() =>
      _StatefulTransitionHostState();
}

class _StatefulTransitionHostState extends State<_StatefulTransitionHost> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild(context);
    return const SizedBox.shrink();
  }
}
