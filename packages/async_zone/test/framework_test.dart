import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_widgets.dart';

void main() {
  group('ZoneWidget', () {
    group('given a StatelessWidget that throws Future', () {
      group('when built with AsyncZone', () {
        testWidgets('should catch and show fallback', (tester) async {
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

          // Then - initially shows fallback
          expect(find.text('Fallback'), findsOneWidget);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows child with result
          expect(find.text('Success'), findsOneWidget);
        });
      });
    });

    group('given a StatefulWidget that throws Future', () {
      group('when built with AsyncZone', () {
        testWidgets('should handle correctly', (tester) async {
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

          // Then - initially shows fallback
          expect(find.text('Stateful Loading...'), findsOneWidget);

          // When - Future completes
          await tester.pump(const Duration(milliseconds: 50));

          // Then - shows result
          expect(find.text('Stateful Result'), findsOneWidget);
        });
      });
    });

    group('given a ZoneWidget without ErrorZoneWidget', () {
      group('when Future throws error', () {
        testWidgets('should rethrow on next build', (tester) async {
          // Given
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

          // Then - initially shows fallback
          expect(find.text('Loading...'), findsOneWidget);

          // When - Future completes with error
          await tester.pump(const Duration(milliseconds: 50));

          // Then - error is rethrown and caught by Flutter's error handling
          expect(tester.takeException(), 'Future error');
        });
      });
    });

    group('given a ZoneWidget without AsyncZone', () {
      group('when Future throws error', () {
        testWidgets('should store error and rethrow on rebuild', (
          tester,
        ) async {
          // Given
          final errorFuture = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () => throw 'Stored error',
          );

          await tester.pumpWidget(
            MaterialApp(home: DirectThrowingZoneWidget(future: errorFuture)),
          );

          // When - Future completes with error
          await tester.pump(const Duration(milliseconds: 50));

          // When - widget rebuilds after error is stored
          await tester.pump();

          // Then - stored error should be rethrown
          expect(tester.takeException(), 'Stored error');
        });
      });
    });
  });
}
