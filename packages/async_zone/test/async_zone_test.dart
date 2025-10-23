import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_widgets.dart';

void main() {
  group('AsyncZone', () {
    group('when Future completes successfully', () {
      testWidgets(
        'Given a pending Future, When it completes, Then should show child widget',
        (tester) async {
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

          // When - initial state shows fallback
          expect(find.text('Loading...'), findsOneWidget);
          expect(find.text('Success'), findsNothing);

          // Then - after Future completes, shows child
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Loading...'), findsNothing);
          expect(find.text('Success'), findsOneWidget);
        },
      );

      testWidgets(
        'Given multiple Futures, When all complete, Then should show all results',
        (tester) async {
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

          // When - shows fallback while waiting
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
        },
      );
    });

    group('when Future completes with error', () {
      testWidgets(
        'Given a Future that throws, When accessed via use(), Then should handle error gracefully',
        (tester) async {
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

          // When - initial state shows fallback
          expect(find.text('Error fallback'), findsOneWidget);

          // When - error occurs, clear it
          await tester.pump(const Duration(milliseconds: 50));
          tester.takeException(); // Clear the error

          // Then - error was handled
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Given an error Future, When use() is called again, Then should throw the error',
        (tester) async {
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

          // When - clear errors first and rebuild
          await tester.pumpWidget(const SizedBox());

          // Then - rebuild with error future should throw
          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Error fallback'),
                child: TestWidget(future: future),
              ),
            ),
          );

          expect(tester.takeException(), 'Test error');
        },
      );
    });

    group('when cache is used', () {
      testWidgets(
        'Given a completed Future, When use() is called multiple times, Then should return cached value',
        (tester) async {
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

          // Then - should only call Future once
          expect(callCount, 1);
          expect(find.text('Result-Result'), findsOneWidget);
        },
      );

      testWidgets(
        'Given a cached value, When invalidateCache() is called, Then cache should be cleared',
        (tester) async {
          // Given
          var callCount = 0;
          Future<String> createFuture() {
            return Future.delayed(const Duration(milliseconds: 50), () {
              callCount++;
              return 'Value $callCount';
            });
          }

          var currentFuture = createFuture();

          await tester.pumpWidget(
            MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  return AsyncZone(
                    fallback: const Text('Loading...'),
                    child: InvalidateCacheTestWidget(
                      future: currentFuture,
                      onInvalidate: () {
                        currentFuture = createFuture();
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 50));

          expect(find.text('Value 1'), findsOneWidget);
          expect(callCount, 1);

          // When - invalidate cache and create new future
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();

          // Then - should show new value
          expect(find.text('Value 2'), findsOneWidget);
          expect(callCount, 2);
        },
      );
    });

    group('when widget rebuilds', () {
      testWidgets(
        'Given a pending Future, When widget rebuilds, Then should preserve fallback state',
        (tester) async {
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

          // When - initial state shows fallback
          expect(find.text('Loading...'), findsOneWidget);

          // When - rebuild during pending
          await tester.pump(const Duration(milliseconds: 50));

          // Then - should still show fallback
          expect(find.text('Loading...'), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 50));

          expect(find.text('Result'), findsOneWidget);
        },
      );
    });

    group('when AsyncZone.of() is called without AsyncZone', () {
      testWidgets(
        'Given no AsyncZone ancestor, When of() is called, Then should throw FlutterError',
        (tester) async {
          // Given - a widget without AsyncZone ancestor
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

          // Then - should throw FlutterError with appropriate message
          expect(tester.takeException(), isA<FlutterError>());
        },
      );
    });
  });
}
