import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_async_zone/hooks_async_zone.dart';

void main() {
  testWidgets(
    'HookTransitionZoneBuilder exposes both hooks and the transition scope '
    'from its build context',
    (tester) async {
      TransitionZoneScope? capturedScope;
      ValueNotifier<int>? capturedState;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HookTransitionZoneBuilder(
            builder: (context) {
              final id = useState(1);
              capturedState = id;
              capturedScope = TransitionZone.of(context);
              return Text('id: ${id.value}');
            },
          ),
        ),
      );
      expect(capturedScope, isNotNull);
      expect(capturedState!.value, 1);
      expect(find.text('id: 1'), findsOneWidget);

      // Trigger a state update via the captured scope. Without a tracked
      // future the transition ends silently; the state update still
      // propagates via the hook.
      capturedScope!.startTransition(() => capturedState!.value = 2);
      await tester.pumpAndSettle();
      expect(find.text('id: 2'), findsOneWidget);
      expect(capturedScope!.isPending, isFalse);
    },
  );

  testWidgets(
    'useTransitionZone returns the surrounding HookTransitionZoneElement '
    'scope',
    (tester) async {
      TransitionZoneScope? capturedScope;
      ValueNotifier<int>? capturedState;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HookTransitionZoneBuilder(
            builder: (context) {
              final scope = useTransitionZone();
              final id = useState(1);
              capturedScope = scope;
              capturedState = id;
              return Text('id: ${id.value}');
            },
          ),
        ),
      );
      expect(capturedScope, isNotNull);
      expect(capturedScope, same(TransitionZone.of(tester.element(find.byType(HookTransitionZoneBuilder)))));
      expect(capturedScope!.isPending, isFalse);

      capturedScope!.startTransition(() => capturedState!.value = 2);
      await tester.pumpAndSettle();
      expect(find.text('id: 2'), findsOneWidget);
      expect(capturedScope!.isPending, isFalse);
    },
  );

  testWidgets(
    'useTransitionZone throws when called outside a HookTransitionZoneElement',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HookBuilder(
            builder: (context) {
              useTransitionZone();
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    },
  );

  testWidgets(
    'isPending surfaces on the same frame when a descendant ZoneWidget '
    'suspends after a startTransition',
    (tester) async {
      final futureA = Future.value('A');
      final futureB = Future.delayed(
        const Duration(milliseconds: 200),
        () => 'B',
      );

      late TransitionZoneScope scope;
      late ValueNotifier<Future<String>> currentFuture;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HookTransitionZoneBuilder(
            builder: (context) {
              scope = TransitionZone.of(context);
              final future = useState<Future<String>>(futureA);
              currentFuture = future;

              return AsyncZone(
                fallback: const Text(
                  'FALLBACK',
                  textDirection: TextDirection.ltr,
                ),
                child: Opacity(
                  opacity: scope.isPending ? 0.5 : 1.0,
                  child: _DataView(future: future.value),
                ),
              );
            },
          ),
        ),
      );

      // Resolve the initial future.
      await tester.pump();
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
      expect(scope.isPending, isFalse);

      // Swap inside a transition. Same-frame two-phase rebuild should
      // surface isPending while the previous content stays visible.
      scope.startTransition(() => currentFuture.value = futureB);
      await tester.pump();
      expect(scope.isPending, isTrue);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('FALLBACK'), findsNothing);

      // When the new future resolves, the transition ends and the new
      // value is shown.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('B'), findsOneWidget);
      expect(scope.isPending, isFalse);
    },
  );
}

class _DataView extends ZoneWidget {
  const _DataView({required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final value = AsyncZone.of(context).use(future);
    return Text(value, textDirection: TextDirection.ltr);
  }
}
