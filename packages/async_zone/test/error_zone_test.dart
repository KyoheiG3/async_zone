import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/error_test_widgets.dart';

void main() {
  group('StatelessErrorZoneWidget', () {
    group('given a child that throws', () {
      group('when synchronous error occurs', () {
        testWidgets('should catch and display fallback', (tester) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: TestStatelessErrorZoneWidget(
                child: const ThrowingWidget(message: 'Test error'),
              ),
            ),
          );

          // When - error occurs during build
          await tester.pump();

          // Then - should display error fallback
          expect(find.text('Stateless Error: Test error'), findsOneWidget);
        });
      });

      group('when async error occurs', () {
        testWidgets('should catch errors from Future', (tester) async {
          // Given
          final future = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () => throw 'Async error',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: TestStatelessErrorZoneWidget(
                child: AsyncZone(
                  fallback: const Text('Loading...'),
                  child: AsyncThrowingWidget(future: future),
                ),
              ),
            ),
          );

          // Then - initially shows loading
          expect(find.text('Loading...'), findsOneWidget);

          // When - Future completes with error
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();

          // Then - should catch and display error
          expect(find.text('Stateless Error: Async error'), findsOneWidget);
        });

        testWidgets('should handle Exception outside of performRebuild', (
          tester,
        ) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: TestStatelessErrorZoneWidget(
                child: const ButtonThrowingFutureErrorWidget(
                  errorMessage: 'Button error',
                ),
              ),
            ),
          );

          // Then - initial build completes successfully
          await tester.pump();
          expect(find.text('Throw Exception'), findsOneWidget);

          // When - button is tapped to throw Exception outside performRebuild
          await tester.tap(find.text('Throw Exception'));

          // Wait for error to be processed asynchronously
          await tester.pump();
          await tester.pump();

          // Then - should catch the error
          expect(
            find.text('Stateless Error: Exception: Button error'),
            findsOneWidget,
          );
        });
      });
    });

    group('given an error state', () {
      group('when resetErrorBoundary is called', () {
        testWidgets('should reset to normal state', (tester) async {
          // Given
          var shouldThrow = true;

          await tester.pumpWidget(
            MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  return TestStatelessErrorZoneWidget(
                    child: ThrowingWidget(
                      key: ValueKey(shouldThrow),
                      shouldThrow: shouldThrow,
                      message: 'Stateless reset test',
                    ),
                  );
                },
              ),
            ),
          );

          // Then - initially shows error
          await tester.pump();
          expect(
            find.text('Stateless Error: Stateless reset test'),
            findsOneWidget,
          );

          // When - child state changes and reset is called
          await tester.pumpWidget(
            MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  shouldThrow = false;
                  return TestStatelessErrorZoneWidget(
                    child: ThrowingWidget(
                      key: ValueKey(shouldThrow),
                      shouldThrow: shouldThrow,
                      message: 'Stateless reset test',
                    ),
                  );
                },
              ),
            ),
          );

          // When - reset is called
          await tester.tap(find.text('Reset'));
          await tester.pump();

          // Then - should show normal state
          expect(find.text('Normal: Stateless reset test'), findsOneWidget);
        });
      });

      group('when throw button is tapped', () {
        testWidgets('should show error state', (tester) async {
          // Given - error state
          await tester.pumpWidget(
            MaterialApp(
              home: TestStatelessErrorZoneWidget(
                child: const ThrowingWidget(
                  shouldThrow: true,
                  message: 'Initial error',
                ),
              ),
            ),
          );

          await tester.pump();
          expect(find.text('Stateless Error: Initial error'), findsOneWidget);

          // When - throw button is tapped
          await tester.tap(find.text('Throw'));
          await tester.pump();

          // Then - should show new error state
          expect(
            find.text('Stateless Error: Stateless reset test'),
            findsOneWidget,
          );
        });
      });
    });
  });

  group('StatefulErrorZoneWidget', () {
    group('given a stateful child that throws', () {
      group('when error occurs', () {
        testWidgets('should catch errors', (tester) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: TestStatefulErrorZoneWidget(
                child: const ThrowingWidget(message: 'Stateful test error'),
              ),
            ),
          );

          // When - error occurs
          await tester.pump();

          // Then - should display error state
          expect(
            find.text('Stateful Error: Stateful test error'),
            findsOneWidget,
          );
        });
      });
    });

    group('given a stateful error state', () {
      group('when reset is called', () {
        testWidgets('should reset to normal state', (tester) async {
          // Given
          var shouldThrow = true;

          await tester.pumpWidget(
            MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  return TestStatefulErrorZoneWidget(
                    child: ThrowingWidget(
                      key: ValueKey(shouldThrow),
                      shouldThrow: shouldThrow,
                      message: 'Stateful reset test',
                    ),
                  );
                },
              ),
            ),
          );

          // Then - initially shows error
          await tester.pump();
          expect(
            find.text('Stateful Error: Stateful reset test'),
            findsOneWidget,
          );

          // When - child state changes and reset is called
          await tester.pumpWidget(
            MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  shouldThrow = false;
                  return TestStatefulErrorZoneWidget(
                    child: ThrowingWidget(
                      key: ValueKey(shouldThrow),
                      shouldThrow: shouldThrow,
                      message: 'Stateful reset test',
                    ),
                  );
                },
              ),
            ),
          );

          await tester.tap(find.text('Reset'));
          await tester.pump();

          // Then - should show normal state
          expect(find.text('Normal: Stateful reset test'), findsOneWidget);
        });
      });

      group('when throw button is tapped', () {
        testWidgets('should show error state', (tester) async {
          // Given - error state
          await tester.pumpWidget(
            MaterialApp(
              home: TestStatefulErrorZoneWidget(
                child: const ThrowingWidget(
                  shouldThrow: true,
                  message: 'Initial error',
                ),
              ),
            ),
          );

          await tester.pump();
          expect(find.text('Stateful Error: Initial error'), findsOneWidget);

          // When - throw button is tapped
          await tester.tap(find.text('Throw'));
          await tester.pump();

          // Then - should show new error state
          expect(
            find.text('Stateful Error: Stateful reset test'),
            findsOneWidget,
          );
        });
      });
    });
  });

  group('nested ErrorZoneWidget', () {
    testWidgets('fallback that throws synchronously escalates to outer', (
      tester,
    ) async {
      // Given - inner fallback rethrows the captured error
      await tester.pumpWidget(
        MaterialApp(
          home: TestStatelessErrorZoneWidget(
            child: CustomFallbackErrorZoneWidget(
              fallback: (error) => throw error,
              child: const ThrowingWidget(message: 'kaboom'),
            ),
          ),
        ),
      );

      await tester.pump();

      // Then - outer catches the rethrown error, no unhandled exception
      expect(find.text('Stateless Error: kaboom'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'fallback containing a throwing descendant ZoneWidget escalates to outer',
      (tester) async {
        // Given - inner fallback returns a ZoneWidget that throws on build
        await tester.pumpWidget(
          MaterialApp(
            home: TestStatelessErrorZoneWidget(
              child: CustomFallbackErrorZoneWidget(
                fallback: (_) =>
                    const ThrowingWidget(message: 'fallback-error'),
                child: const ThrowingWidget(message: 'initial-error'),
              ),
            ),
          ),
        );

        await tester.pump();

        // Then - the descendant throw escalates past inner to outer
        expect(find.text('Stateless Error: fallback-error'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'fallback rethrow without an outer surfaces as unhandled error',
      (tester) async {
        // Given - single ErrorZoneWidget whose fallback rethrows
        await tester.pumpWidget(
          MaterialApp(
            home: CustomFallbackErrorZoneWidget(
              fallback: (error) => throw error,
              child: const ThrowingWidget(message: 'kaboom'),
            ),
          ),
        );

        await tester.pump();

        // Then - no outer to escalate to, so the rethrow surfaces
        expect(tester.takeException(), 'kaboom');
      },
    );
  });
}
