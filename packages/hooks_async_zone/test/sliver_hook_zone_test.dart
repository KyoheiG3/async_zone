import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_async_zone/hooks_async_zone.dart';

import 'helper/test_widgets.dart';

void main() {
  group('SliverHookZoneWidget', () {
    group('given a SliverHookZoneWidget inside a CustomScrollView', () {
      testWidgets('should suspend and then show data', (tester) async {
        // Given
        final future = Future<String>.delayed(
          const Duration(milliseconds: 50),
          () => 'Sliver hook data',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Fallback'),
              child: CustomScrollView(
                slivers: [
                  SimpleSliverHookZoneWidget(future: future),
                ],
              ),
            ),
          ),
        );

        // Then - fallback shown while suspended
        expect(find.text('Fallback'), findsOneWidget);
        expect(find.text('Sliver hook data'), findsNothing);

        // When - future completes
        await tester.pump(const Duration(milliseconds: 50));

        // Then - sliver content visible
        expect(find.text('Sliver hook data'), findsOneWidget);
      });
    });

    group('given hooks state in a suspended SliverHookZoneWidget', () {
      testWidgets('should preserve hook state across the suspend cycle', (
        tester,
      ) async {
        // Given
        final future = Future<String>.delayed(
          const Duration(milliseconds: 50),
          () => 'Loaded',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Loading...'),
              child: CustomScrollView(
                slivers: [
                  TestSliverHookZoneWidget(future: future),
                ],
              ),
            ),
          ),
        );

        // Then - fallback visible, hook state not yet observable
        expect(find.text('Loading...'), findsOneWidget);

        // When - future resolves
        await tester.pump(const Duration(milliseconds: 50));

        // Then - both hook state and data are visible
        expect(find.text('Counter: 0'), findsOneWidget);
        expect(find.text('Loaded'), findsOneWidget);

        // When - increment
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        // Then - hook state advanced
        expect(find.text('Counter: 1'), findsOneWidget);
      });
    });

    group('given a SliverStatefulHookZoneWidget', () {
      testWidgets('should suspend, then expose State + hooks', (tester) async {
        // Given
        final future = Future<String>.delayed(
          const Duration(milliseconds: 50),
          () => 'Stateful loaded',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Stateful loading'),
              child: CustomScrollView(
                slivers: [
                  TestStatefulSliverHookZoneWidget(future: future),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Stateful loading'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('State: Initial'), findsOneWidget);
        expect(find.text('Stateful loaded'), findsOneWidget);

        // When - tap update
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(find.text('State: Updated'), findsOneWidget);
      });
    });

    group('given a SliverHookZoneBuilder', () {
      testWidgets('should support inline hooks + suspend', (tester) async {
        // Given
        final future = Future<String>.delayed(
          const Duration(milliseconds: 50),
          () => 'Inline data',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AsyncZone(
              fallback: const Text('Inline fallback'),
              child: CustomScrollView(
                slivers: [
                  SliverHookZoneBuilder(
                    builder: (context) {
                      final counter = useState(0);
                      final data = useAsyncZone().use(future);
                      return SliverList.list(
                        children: [
                          Text('inline ${counter.value}'),
                          Text(data),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Inline fallback'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('inline 0'), findsOneWidget);
        expect(find.text('Inline data'), findsOneWidget);
      });
    });
  });
}
