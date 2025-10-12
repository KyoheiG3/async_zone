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
  });
}
