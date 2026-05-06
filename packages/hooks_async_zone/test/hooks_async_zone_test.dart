import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_async_zone/hooks_async_zone.dart';

import 'helper/test_widgets.dart';

void main() {
  group('useAsyncZone', () {
    group('given a Future', () {
      group('when Future is pending', () {
        testWidgets('should throw Future and show fallback', (tester) async {
          // Given
          final future = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () => 'Data loaded',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: SimpleHookZoneWidget(
                  builder: (data) => Text(data),
                  future: future,
                ),
              ),
            ),
          );

          // When - initial render
          await tester.pump();

          // Then - should show fallback
          expect(find.text('Loading...'), findsOneWidget);
          expect(find.text('Data loaded'), findsNothing);

          // Clean up - wait for timer to complete
          await tester.pumpAndSettle();
        });
      });

      group('when Future completes', () {
        testWidgets('should display data', (tester) async {
          // Given
          final future = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () => 'Data loaded',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: SimpleHookZoneWidget(
                  builder: (data) => Text(data),
                  future: future,
                ),
              ),
            ),
          );

          await tester.pump();
          expect(find.text('Loading...'), findsOneWidget);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();

          // Then - should display data
          expect(find.text('Data loaded'), findsOneWidget);
          expect(find.text('Loading...'), findsNothing);
        });
      });
    });

    group('given multiple Futures', () {
      testWidgets('should handle multiple async operations', (tester) async {
        // Given
        final future1 = Future<String>.delayed(
          const Duration(milliseconds: 50),
          () => 'Data 1',
        );
        final future2 = Future<String>.delayed(
          const Duration(milliseconds: 100),
          () => 'Data 2',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Loading...'),
              child: MultipleHookZoneWidget(future1: future1, future2: future2),
            ),
          ),
        );

        // When - initially pending
        await tester.pump();

        // Then - should show fallback
        expect(find.text('Loading...'), findsOneWidget);

        // When - both complete
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Then - should display both data
        expect(find.text('Data 1 - Data 2'), findsOneWidget);
      });
    });
  });

  group('HookZoneWidget', () {
    group('given a widget that uses hooks and async', () {
      testWidgets('should work with useState and useAsyncZone', (tester) async {
        // Given
        var counter = 0;
        final future = Future<String>.delayed(
          const Duration(milliseconds: 50),
          () => 'Data ${++counter}',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Loading...'),
              child: TestHookZoneWidget(future: future),
            ),
          ),
        );

        // When - initial render
        await tester.pump();
        expect(find.text('Loading...'), findsOneWidget);

        // When - Future completes
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();

        // Then - should display data and counter
        expect(find.text('Counter: 0'), findsOneWidget);
        expect(find.text('Data 1'), findsOneWidget);

        // When - increment counter
        await tester.tap(find.text('Increment'));
        await tester.pump();

        // Then - counter should update
        expect(find.text('Counter: 1'), findsOneWidget);
      });
    });
  });

  group('StatefulHookZoneWidget', () {
    group('given a stateful widget with hooks', () {
      testWidgets('should work with state and hooks', (tester) async {
        // Given
        final future = Future<String>.delayed(
          const Duration(milliseconds: 50),
          () => 'Async data',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Loading...'),
              child: TestStatefulHookZoneWidget(future: future),
            ),
          ),
        );

        // When - initial render
        await tester.pump();
        expect(find.text('Loading...'), findsOneWidget);

        // When - Future completes
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();

        // Then - should display both state and async data
        expect(find.text('State: Initial'), findsOneWidget);
        expect(find.text('Async data'), findsOneWidget);

        // When - update state
        await tester.tap(find.text('Update'));
        await tester.pump();

        // Then - state should update
        expect(find.text('State: Updated'), findsOneWidget);
      });
    });
  });

  group('HookErrorZoneWidget', () {
    group('given a widget that throws error', () {
      testWidgets('should catch and display error', (tester) async {
        // Given
        await tester.pumpWidget(
          MaterialApp(
            home: TestHookErrorZoneWidgetWithError(shouldThrow: true),
          ),
        );

        // When - error occurs
        await tester.pump();

        // Then - should display error
        expect(find.text('Error: Exception: Test error'), findsOneWidget);
      });

      testWidgets('should reset error boundary', (tester) async {
        // Given
        var shouldThrow = true;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return TestHookErrorZoneWidgetWithError(
                  shouldThrow: shouldThrow,
                  onReset: () {
                    setState(() {
                      shouldThrow = false;
                    });
                  },
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Error: Exception: Test error'), findsOneWidget);

        // When - reset error and change state
        await tester.tap(find.text('Reset'));
        await tester.pump();

        // Then - should show normal state
        expect(find.text('Normal'), findsOneWidget);
      });
    });

    group('given a widget with hooks and error handling', () {
      testWidgets('should work with useState', (tester) async {
        // Given
        await tester.pumpWidget(
          MaterialApp(home: TestHookErrorZoneWidgetWithCounter()),
        );

        // When - initial render
        await tester.pump();

        // Then - should display counter
        expect(find.text('Counter: 0'), findsOneWidget);

        // When - increment counter
        await tester.tap(find.text('Increment'));
        await tester.pump();

        // Then - counter should update
        expect(find.text('Counter: 1'), findsOneWidget);
      });
    });
  });

  group('StatefulHookErrorZoneWidget', () {
    group('given a stateful widget with error handling', () {
      testWidgets('should catch errors and maintain state', (tester) async {
        // Given
        await tester.pumpWidget(
          MaterialApp(
            home: TestStatefulHookErrorZoneWidgetWithError(shouldThrow: true),
          ),
        );

        // When - error occurs
        await tester.pump();

        // Then - should display error and state
        expect(
          find.text('Stateful Error: Exception: Stateful error'),
          findsOneWidget,
        );
      });

      testWidgets('should work with hooks and state', (tester) async {
        // Given
        await tester.pumpWidget(
          MaterialApp(home: TestStatefulHookErrorZoneWidgetWithCounter()),
        );

        // When - initial render
        await tester.pump();

        // Then - should display hook state
        expect(find.text('Hook Counter: 0'), findsOneWidget);
      });
    });
  });

  group('HookZoneBuilder', () {
    testWidgets('should work with builder pattern', (tester) async {
      // Given
      final future = Future.delayed(
        const Duration(milliseconds: 50),
        () => 'Success',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncZone(
            fallback: const Text('Loading...'),
            child: HookZoneBuilder(
              builder: (context) {
                final counter = useState(0);
                final data = useAsyncZone(future);
                return Column(
                  children: [
                    Text('Counter: ${counter.value}'),
                    Text('Data: $data'),
                    ElevatedButton(
                      onPressed: () => counter.value++,
                      child: const Text('Increment'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Then - initially shows fallback
      expect(find.text('Loading...'), findsOneWidget);

      // When - Future completes
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // Then - shows content with hooks working
      expect(find.text('Counter: 0'), findsOneWidget);
      expect(find.text('Data: Success'), findsOneWidget);

      // When - increment counter
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Then - counter updates
      expect(find.text('Counter: 1'), findsOneWidget);
    });
  });
}
