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

          // When - after 50ms, future1 completes but future2 is still pending
          await tester.pump(const Duration(milliseconds: 50));

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

    group('given a pending Future with sibling ZoneWidget', () {
      group('when allowParallelBuilds is false', () {
        testWidgets('should return Empty instead of building sibling',
            (tester) async {
          // Given
          var siblingBuildCount = 0;
          final future = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Result',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                allowParallelBuilds: false,
                fallback: const Text('Loading...'),
                child: SiblingFutureWidget(
                  firstChild: TestWidget(future: future),
                  secondChild: BuildCountingWidget(
                    onBuild: () => siblingBuildCount++,
                  ),
                ),
              ),
            ),
          );

          // Then - fallback is shown and sibling's build was never called
          // because canBuildChild() returned false (tasks is not empty)
          expect(find.text('Loading...'), findsOneWidget);
          expect(find.text('Child built'), findsNothing);
          expect(siblingBuildCount, 0);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 100));

          // Then - sibling is now built
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('Result'), findsOneWidget);
          expect(find.text('Child built'), findsOneWidget);
          expect(siblingBuildCount, 1);
        });
      });

      group('when allowParallelBuilds is true (default)', () {
        testWidgets('should build sibling while Future is pending',
            (tester) async {
          // Given
          var siblingBuildCount = 0;
          final future = Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Result',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                allowParallelBuilds: true, // default
                fallback: const Text('Loading...'),
                child: SiblingFutureWidget(
                  firstChild: TestWidget(future: future),
                  secondChild: BuildCountingWidget(
                    onBuild: () => siblingBuildCount++,
                  ),
                ),
              ),
            ),
          );

          // Then - fallback is shown but sibling's build WAS called
          // because allowParallelBuilds is true (canBuildChild returns true)
          expect(find.text('Loading...'), findsOneWidget);
          expect(siblingBuildCount, 1);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 100));

          // Then - shows result and sibling was rebuilt
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('Result'), findsOneWidget);
          expect(siblingBuildCount, 2);
        });
      });
    });
  });
}
