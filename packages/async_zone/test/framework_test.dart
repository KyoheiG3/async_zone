import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_widgets.dart';

void main() {
  group('ZoneWidget', () {
    group('when Future is thrown', () {
      testWidgets(
        'Given a StatelessWidget that throws Future, When built, Then should catch and show fallback',
        (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'Success',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Fallback'),
                child: ThrowingZoneWidget(future: future),
              ),
            ),
          );

          // When - ZoneWidget throws Future
          expect(find.text('Fallback'), findsOneWidget);

          // Then - shows child after completion
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.text('Success'), findsOneWidget);
        },
      );

      testWidgets(
        'Given a StatefulWidget that throws Future, When setState is called, Then should handle correctly',
        (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'Result',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: StatefulThrowingWidget(future: future),
              ),
            ),
          );

          // When - shows fallback initially
          expect(find.text('Loading...'), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows result (this also tests mounted == true case)
          expect(find.text('Result'), findsOneWidget);
        },
      );
    });

    group('when Future throws without ErrorZone', () {
      testWidgets(
        'Given a ZoneWidget without ErrorZone, When Future throws, Then should rethrow on next build',
        (tester) async {
          // Given - Future that throws error
          final future = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () => throw 'Future error',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Loading...'),
                child: ThrowingZoneWidget(future: future),
              ),
            ),
          );

          // When - shows fallback initially
          expect(find.text('Loading...'), findsOneWidget);

          // Wait for Future to complete
          await tester.pump(const Duration(milliseconds: 50));

          // Then - error is stored and will be rethrown on next build
          // The error is caught by Flutter's error handling
          expect(tester.takeException(), 'Future error');
        },
      );
    });

    group('when using StatefulZoneWidget', () {
      testWidgets(
        'Given a StatefulZoneWidget, When Future completes, Then should work correctly',
        (tester) async {
          // Given
          final future = Future.delayed(
            const Duration(milliseconds: 50),
            () => 'Stateful Result',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AsyncZone(
                fallback: const Text('Stateful Loading...'),
                child: StatefulThrowingWidget(future: future),
              ),
            ),
          );

          // When - shows fallback
          expect(find.text('Stateful Loading...'), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows result
          expect(find.text('Stateful Result'), findsOneWidget);
        },
      );
    });

    group('when error is stored and widget rebuilds', () {
      testWidgets(
        'Given a ZoneWidget without AsyncZone, When Future throws, Then should store error and rethrow on rebuild',
        (tester) async {
          // Given - ZoneWidget without AsyncZone wrapper
          final errorFuture = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () => throw 'Stored error',
          );

          await tester.pumpWidget(
            MaterialApp(home: DirectThrowingZoneWidget(future: errorFuture)),
          );

          // Wait for error to be stored in _error (lines 43-44, 30-34)
          await tester.pump(const Duration(milliseconds: 50));

          // When - Widget rebuilds after error is stored
          await tester.pump();

          // Then - The stored error should be rethrown (line 21)
          expect(tester.takeException(), 'Stored error');
        },
      );
    });
  });
}
