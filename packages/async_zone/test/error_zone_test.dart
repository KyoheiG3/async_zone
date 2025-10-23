import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/error_test_widgets.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('should catch synchronous errors and display fallback', (
      tester,
    ) async {
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

      await tester.pump();

      expect(find.text('Error: Test error'), findsOneWidget);
    });

    testWidgets('should reset error state when resetErrorBoundary is called', (
      tester,
    ) async {
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

      await tester.pump();
      expect(find.text('Error: Test message'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(find.text('Normal: Test message'), findsOneWidget);
    });

    testWidgets('should invoke onError callback when error occurs', (
      tester,
    ) async {
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

      await tester.pump();

      expect(capturedError, 'Callback test');
    });

    testWidgets(
      'should invoke onReset callback when reset is called with argument',
      (tester) async {
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
              onReset: ([arg]) {
                resetArg = arg;
              },
              child: const ThrowingWidget(message: 'Reset test'),
            ),
          ),
        );

        await tester.pump();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(resetArg, 'custom arg');
      },
    );

    testWidgets('should catch async errors from Future', (tester) async {
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

      expect(find.text('Loading...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('Caught: Async error'), findsOneWidget);
    });

    testWidgets('should handle Exception thrown outside of performRebuild', (
      tester,
    ) async {
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

      // Initial build completes successfully
      await tester.pump();
      expect(find.text('Throw Exception'), findsOneWidget);

      // Tap button to throw Exception outside of performRebuild
      // This should trigger line 60: handleFuture(Future.error(...))
      await tester.tap(find.text('Throw Exception'));

      // Wait for error to be processed asynchronously
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Caught error: Exception: Button error'),
        findsOneWidget,
      );
    });
  });

  group('StatefulErrorZone', () {
    testWidgets('should catch errors with StatefulErrorZone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulErrorZoneWidget(
            child: const ThrowingWidget(message: 'Stateful test error'),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Stateful Error: Stateful test error'), findsOneWidget);
    });

    testWidgets('should reset StatefulErrorZone', (tester) async {
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

      await tester.pump();
      expect(find.text('Stateful Error: Stateful reset test'), findsOneWidget);

      // Change child state before reset
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

      expect(find.text('Normal: Stateful reset test'), findsOneWidget);
    });
  });
}
