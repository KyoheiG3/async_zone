import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/transition_test_widgets.dart';

void main() {
  group('TransitionZoneProvider', () {
    group('maybeOf', () {
      group('given no TransitionZoneProvider in the tree', () {
        testWidgets('should return null', (tester) async {
          // Given
          TransitionZoneBridge? captured;

          // When
          await tester.pumpWidget(
            Builder(
              builder: (context) {
                captured = TransitionZoneProvider.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          );

          // Then
          expect(captured, isNull);
        });
      });

      group('given a TransitionZoneProvider in the tree', () {
        testWidgets('should return its bridge', (tester) async {
          // Given
          final bridge = FakeTransitionZoneBridge();
          TransitionZoneBridge? captured;

          // When
          await tester.pumpWidget(
            TransitionZoneProvider(
              bridge: bridge,
              isPending: false,
              child: Builder(
                builder: (context) {
                  captured = TransitionZoneProvider.maybeOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          // Then
          expect(captured, same(bridge));
        });
      });

      group('given nested TransitionZoneProviders', () {
        testWidgets('should return the bridge from the nearest ancestor', (
          tester,
        ) async {
          // Given
          final outer = FakeTransitionZoneBridge();
          final inner = FakeTransitionZoneBridge();
          TransitionZoneBridge? captured;

          // When
          await tester.pumpWidget(
            TransitionZoneProvider(
              bridge: outer,
              isPending: false,
              child: TransitionZoneProvider(
                bridge: inner,
                isPending: false,
                child: Builder(
                  builder: (context) {
                    captured = TransitionZoneProvider.maybeOf(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          );

          // Then
          expect(captured, same(inner));
        });
      });

      group('given a descendant Builder that calls maybeOf', () {
        group('when isPending changes', () {
          testWidgets('should not rebuild the descendant', (tester) async {
            // Given
            final bridge = FakeTransitionZoneBridge();
            var buildCount = 0;
            final consumer = Builder(
              builder: (context) {
                buildCount++;
                TransitionZoneProvider.maybeOf(context);
                return const SizedBox.shrink();
              },
            );

            await tester.pumpWidget(
              PendingHost(bridge: bridge, child: consumer),
            );
            expect(buildCount, 1);

            // When - flipping isPending rebuilds the provider and notifies
            // dependents
            final state = tester.state<PendingHostState>(
              find.byType(PendingHost),
            );
            state.setPending(true);
            await tester.pump();

            // Then - maybeOf did not subscribe, so the consumer stays put
            expect(buildCount, 1);
          });
        });
      });
    });

    group('updateShouldNotify', () {
      group('given isPending changed between old and new', () {
        test('should return true', () {
          // Given
          final bridge = FakeTransitionZoneBridge();
          const child = SizedBox.shrink();
          final previous = TransitionZoneProvider(
            bridge: bridge,
            isPending: false,
            child: child,
          );
          final next = TransitionZoneProvider(
            bridge: bridge,
            isPending: true,
            child: child,
          );

          // When
          final shouldNotify = next.updateShouldNotify(previous);

          // Then
          expect(shouldNotify, isTrue);
        });
      });

      group('given isPending unchanged but bridge instance differs', () {
        test('should return false', () {
          // Given - descendants don't depend on bridge identity, only on
          // isPending
          const child = SizedBox.shrink();
          final previous = TransitionZoneProvider(
            bridge: FakeTransitionZoneBridge(),
            isPending: true,
            child: child,
          );
          final next = TransitionZoneProvider(
            bridge: FakeTransitionZoneBridge(),
            isPending: true,
            child: child,
          );

          // When
          final shouldNotify = next.updateShouldNotify(previous);

          // Then
          expect(shouldNotify, isFalse);
        });
      });
    });
  });
}
