import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/sliver_test_widgets.dart';

void main() {
  group('SliverZoneWidget', () {
    group('given a SliverZoneWidget that throws Future', () {
      group('when placed inside a CustomScrollView and AsyncZone', () {
        testWidgets('should catch and show fallback', (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'Loaded',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Fallback'),
                child: CustomScrollView(
                  slivers: [
                    SliverThrowingZoneWidget(future: future),
                  ],
                ),
              ),
            ),
          );

          // Then - initially shows fallback
          expect(find.text('Fallback'), findsOneWidget);
          expect(find.text('Loaded'), findsNothing);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows sliver content with result
          expect(find.text('Loaded'), findsOneWidget);
          expect(find.text('Fallback'), findsNothing);
        });
      });
    });

    group('given a SliverStatefulZoneWidget that throws Future', () {
      group('when placed inside a CustomScrollView and AsyncZone', () {
        testWidgets('should handle correctly', (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'Stateful Sliver Result',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Stateful Loading...'),
                child: CustomScrollView(
                  slivers: [
                    SliverStatefulThrowingZoneWidget(future: future),
                  ],
                ),
              ),
            ),
          );

          // Then - initially shows fallback
          expect(find.text('Stateful Loading...'), findsOneWidget);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows result
          expect(find.text('Stateful Sliver Result'), findsOneWidget);
        });
      });
    });

    group('given a SliverZoneBuilder', () {
      group('when builder throws Future', () {
        testWidgets('should suspend and resume inline', (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'Inline Sliver',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Inline Fallback'),
                child: CustomScrollView(
                  slivers: [
                    SliverZoneBuilder(
                      builder: (context) {
                        final value = AsyncZone.of(context).use(future);
                        return SliverToBoxAdapter(child: Text(value));
                      },
                    ),
                  ],
                ),
              ),
            ),
          );

          // Then - initially shows fallback
          expect(find.text('Inline Fallback'), findsOneWidget);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows inline sliver content
          expect(find.text('Inline Sliver'), findsOneWidget);
        });
      });
    });

    group('given two sliver children both suspending concurrently', () {
      testWidgets(
        'should show fallback once and resume both after futures resolve',
        (tester) async {
          // Given
          final future1 = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'First',
          );
          final future2 = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'Second',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading slivers'),
                child: CustomScrollView(
                  slivers: [
                    SliverThrowingZoneWidget(future: future1),
                    SliverThrowingZoneWidget(future: future2),
                  ],
                ),
              ),
            ),
          );

          // Then - fallback covers the suspended subtree
          expect(find.text('Loading slivers'), findsOneWidget);
          expect(find.text('First'), findsNothing);
          expect(find.text('Second'), findsNothing);

          // When - both futures complete
          await tester.pump(const Duration(milliseconds: 50));

          // Then - both sliver values shown
          expect(find.text('First'), findsOneWidget);
          expect(find.text('Second'), findsOneWidget);
        },
      );
    });

    group(
      'given a non-suspending sliver alongside a suspending sliver',
      () {
        testWidgets(
          'should keep the layout valid (SliverEmpty contributes zero extent)',
          (tester) async {
            // Given
            final future = Future.delayed(
              const Duration(milliseconds: 50),
              () => 'Resolved',
            );

            await tester.pumpWidget(
              MaterialApp(
                home: AsyncZone(
                  fallback: const Text('Loading'),
                  child: CustomScrollView(
                    slivers: [
                      SliverThrowingZoneWidget(future: future),
                      const SliverToBoxAdapter(child: Text('Static below')),
                    ],
                  ),
                ),
              ),
            );

            // Then - fallback covers the suspended sliver subtree.
            // The static sliver remains in the element tree but is hidden
            // by AsyncZone's overlay.
            expect(find.text('Loading'), findsOneWidget);

            // When - future resolves
            await tester.pump(const Duration(milliseconds: 50));

            // Then - both slivers visible in order
            expect(find.text('Resolved'), findsOneWidget);
            expect(find.text('Static below'), findsOneWidget);
          },
        );
      },
    );

    group('given a SliverZoneWidget that gets a new future on rebuild', () {
      testWidgets('should supersede the old future and load the new one', (
        tester,
      ) async {
        // Given - initial future
        final firstFuture = Future.delayed(
          const Duration(milliseconds: 50),
          () => 'First',
        );

        Widget buildWith(Future<String> f) => MaterialApp(
          home: AsyncZone(
            fallback: const Text('Loading'),
            child: CustomScrollView(slivers: [SliverThrowingZoneWidget(future: f)]),
          ),
        );

        await tester.pumpWidget(buildWith(firstFuture));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('First'), findsOneWidget);

        // When - rebuild with a different future
        final secondFuture = Future.delayed(
          const Duration(milliseconds: 50),
          () => 'Second',
        );
        await tester.pumpWidget(buildWith(secondFuture));

        // Then - fallback while the new future is pending
        expect(find.text('Loading'), findsOneWidget);
        expect(find.text('First'), findsNothing);

        // When - new future completes
        await tester.pump(const Duration(milliseconds: 50));

        // Then - new value shown
        expect(find.text('Second'), findsOneWidget);
      });
    });

    group('given a nested AsyncZone with a sliver leaf inside', () {
      testWidgets(
        'should show only the inner fallback when the sliver leaf suspends',
        (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'Inner data',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('outer fallback'),
                child: Column(
                  children: [
                    const Text('static sibling'),
                    AsyncZone(
                      fallback: const Text('inner fallback'),
                      child: CustomScrollView(
                        shrinkWrap: true,
                        slivers: [SliverThrowingZoneWidget(future: future)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // Then - inner fallback covers the sliver subtree; outer is idle
          expect(find.text('inner fallback'), findsOneWidget);
          expect(find.text('outer fallback'), findsNothing);
          expect(find.text('static sibling'), findsOneWidget);

          // When - the inner future resolves
          await tester.pump(const Duration(milliseconds: 50));

          // Then - sliver content shown, outer still untouched
          expect(find.text('Inner data'), findsOneWidget);
          expect(find.text('inner fallback'), findsNothing);
          expect(find.text('outer fallback'), findsNothing);
          expect(find.text('static sibling'), findsOneWidget);
        },
      );
    });

    group('given a SliverZoneWidget that calls use() multiple times', () {
      testWidgets(
        'should suspend until every awaited future completes',
        (tester) async {
          // Given
          final future1 = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'A',
          );
          final future2 = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'B',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading'),
                child: CustomScrollView(
                  slivers: [
                    SliverMultipleFuturesZoneWidget(
                      future1: future1,
                      future2: future2,
                    ),
                  ],
                ),
              ),
            ),
          );

          // Then - fallback while either future is still pending
          expect(find.text('Loading'), findsOneWidget);

          // When - only the first future completes. A second pump lets the
          // post-frame markNeedsBuild scheduled by the freshly-thrown
          // future2 land before we assert.
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();

          // Then - still fallback (use(future2) throws on rebuild)
          expect(find.text('Loading'), findsOneWidget);
          expect(find.text('A'), findsNothing);
          expect(find.text('B'), findsNothing);

          // When - the second future completes
          await tester.pump(const Duration(milliseconds: 50));

          // Then - both values rendered
          expect(find.text('A'), findsOneWidget);
          expect(find.text('B'), findsOneWidget);
          expect(find.text('Loading'), findsNothing);
        },
      );
    });
  });
}
