import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transition_boundary/transition_boundary.dart';

import 'helpers/transition_test_widgets.dart';

void main() {
  group('TransitionBoundary', () {
    group('TransitionZone.of', () {
      group('given no TransitionBoundary in the tree', () {
        testWidgets('should throw a FlutterError describing the cause', (
          tester,
        ) async {
          // Given
          Object? caught;

          // When
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  try {
                    TransitionZone.of(context);
                  } catch (error) {
                    caught = error;
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          // Then
          expect(caught, isA<FlutterError>());
          expect(
            (caught! as FlutterError).toString(),
            contains('TransitionZone.of called without an enclosing '),
          );
        });
      });

      group('given a TransitionBoundary in the tree', () {
        testWidgets('should return the scope from any descendant', (
          tester,
        ) async {
          // Given
          TransitionZoneScope? captured;

          // When
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: TransitionBoundary(
                child: Builder(
                  builder: (context) {
                    captured = TransitionZone.of(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          );

          // Then
          expect(captured, isNotNull);
          expect(captured!.isPending, isFalse);
        });
      });
    });

    group('TransitionZone.maybeOf', () {
      group('given no TransitionBoundary in the tree', () {
        testWidgets('should return null', (tester) async {
          // Given
          TransitionZoneScope? scope;

          // When
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  scope = TransitionZone.maybeOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          // Then
          expect(scope, isNull);
        });
      });

      group('given a TransitionBoundary in the tree', () {
        testWidgets('should return the scope', (tester) async {
          // Given
          TransitionZoneScope? scope;

          // When
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: TransitionBoundary(
                child: Builder(
                  builder: (context) {
                    scope = TransitionZone.maybeOf(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          );

          // Then
          expect(scope, isNotNull);
        });
      });
    });

    group('startTransition', () {
      group('given no tracked future', () {
        testWidgets(
          'should run the action synchronously without surfacing isPending',
          (tester) async {
            // Given
            final log = <bool>[];
            late TransitionZoneScope scope;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return IsPendingProbe(log: log);
                    },
                  ),
                ),
              ),
            );
            expect(log, [false]);

            // When
            var actionRan = false;
            scope.startTransition(() => actionRan = true);

            // Then
            expect(actionRan, isTrue);
            await tester.pumpAndSettle();
            expect(scope.isPending, isFalse);
            expect(log.contains(true), isFalse);
          },
        );

        testWidgets(
          'should run a nested startTransition action synchronously inside '
          'the outer action',
          (tester) async {
            // Given
            late TransitionZoneScope scope;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            );

            // When
            var outerActionRan = false;
            var innerActionRan = false;
            var innerRanInsideOuter = false;
            scope.startTransition(() {
              scope.startTransition(() => innerActionRan = true);
              innerRanInsideOuter = innerActionRan;
              outerActionRan = true;
            });
            await tester.pumpAndSettle();

            // Then
            expect(outerActionRan, isTrue);
            expect(innerActionRan, isTrue);
            expect(innerRanInsideOuter, isTrue);
          },
        );
      });

      group('given an AsyncZone with a committed previous subtree', () {
        testWidgets(
          'should keep the previous subtree visible while the new future is '
          'pending',
          (tester) async {
            // Given
            final futureA = Future.value('A');
            final futureB = Future.delayed(
              const Duration(milliseconds: 200),
              () => 'B',
            );

            late FutureHostController controller;
            late TransitionZoneScope scope;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return AsyncZone(
                        fallback: const Text(
                          'FALLBACK',
                          textDirection: TextDirection.ltr,
                        ),
                        child: FutureHost(
                          initial: futureA,
                          controllerOut: (c) => controller = c,
                          builder: (context, future) =>
                              DataView(future: future),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            expect(find.text('A'), findsOneWidget);
            expect(find.text('FALLBACK'), findsNothing);

            // When - startTransition swaps to a pending future
            controller.swap(futureB);
            await tester.pump();
            await tester.pump();

            // Then - transition is pending, previous subtree stays
            expect(scope.isPending, isTrue);
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.text('A'), findsOneWidget);
            expect(find.text('FALLBACK'), findsNothing);
            expect(scope.isPending, isTrue);

            // When - the new future resolves
            await tester.pump(const Duration(milliseconds: 200));

            // Then - new subtree replaces the previous one
            expect(find.text('B'), findsOneWidget);
            expect(find.text('A'), findsNothing);
            expect(scope.isPending, isFalse);
          },
        );

        testWidgets(
          'should supersede the previous future so the transition ends when '
          'the latest future resolves',
          (tester) async {
            // Given
            final futureA = Future.value('A');
            final futureB = Future.delayed(
              const Duration(milliseconds: 500),
              () => 'B',
            );
            final futureC = Future.delayed(
              const Duration(milliseconds: 100),
              () => 'C',
            );

            late FutureHostController controller;
            late TransitionZoneScope scope;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return AsyncZone(
                        fallback: const Text(
                          'FALLBACK',
                          textDirection: TextDirection.ltr,
                        ),
                        child: FutureHost(
                          initial: futureA,
                          controllerOut: (c) => controller = c,
                          builder: (context, future) =>
                              DataView(future: future),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            expect(find.text('A'), findsOneWidget);

            // When - first swap starts a transition on a slow future
            controller.swap(futureB);
            await tester.pump();
            await tester.pump();
            expect(scope.isPending, isTrue);

            // When - second swap supersedes with a faster future
            controller.swap(futureC);
            await tester.pump();
            await tester.pump();
            expect(scope.isPending, isTrue);

            // Then - transition ends when the latest future resolves
            await tester.pump(const Duration(milliseconds: 150));
            expect(find.text('C'), findsOneWidget);
            expect(scope.isPending, isFalse);

            // Let futureB resolve to avoid leftover timer warning.
            await tester.pump(const Duration(milliseconds: 400));
          },
        );
      });

      group('given an async action that mutates state inside its body', () {
        testWidgets(
          'should keep the previous subtree visible across the action future '
          'so the AsyncZone fallback does not flash',
          (tester) async {
            // Given
            final futureA = Future.value('A');
            final futureB = Future.delayed(
              const Duration(milliseconds: 200),
              () => 'B',
            );

            late FutureHostController controller;
            late TransitionZoneScope scope;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return AsyncZone(
                        fallback: const Text(
                          'FALLBACK',
                          textDirection: TextDirection.ltr,
                        ),
                        child: FutureHost(
                          initial: futureA,
                          controllerOut: (c) => controller = c,
                          builder: (context, future) =>
                              DataView(future: future),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            expect(find.text('A'), findsOneWidget);

            // When - async startTransition whose body mutates state and
            // assigns a pending future. The action future itself resolves on
            // the microtask after the synchronous body, so the transition
            // bridge must not tear down before descendants get a chance to
            // rebuild and register the new suspending future.
            controller.swap(futureB, asyncAction: true);
            await tester.pump();
            await tester.pump();

            // Then - previous subtree stays visible, fallback never appears.
            expect(find.text('A'), findsOneWidget);
            expect(find.text('FALLBACK'), findsNothing);
            expect(scope.isPending, isTrue);

            // When - the new future resolves
            await tester.pump(const Duration(milliseconds: 200));

            // Then - new subtree replaces the previous one
            expect(find.text('B'), findsOneWidget);
            expect(find.text('A'), findsNothing);
            expect(scope.isPending, isFalse);
          },
        );
      });

      group('given an async action whose post-await body dirties a descendant '
          'without suspending', () {
        testWidgets(
          'should flip isPending back to false after the rebuild even when '
          'no future is registered',
          (tester) async {
            // Given
            late TransitionZoneScope scope;
            late StateSetter setOuter;
            var counter = 0;

            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return StatefulBuilder(
                        builder: (context, setState) {
                          setOuter = setState;
                          return Text(
                            'count: $counter',
                            textDirection: TextDirection.ltr,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            );
            expect(scope.isPending, isFalse);

            // When - async action awaits, then dirties a descendant via
            // setState. No ZoneWidget throws, so [_tracked] stays empty.
            // The action future resolves long after the initial post-frame
            // settle (the one scheduled by [startTransition]) has already
            // fired, so the bridge needs its own post-frame to flip
            // [_isPending] back to false once descendants rebuild.
            scope.startTransition(() async {
              await Future.delayed(const Duration(milliseconds: 100));
              setOuter(() => counter++);
            });

            // While the action is awaiting
            await tester.pump();
            await tester.pump();
            expect(scope.isPending, isTrue);

            // When - the action completes and the post-await setState fires
            await tester.pump(const Duration(milliseconds: 150));
            await tester.pump();

            // Then - the rebuild ran (counter is 1) and isPending is back
            // to false. Removing the post-frame callback in [_trackAction]
            // strands [_isPending] at true here.
            expect(find.text('count: 1'), findsOneWidget);
            expect(scope.isPending, isFalse);
          },
        );
      });

      group('given an async action that outlives its descendant suspending '
          'future', () {
        testWidgets(
          'should hold the previous subtree until the action future also '
          'resolves',
          (tester) async {
            // Given
            final futureA = Future.value('A');
            final futureB = Future.delayed(
              const Duration(milliseconds: 100),
              () => 'B',
            );

            late FutureHostController controller;
            late TransitionZoneScope scope;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return AsyncZone(
                        fallback: const Text(
                          'FALLBACK',
                          textDirection: TextDirection.ltr,
                        ),
                        child: FutureHost(
                          initial: futureA,
                          controllerOut: (c) => controller = c,
                          builder: (context, future) =>
                              DataView(future: future),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            expect(find.text('A'), findsOneWidget);

            // When - async action whose body sets the new future and then
            // keeps awaiting for 300ms. The descendant suspending future
            // resolves at 100ms, the action future at ~300ms.
            controller.swap(
              futureB,
              asyncAction: true,
              actionDelay: const Duration(milliseconds: 300),
            );
            await tester.pump();
            await tester.pump();
            expect(scope.isPending, isTrue);

            // When - 150ms in: futureB has resolved, but the action is
            // still awaiting another ~150ms.
            await tester.pump(const Duration(milliseconds: 150));

            // Then - the previous subtree must stay because the
            // transition has not fully settled yet (React parity).
            expect(find.text('A'), findsOneWidget);
            expect(find.text('B'), findsNothing);
            expect(find.text('FALLBACK'), findsNothing);
            expect(scope.isPending, isTrue);

            // When - the action future also resolves
            await tester.pump(const Duration(milliseconds: 200));

            // Then - new subtree commits
            expect(find.text('B'), findsOneWidget);
            expect(find.text('A'), findsNothing);
            expect(scope.isPending, isFalse);
          },
        );
      });

      group('given an outer ZoneWidget that depends on isPending but does not '
          'suspend', () {
        testWidgets('should commit its isPending-dependent UI updates while a '
            'descendant ZoneWidget is suspending the transition', (
          tester,
        ) async {
          // Given
          final futureA = Future.value('A');
          final futureB = Future.delayed(
            const Duration(milliseconds: 200),
            () => 'B',
          );

          late FutureHostController controller;
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: TransitionBoundary(
                child: IsPendingZoneProbe(
                  child: AsyncZone(
                    fallback: const Text(
                      'FALLBACK',
                      textDirection: TextDirection.ltr,
                    ),
                    child: FutureHost(
                      initial: futureA,
                      controllerOut: (c) => controller = c,
                      builder: (context, future) => DataView(future: future),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(find.text('IDLE'), findsOneWidget);
          expect(find.text('A'), findsOneWidget);

          // When - kick off a transition; the inner DataView suspends.
          controller.swap(futureB);
          await tester.pump();
          await tester.pump();

          // Then - the outer probe (which doesn't suspend) commits its
          // 'PENDING' update while the inner subtree still shows 'A'.
          expect(find.text('PENDING'), findsOneWidget);
          expect(find.text('IDLE'), findsNothing);
          expect(find.text('A'), findsOneWidget);
          expect(find.text('B'), findsNothing);
          expect(find.text('FALLBACK'), findsNothing);

          // When - futureB resolves
          await tester.pump(const Duration(milliseconds: 250));

          // Then - inner commits new data, outer flips back to IDLE.
          expect(find.text('IDLE'), findsOneWidget);
          expect(find.text('PENDING'), findsNothing);
          expect(find.text('B'), findsOneWidget);
          expect(find.text('A'), findsNothing);
        });
      });

      group('given no surrounding transition', () {
        testWidgets(
          'should show the AsyncZone fallback while swapping to a pending '
          'future',
          (tester) async {
            // Given
            final futureA = Future.value('A');
            final futureB = Future.delayed(
              const Duration(milliseconds: 200),
              () => 'B',
            );

            late FutureHostController controller;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: AsyncZone(
                    fallback: const Text(
                      'FALLBACK',
                      textDirection: TextDirection.ltr,
                    ),
                    child: FutureHost(
                      initial: futureA,
                      controllerOut: (c) => controller = c,
                      builder: (context, future) => DataView(future: future),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            expect(find.text('A'), findsOneWidget);

            // When - swap happens outside a transition
            controller.swap(futureB, inTransition: false);
            await tester.pump();
            await tester.pump();

            // Then - the AsyncZone fallback takes over
            expect(find.text('FALLBACK'), findsOneWidget);
            expect(find.text('A', skipOffstage: true), findsNothing);

            // When - the new future resolves
            await tester.pump(const Duration(milliseconds: 200));

            // Then - new subtree replaces the fallback
            expect(find.text('B'), findsOneWidget);
            expect(find.text('FALLBACK'), findsNothing);
          },
        );
      });

      group('given no previously committed AsyncZone subtree', () {
        testWidgets(
          'should show the AsyncZone fallback when startTransition mounts a '
          'fresh suspending subtree',
          (tester) async {
            // Given
            final future = Future.delayed(
              const Duration(milliseconds: 200),
              () => 'NEW',
            );

            late TransitionZoneScope scope;
            late void Function(VoidCallback fn) setOuterState;
            var showZone = false;

            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return StatefulBuilder(
                        builder: (context, setState) {
                          setOuterState = setState;
                          if (!showZone) {
                            return const Text(
                              'GATE',
                              textDirection: TextDirection.ltr,
                            );
                          }
                          return AsyncZone(
                            fallback: const Text(
                              'FALLBACK',
                              textDirection: TextDirection.ltr,
                            ),
                            child: DataView(future: future),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(find.text('GATE'), findsOneWidget);

            // When - startTransition mounts a brand new AsyncZone subtree
            scope.startTransition(() {
              setOuterState(() => showZone = true);
            });
            await tester.pump();
            await tester.pump();

            // Then - no previous subtree to preserve, so fallback is shown
            expect(find.text('FALLBACK'), findsOneWidget);
            expect(find.text('GATE'), findsNothing);
            expect(scope.isPending, isFalse);

            // When - the new future resolves
            await tester.pump(const Duration(milliseconds: 200));

            // Then - new subtree replaces the fallback
            expect(find.text('NEW'), findsOneWidget);
            expect(find.text('FALLBACK'), findsNothing);
          },
        );
      });
    });

    group('forceSameFrameRebuild', () {
      group('given forceSameFrameRebuild is true', () {
        testWidgets(
          'should clear isPending in the same frame an async action ends '
          'with a non-suspending descendant rebuild',
          (tester) async {
            // Given
            late TransitionZoneScope scope;
            late StateSetter setOuter;
            var counter = 0;
            final log = <String>[];

            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  forceSameFrameRebuild: true,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      setOuter = setState;
                      // Subscribe to isPending and log every observed
                      // (counter, isPending) pair so the test can verify
                      // when the new isPending value reaches dependents.
                      scope = TransitionZone.of(context);
                      log.add('counter=$counter, isPending=${scope.isPending}');
                      return Text(
                        'count: $counter',
                        textDirection: TextDirection.ltr,
                      );
                    },
                  ),
                ),
              ),
            );

            // When - async action awaits, then dirties this widget via
            // setState. The state change does not register any suspending
            // future, so [_tracked] stays empty when the action future
            // completes.
            scope.startTransition(() async {
              await Future.delayed(const Duration(milliseconds: 100));
              setOuter(() => counter++);
            });

            // While the action is awaiting, isPending flips to true.
            await tester.pump();
            expect(scope.isPending, isTrue);
            log.clear();

            // When - one pump that covers the action delay and runs exactly
            // one frame + its post-frame callbacks.
            await tester.pump(const Duration(milliseconds: 150));

            // Then - the subscriber observed the descendant's new state
            // *together with* isPending=false in the same frame. Without
            // the markNeedsBuild in [_trackAction]'s post-frame branch,
            // [_TransitionBoundaryElement.performRebuild] would not run and
            // the inline settle would not flip isPending until the post-
            // frame fires, leaving the log without the (counter=1,
            // isPending=false) entry until a second pump.
            expect(log, contains('counter=1, isPending=false'));
            expect(find.text('count: 1'), findsOneWidget);
            expect(scope.isPending, isFalse);
          },
        );

        testWidgets(
          'should surface isPending in the same frame the transition starts',
          (tester) async {
            // Given
            final futureA = Future.value('A');
            final futureB = Future.delayed(
              const Duration(milliseconds: 200),
              () => 'B',
            );

            late FutureHostController controller;
            late TransitionZoneScope scope;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: TransitionBoundary(
                  forceSameFrameRebuild: true,
                  child: Builder(
                    builder: (context) {
                      scope = TransitionZone.of(context);
                      return AsyncZone(
                        fallback: const Text(
                          'FALLBACK',
                          textDirection: TextDirection.ltr,
                        ),
                        child: FutureHost(
                          initial: futureA,
                          controllerOut: (c) => controller = c,
                          builder: (context, future) =>
                              DataView(future: future),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            expect(find.text('A'), findsOneWidget);

            // When - one pump only; Phase 1.5 forces descendants to rebuild
            // synchronously and inline Phase 2 surfaces isPending immediately
            controller.swap(futureB);
            await tester.pump();

            // Then
            expect(scope.isPending, isTrue);

            // When - the new future resolves
            await tester.pump(const Duration(milliseconds: 200));

            // Then
            expect(find.text('B'), findsOneWidget);
            expect(scope.isPending, isFalse);
          },
        );
      });
    });
  });
}
