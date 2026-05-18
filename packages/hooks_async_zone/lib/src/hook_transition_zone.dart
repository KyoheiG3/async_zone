import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A base class for stateless widgets that combine hooks with a transition
/// scope.
///
/// This widget combines [StatelessWidget] with [HookElement] and
/// [TransitionZoneElement] capabilities, allowing you to call hooks (such as
/// [useState]) directly in the build method and obtain the surrounding
/// transition scope via `TransitionZone.of(context)` — the build context is
/// the transition-bearing element itself, so the scope lookup succeeds
/// without an intermediate widget.
///
/// This is the most ergonomic form when state and transition coordination
/// live in the same widget.
///
/// Example:
/// ```dart
/// class UserPage extends HookTransitionZoneWidget {
///   const UserPage({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final scope = TransitionZone.of(context);
///     final id = useState(1);
///     final userFuture = useState<Future<User>>(() => fetchUser(1));
///
///     return Column(children: [
///       Opacity(
///         opacity: scope.isPending ? 0.5 : 1.0,
///         child: UserCard(future: userFuture.value),
///       ),
///       ElevatedButton(
///         onPressed: () => scope.startTransition(() {
///           id.value++;
///           userFuture.value = fetchUser(id.value);
///         }),
///         child: const Text('Next'),
///       ),
///     ]);
///   }
/// }
/// ```
abstract class HookTransitionZoneWidget extends StatelessWidget {
  /// Creates a [HookTransitionZoneWidget].
  const HookTransitionZoneWidget({super.key});

  @override
  HookTransitionZoneElement createElement() => HookTransitionZoneElement(this);
}

/// The element for [HookTransitionZoneWidget].
///
/// Combines [StatelessElement] with [HookElement] and
/// [TransitionZoneElement], providing the necessary infrastructure for
/// hooks and transition coordination in one element. The build context
/// itself implements [TransitionZoneScope], so `TransitionZone.of(context)`
/// returns the scope directly inside the build method.
class HookTransitionZoneElement extends StatelessElement
    with HookElement, TransitionZoneElement {
  /// Creates a [HookTransitionZoneElement] for the given [widget].
  HookTransitionZoneElement(super.widget);
}

/// A convenience widget that provides hooks and a transition scope through
/// a builder pattern.
///
/// This widget is useful when you want to use hooks inside a transition
/// scope without creating a custom widget class. It's similar to
/// [HookBuilder] from flutter_hooks but with a [TransitionZoneWidget]
/// surrounding it, so the builder's context exposes both hooks and the
/// transition scope via `TransitionZone.of(context)`.
///
/// Example:
/// ```dart
/// HookTransitionZoneBuilder(
///   builder: (context) {
///     final scope = TransitionZone.of(context);
///     final id = useState(1);
///     return ElevatedButton(
///       onPressed: () => scope.startTransition(() => id.value++),
///       child: Text('${id.value}'),
///     );
///   },
/// )
/// ```
class HookTransitionZoneBuilder extends HookTransitionZoneWidget {
  /// Creates a [HookTransitionZoneBuilder].
  ///
  /// The [builder] is invoked with the build context of the surrounding
  /// [HookTransitionZoneElement].
  const HookTransitionZoneBuilder({super.key, required this.builder});

  /// The builder function that creates the widget tree.
  ///
  /// This function is called whenever the widget needs to rebuild. The
  /// supplied context is the [HookTransitionZoneElement], so callers may
  /// pass it to [TransitionZone.of] to retrieve the scope.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}
