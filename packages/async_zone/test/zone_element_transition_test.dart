import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_widgets.dart';
import 'helpers/transition_test_widgets.dart';

void main() {
  group('ZoneElement inside an active TransitionZoneProvider', () {
    testWidgets(
      'extends the transition: track on suspend, supersede on subsequent '
      'swap, hold the subtree until isPending flips false',
      (tester) async {
        // Given - a ZoneElement that has committed a build (futureA
        // already resolved), wrapped in a [PendingHost] whose bridge can
        // be flipped between in-transition and idle from the test.
        final bridge = FakeTransitionZoneBridge();
        final futureA = Future.value('A');
        var current = futureA;
        late StateSetter setOuter;
        final hostKey = GlobalKey<PendingHostState>();

        await tester.pumpWidget(
          MaterialApp(
            home: PendingHost(
              key: hostKey,
              bridge: bridge,
              child: AsyncZone(
                fallback: const Text('FALLBACK'),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setOuter = setState;
                    return ThrowingZoneWidget(future: current);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('A'), findsOneWidget);

        // When - the bridge becomes in-transition and isPending flips on;
        // a slow future is swapped in.
        bridge.inTransition = true;
        hostKey.currentState!.setPending(true);
        final futureB = Future.delayed(
          const Duration(milliseconds: 200),
          () => 'B',
        );
        setOuter(() {
          current = futureB;
        });
        await tester.pump();

        // Then - the bridge received track(futureB); the previous subtree
        // is preserved and the AsyncZone fallback is *not* shown.
        expect(bridge.tracked, contains(futureB));
        expect(bridge.superseded, isEmpty);
        expect(find.text('A'), findsOneWidget);
        expect(find.text('FALLBACK'), findsNothing);

        // When - before futureB resolves, swap to a faster futureC.
        final futureC = Future.delayed(
          const Duration(milliseconds: 50),
          () => 'C',
        );
        setOuter(() {
          current = futureC;
        });
        await tester.pump();

        // Then - futureB was superseded on the bridge and futureC was
        // tracked. The element is still holding the previous subtree.
        expect(bridge.superseded, contains(futureB));
        expect(bridge.tracked, contains(futureC));
        expect(find.text('A'), findsOneWidget);

        // When - futureC resolves; the element clears its local tasks but
        // [_extending] keeps the subtree held while isPending is still
        // true.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('A'), findsOneWidget);
        expect(find.text('C'), findsNothing);

        // When - the transition fully settles (isPending flips false).
        bridge.inTransition = false;
        hostKey.currentState!.setPending(false);
        await tester.pump();

        // Then - the queued subtree commits.
        expect(find.text('C'), findsOneWidget);
        expect(find.text('A'), findsNothing);

        // Drain pending timers from futureB so the test ends cleanly.
        await tester.pump(const Duration(milliseconds: 200));
      },
    );

    testWidgets(
      'on a fresh mount during an active transition, routes the future to '
      'the AsyncZone fallback rather than extending the transition',
      (tester) async {
        // Given - a transition is already active before the ZoneElement
        // ever commits a build (a re-mount scenario).
        final bridge = FakeTransitionZoneBridge(
          inTransition: true,
          isPending: true,
        );
        final future = Future.delayed(
          const Duration(milliseconds: 100),
          () => 'NEW',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TransitionZoneProvider(
              bridge: bridge,
              isPending: true,
              child: AsyncZone(
                fallback: const Text('FALLBACK'),
                child: ThrowingZoneWidget(future: future),
              ),
            ),
          ),
        );
        await tester.pump();

        // Then - bridge was *not* asked to track this future (no prior
        // subtree to preserve), and the AsyncZone fallback is shown
        // instead.
        expect(bridge.tracked, isEmpty);
        expect(find.text('FALLBACK'), findsOneWidget);

        // Drain pending timer.
        await tester.pump(const Duration(milliseconds: 150));
      },
    );
  });
}
