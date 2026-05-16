import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_widgets.dart';

void main() {
  group('AsyncZone', () {
    group('given a single pending Future', () {
      group('when it completes successfully', () {
        testWidgets('should show child widget', (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Success',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: TestWidget(future: future),
              ),
            ),
          );

          // Then - initial state shows fallback
          expect(find.text('Loading...'), findsOneWidget);
          expect(find.text('Success'), findsNothing);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 100));

          // Then - shows child
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('Success'), findsOneWidget);
        });
      });

      group('when it completes with error', () {
        testWidgets('should handle error gracefully', (tester) async {
          // Given
          final future = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () => throw 'Test error',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Error fallback'),
                child: TestWidget(future: future),
              ),
            ),
          );

          // Then - initial state shows fallback
          expect(find.text('Error fallback'), findsOneWidget);

          // When - error occurs
          await tester.pump(const Duration(milliseconds: 50));
          tester.takeException(); // Clear the error

          // Then - error was handled
          expect(tester.takeException(), isNull);
        });

        testWidgets('should throw when use() is called again', (tester) async {
          // Given
          final future = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () => throw 'Test error',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Error fallback'),
                child: TestWidget(future: future),
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 50));

          // When - clear errors and rebuild with same error future
          await tester.pumpWidget(const SizedBox());

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Error fallback'),
                child: TestWidget(future: future),
              ),
            ),
          );

          // Then - should throw the error
          expect(tester.takeException(), 'Test error');
        });
      });

      group('when widget rebuilds', () {
        testWidgets('should preserve fallback state', (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Result',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: TestWidget(future: future),
              ),
            ),
          );

          // Then - initial state shows fallback
          expect(find.text('Loading...'), findsOneWidget);

          // When - rebuild during pending
          await tester.pump(const Duration(milliseconds: 50));

          // Then - should still show fallback
          expect(find.text('Loading...'), findsOneWidget);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows result
          expect(find.text('Result'), findsOneWidget);
        });
      });
    });

    group('given multiple pending Futures', () {
      group('when all complete', () {
        testWidgets('should show all results', (tester) async {
          // Given
          final future1 = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'First',
          );
          final future2 = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Second',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: MultipleFuturesWidget(
                  future1: future1,
                  future2: future2,
                ),
              ),
            ),
          );

          // Then - shows fallback while waiting
          expect(find.text('Loading...'), findsOneWidget);

          // When - after 50ms, future1 completes but future2 is still pending.
          // A second pump lets the post-frame markNeedsBuild scheduled by the
          // freshly-thrown future2 land before we assert.
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();

          // Then - should still show fallback because future2 is pending
          expect(find.text('Loading...'), findsOneWidget);
          expect(find.text('First'), findsNothing);
          expect(find.text('Second'), findsNothing);

          // When - after another 50ms, both futures complete
          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows all results
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('First'), findsOneWidget);
          expect(find.text('Second'), findsOneWidget);
        });
      });
    });

    group('given a completed Future', () {
      group('when use() is called multiple times', () {
        testWidgets('should return cached value', (tester) async {
          // Given
          var callCount = 0;
          final future = Future.delayed(const Duration(milliseconds: 50), () {
            callCount++;
            return 'Result';
          });

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: CachedTestWidget(future: future),
              ),
            ),
          );

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 50));

          // Then - should only call Future once and cache the result
          expect(callCount, 1);
          expect(find.text('Result-Result'), findsOneWidget);
        });
      });
    });

    group('given a Future resolving to null', () {
      testWidgets('should transition from fallback to the null value',
          (tester) async {
        // Given
        final future = Future<String?>.delayed(
          const Duration(milliseconds: 50),
          () => null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Loading...'),
              child: NullableTestWidget(future: future),
            ),
          ),
        );

        // Then - fallback is shown while pending
        expect(find.text('Loading...'), findsOneWidget);

        // When - Future completes with null
        await tester.pump(const Duration(milliseconds: 50));

        // Then - null is rendered without infinite suspend
        expect(find.text('Loading...'), findsNothing);
        expect(find.text('NULL'), findsOneWidget);
      });

      testWidgets('should cache the null value across use() calls',
          (tester) async {
        // Given
        var callCount = 0;
        final future = Future<String?>.delayed(
          const Duration(milliseconds: 50),
          () {
            callCount++;
            return null;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Loading...'),
              child: NullableCachedTestWidget(future: future),
            ),
          ),
        );

        // When - Future completes
        await tester.pump(const Duration(milliseconds: 50));

        // Then - Future is invoked once and the null result is cached
        expect(callCount, 1);
        expect(find.text('NULL-NULL'), findsOneWidget);
      });
    });

    group('given no AsyncZone ancestor', () {
      group('when of() is called', () {
        testWidgets('should throw FlutterError', (tester) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      AsyncZone.of(context);
                    },
                    child: const Text('Call AsyncZone.of'),
                  );
                },
              ),
            ),
          );

          // When - of() is called
          await tester.tap(find.text('Call AsyncZone.of'));

          // Then - should throw FlutterError
          expect(tester.takeException(), isA<FlutterError>());
        });
      });
    });

    group('given a non-ZoneWidget caller inside an AsyncZone', () {
      group('when of() is called', () {
        testWidgets(
          'should throw FlutterError mentioning ZoneWidget',
          (tester) async {
            // Given - a regular StatelessWidget calls AsyncZone.of() during
            // build while wrapped in an AsyncZone (provider exists, but the
            // calling Element does not mix in ZoneElement)
            await tester.pumpWidget(
              MaterialApp(
                home: AsyncZone(
                  fallback: const Text('Loading...'),
                  child: Builder(
                    builder: (context) {
                      AsyncZone.of(context);
                      return const Text('Should not render');
                    },
                  ),
                ),
              ),
            );

            // Then - should surface the dedicated ZoneWidget hint, not the
            // opaque Future-throw error
            final error = tester.takeException();
            expect(error, isA<FlutterError>());
            expect(
              (error as FlutterError).message,
              contains('not a ZoneWidget'),
            );
          },
        );
      });
    });

    group('given freeze: true', () {
      testWidgets(
        'on first render keeps fallback hidden and shows nothing visible',
        (tester) async {
          // Given - freeze on the very first render: there is no previous
          // subtree to keep, so the suspending ZoneElement renders Empty and
          // AsyncZoneProvider holds onto it instead of swapping to fallback.
          final future = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'First',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: FreezingTestWidget(future: future, freeze: true),
              ),
            ),
          );

          // Then - neither fallback nor child content is shown during freeze
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('First'), findsNothing);

          // When - the future completes
          await tester.pump(const Duration(milliseconds: 100));

          // Then - the child renders the resolved value
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('First'), findsOneWidget);
        },
      );

      testWidgets(
        'retains the previously rendered subtree while pending',
        (tester) async {
          // Given - first render completes and "First" is visible
          final firstFuture = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'First',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: FreezingTestWidget(future: firstFuture),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.text('First'), findsOneWidget);

          // When - the widget is rebuilt with a new future and freeze: true
          final secondFuture = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Second',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: FreezingTestWidget(future: secondFuture, freeze: true),
              ),
            ),
          );

          // Then - the previous subtree is retained instead of swapping to
          // fallback, and the new value is not yet visible
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('First'), findsOneWidget);
          expect(find.text('Second'), findsNothing);

          // When - the second future completes
          await tester.pump(const Duration(milliseconds: 100));

          // Then - the new content replaces the previous subtree
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('First'), findsNothing);
          expect(find.text('Second'), findsOneWidget);
        },
      );

      testWidgets(
        'leaves siblings under the same AsyncZone free to rebuild',
        (tester) async {
          // Given - the frozen widget shares an AsyncZone with a plain
          // sibling Text. The first render resolves the future so "First"
          // is visible alongside "sibling-1".
          final firstFuture = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'First',
          );
          final secondFuture = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Second',
          );

          Widget tree({
            required Future<String> future,
            required bool freeze,
            required String label,
          }) {
            return MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: Column(
                  children: [
                    FreezingTestWidget(future: future, freeze: freeze),
                    Text(label),
                  ],
                ),
              ),
            );
          }

          await tester.pumpWidget(
            tree(future: firstFuture, freeze: false, label: 'sibling-1'),
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.text('First'), findsOneWidget);
          expect(find.text('sibling-1'), findsOneWidget);

          // When - rebuilt with a frozen new future and an updated
          // sibling label
          await tester.pumpWidget(
            tree(future: secondFuture, freeze: true, label: 'sibling-2'),
          );

          // Then - the frozen widget retains its old subtree, but the
          // sibling text updates because freeze is local to the calling
          // ZoneWidget and does not gate top-down propagation through the
          // AsyncZone.
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('First'), findsOneWidget);
          expect(find.text('sibling-1'), findsNothing);
          expect(find.text('sibling-2'), findsOneWidget);

          // Drain the pending future to avoid leaking timers.
          await tester.pump(const Duration(milliseconds: 100));
        },
      );
    });

    group('given a pending Future superseded by a rebuild', () {
      testWidgets(
        'late completion of the old future does not swap the resolved UI',
        (tester) async {
          // Given - slow future that we will later replace
          final slowFuture = Future.delayed(
            const Duration(milliseconds: 300),
            () => 'Slow',
          );
          final fastFuture = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Fast',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: TestWidget(future: slowFuture),
              ),
            ),
          );
          expect(find.text('Loading...'), findsOneWidget);

          // When - rebuilt with a fresh future before the original completes,
          // the rebuild supersedes the in-flight slowFuture
          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: TestWidget(future: fastFuture),
              ),
            ),
          );

          // Then - fastFuture resolves and is rendered
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('Fast'), findsOneWidget);
          expect(find.text('Loading...'), findsNothing);

          // When - slowFuture completes after the supersede
          await tester.pump(const Duration(milliseconds: 200));

          // Then - it must not roll back to the fallback or otherwise replace
          // the resolved UI; the supersede dropped it from tracked tasks
          expect(find.text('Fast'), findsOneWidget);
          expect(find.text('Loading...'), findsNothing);
        },
      );

      testWidgets(
        'removing the ZoneWidget supersedes its pending future cleanly',
        (tester) async {
          // Given - a ZoneWidget waiting on a future that has not yet completed
          final future = Future.delayed(
            const Duration(milliseconds: 200),
            () => 'Result',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: TestWidget(future: future),
              ),
            ),
          );
          expect(find.text('Loading...'), findsOneWidget);

          // When - the ZoneWidget is replaced with a non-suspending child;
          // ZoneElement.deactivate must drop the pending future from the
          // provider's tracked tasks so the fallback is no longer needed
          await tester.pumpWidget(
            const MaterialApp(
              home: AsyncZone(
                fallback: Text('Loading...'),
                child: Text('Plain'),
              ),
            ),
          );

          // Then - the new content is shown immediately
          expect(find.text('Plain'), findsOneWidget);
          expect(find.text('Loading...'), findsNothing);

          // When - the original future completes after the widget is gone
          await tester.pump(const Duration(milliseconds: 200));

          // Then - the completion is harmless; no exception, no UI churn
          expect(tester.takeException(), isNull);
          expect(find.text('Plain'), findsOneWidget);
        },
      );
    });
  });
}
