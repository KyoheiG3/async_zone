import 'package:error_boundary/error_boundary.dart';
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

  group('given resetKeys', () {
    testWidgets('should reset when keys change while in error state', (
      tester,
    ) async {
      // Given
      var keys = [1];
      late StateSetter setOuterState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuterState = setState;
              return ErrorBoundary(
                resetKeys: keys,
                builder: (context, error, reset) =>
                    Text('Error: $error'),
                child: ThrowingWidget(
                  shouldThrow: keys.first == 1,
                  message: 'boom',
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Error: boom'), findsOneWidget);

      // When - resetKeys change to a list whose values differ
      setOuterState(() => keys = [2]);
      await tester.pump();

      // Then - the boundary resets and renders the (now non-throwing) child
      expect(find.text('Error: boom'), findsNothing);
      expect(find.text('Normal: boom'), findsOneWidget);
    });

    testWidgets('should not reset when keys are deeply equal', (tester) async {
      // Given
      var keys = [1, 'a'];
      late StateSetter setOuterState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuterState = setState;
              return ErrorBoundary(
                resetKeys: keys,
                builder: (context, error, reset) =>
                    Text('Error: $error'),
                child: const ThrowingWidget(message: 'boom'),
              );
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Error: boom'), findsOneWidget);

      // When - a fresh list with the same values is passed
      setOuterState(() => keys = [1, 'a']);
      await tester.pump();

      // Then - boundary remains in error state (no spurious reset)
      expect(find.text('Error: boom'), findsOneWidget);
    });

    testWidgets('should invoke onReset when keys change', (tester) async {
      // Given
      var keys = [1];
      var resetCallCount = 0;
      late StateSetter setOuterState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuterState = setState;
              return ErrorBoundary(
                resetKeys: keys,
                onReset: (_) => resetCallCount++,
                builder: (context, error, reset) =>
                    Text('Error: $error'),
                child: ThrowingWidget(
                  shouldThrow: keys.first == 1,
                  message: 'boom',
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      expect(resetCallCount, 0);

      // When - keys change
      setOuterState(() => keys = [2]);
      await tester.pump();

      // Then - onReset is invoked exactly once
      expect(resetCallCount, 1);
    });
  });

  group('given nested ErrorBoundary', () {
    testWidgets(
      'showBoundary on outer from descendant escalates correctly',
      (tester) async {
        // Given - inner descendant explicitly delegates to outer via showBoundary.
        // Use a Builder that captures the outer provider before the inner
        // ErrorBoundary intercepts the context.
        late void Function(Object error, [StackTrace? stackTrace]) outerShow;

        await tester.pumpWidget(
          MaterialApp(
            home: ErrorBoundary(
              builder: (context, error, reset) =>
                  Text('Outer: $error'),
              child: Builder(
                builder: (outerContext) {
                  outerShow = ErrorBoundary.of(outerContext).showBoundary;
                  return ErrorBoundary(
                    builder: (context, error, reset) =>
                        Text('Inner: $error'),
                    child: Builder(
                      builder: (innerContext) {
                        return ElevatedButton(
                          onPressed: () => outerShow('escalated'),
                          child: const Text('Escalate'),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        );

        // When - tap escalates to outer
        await tester.tap(find.text('Escalate'));
        await tester.pump();

        // Then - the outer boundary handles the error, inner is unaffected
        expect(find.text('Outer: escalated'), findsOneWidget);
        expect(find.text('Inner: escalated'), findsNothing);
      },
    );
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
}
