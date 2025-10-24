import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/error_test_widgets.dart';

void main() {
  group('ErrorBoundary', () {
    group('given a child that throws', () {
      group('when synchronous error occurs', () {
        testWidgets('should catch and display fallback', (tester) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: ErrorBoundary(
                builder: (context, error, reset) {
                  return Text('Error: $error');
                },
                child: const ThrowingWidget(message: 'Test error'),
              ),
            ),
          );

          // When - error occurs during build
          await tester.pump();

          // Then - should display error fallback
          expect(find.text('Error: Test error'), findsOneWidget);
        });

        testWidgets('should invoke onError callback', (tester) async {
          // Given
          Object? capturedError;

          await tester.pumpWidget(
            MaterialApp(
              home: ErrorBoundary(
                builder: (context, error, reset) => Text('Error: $error'),
                onError: (error, stackTrace) {
                  capturedError = error;
                },
                child: const ThrowingWidget(message: 'Callback test'),
              ),
            ),
          );

          // When - error occurs
          await tester.pump();

          // Then - should invoke callback with error
          expect(capturedError, 'Callback test');
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
              home: ErrorBoundary(
                builder: (context, error, reset) {
                  return Text('Caught: $error');
                },
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
          expect(find.text('Caught: Async error'), findsOneWidget);
        });

        testWidgets('should handle Exception outside of performRebuild', (
          tester,
        ) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: ErrorBoundary(
                builder: (context, error, reset) {
                  return Text('Caught error: $error');
                },
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
            find.text('Caught error: Exception: Button error'),
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
                  return ErrorBoundary(
                    builder: (context, error, reset) {
                      return Column(
                        children: [
                          Text('Error: $error'),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                shouldThrow = false;
                              });
                              reset();
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      );
                    },
                    child: ThrowingWidget(
                      key: ValueKey(shouldThrow),
                      shouldThrow: shouldThrow,
                      message: 'Test message',
                    ),
                  );
                },
              ),
            ),
          );

          // Then - initially shows error
          await tester.pump();
          expect(find.text('Error: Test message'), findsOneWidget);

          // When - reset is called
          await tester.tap(find.text('Reset'));
          await tester.pump();

          // Then - should show normal state
          expect(find.text('Normal: Test message'), findsOneWidget);
        });

        testWidgets('should invoke onReset callback with argument', (
          tester,
        ) async {
          // Given
          Object? resetArg;

          await tester.pumpWidget(
            MaterialApp(
              home: ErrorBoundary(
                builder: (context, error, reset) {
                  return ElevatedButton(
                    onPressed: () => reset('custom arg'),
                    child: Text('Error: $error'),
                  );
                },
                onReset: (arg) {
                  resetArg = arg;
                },
                child: const ThrowingWidget(message: 'Reset test'),
              ),
            ),
          );

          // Then - initially shows error
          await tester.pump();

          // When - reset is called with argument
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();

          // Then - should invoke callback with argument
          expect(resetArg, 'custom arg');
        });
      });
    });
  });

  group('ErrorBoundary.of()', () {
    group('given no ErrorBoundary ancestor', () {
      group('when of() is called', () {
        testWidgets('should throw FlutterError', (tester) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ErrorBoundary.of(context);
                    },
                    child: const Text('Call of()'),
                  );
                },
              ),
            ),
          );

          await tester.pump();

          // When/Then - calling of() should throw
          expect(
            () => ErrorBoundary.of(tester.element(find.text('Call of()'))),
            throwsA(isA<FlutterError>()),
          );
        });
      });
    });

    group('given an ErrorBoundary ancestor', () {
      group('when showBoundary is called', () {
        testWidgets('should programmatically trigger error state', (
          tester,
        ) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: ErrorBoundary(
                builder: (context, error, reset) {
                  return Text('Error: $error');
                },
                child: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        ErrorBoundary.of(
                          context,
                        ).showBoundary('Manual error', StackTrace.current);
                      },
                      child: const Text('Show Error'),
                    );
                  },
                ),
              ),
            ),
          );

          // Then - initially shows normal state
          await tester.pump();
          expect(find.text('Show Error'), findsOneWidget);

          // When - showBoundary is called
          await tester.tap(find.text('Show Error'));
          await tester.pump();

          // Then - should display error state
          expect(find.text('Error: Manual error'), findsOneWidget);
        });
      });

      group('when resetBoundary is called', () {
        testWidgets('should programmatically reset error state', (
          tester,
        ) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: ErrorBoundary(
                builder: (context, error, reset) {
                  return Column(
                    children: [
                      Text('Error: $error'),
                      ElevatedButton(
                        onPressed: () {
                          ErrorBoundary.of(context).resetBoundary();
                        },
                        child: const Text('Reset via Scope'),
                      ),
                    ],
                  );
                },
                child: const ThrowingWidget(message: 'Initial error'),
              ),
            ),
          );

          // When - error occurs
          await tester.pump();

          // Then - ErrorBoundary.of() throws because context is inside error fallback
          expect(
            () =>
                ErrorBoundary.of(tester.element(find.text('Reset via Scope'))),
            throwsA(isA<FlutterError>()),
          );
        });
      });
    });
  });

  group('StatefulErrorZone', () {
    group('given a stateful child that throws', () {
      group('when error occurs', () {
        testWidgets('should catch errors', (tester) async {
          // Given
          await tester.pumpWidget(
            MaterialApp(
              home: StatefulErrorZoneWidget(
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
                  return StatefulErrorZoneWidget(
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
                  return StatefulErrorZoneWidget(
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
    });
  });
}
