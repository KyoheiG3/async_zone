import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A base class for stateless sliver widgets that support both hooks and zone
/// functionality.
///
/// Sliver-shaped counterpart of [HookZoneWidget]. Use this when a suspendable
/// hook-using widget needs to live directly inside a [CustomScrollView]
/// without being wrapped in [SliverToBoxAdapter]. The element mixes in both
/// [HookElement] and [ZoneElement], and overrides
/// [ZoneElement.emptyPlaceholder] to return [SliverEmpty] so the placeholder
/// stays a valid sliver while the widget is suspended.
///
/// Example:
/// ```dart
/// class MySliverHookZoneWidget extends SliverHookZoneWidget {
///   const MySliverHookZoneWidget({super.key, required this.future});
///
///   final Future<List<Item>> future;
///
///   @override
///   Widget build(BuildContext context) {
///     final items = useAsyncZone().use(future);
///     return SliverList.builder(
///       itemCount: items.length,
///       itemBuilder: (context, i) => Text(items[i].name),
///     );
///   }
/// }
/// ```
abstract class SliverHookZoneWidget extends StatelessWidget {
  /// Creates a [SliverHookZoneWidget].
  const SliverHookZoneWidget({super.key});

  @override
  SliverHookZoneElement createElement() => SliverHookZoneElement(this);
}

/// The element for [SliverHookZoneWidget].
///
/// Combines [StatelessElement] with [HookElement], [ZoneElement] and
/// [SliverZoneElementMixin] so the suspended placeholder remains a valid
/// sliver inside a [CustomScrollView].
class SliverHookZoneElement extends StatelessElement
    with HookElement, ZoneElement, SliverZoneElementMixin {
  /// Creates a [SliverHookZoneElement] for the given [widget].
  SliverHookZoneElement(super.widget);
}

/// A base class for stateful sliver widgets that support both hooks and zone
/// functionality.
///
/// Sliver-shaped counterpart of [StatefulHookZoneWidget]. Useful when the
/// suspendable hook-using widget also needs its own [State] (for example to
/// hold a future across hook reads).
///
/// Example:
/// ```dart
/// class MySliverStatefulHookZoneWidget extends SliverStatefulHookZoneWidget {
///   const MySliverStatefulHookZoneWidget({super.key});
///
///   @override
///   State<MySliverStatefulHookZoneWidget> createState() => _State();
/// }
///
/// class _State extends State<MySliverStatefulHookZoneWidget> {
///   late final _future = fetchItems();
///
///   @override
///   Widget build(BuildContext context) {
///     final reload = useState(0);
///     final items = useAsyncZone().use(_future);
///     return SliverList.builder(
///       itemCount: items.length,
///       itemBuilder: (context, i) => Text(items[i]),
///     );
///   }
/// }
/// ```
abstract class SliverStatefulHookZoneWidget extends StatefulWidget {
  /// Creates a [SliverStatefulHookZoneWidget].
  const SliverStatefulHookZoneWidget({super.key});

  @override
  SliverStatefulHookZoneElement createElement() =>
      SliverStatefulHookZoneElement(this);
}

/// The element for [SliverStatefulHookZoneWidget].
///
/// Combines [StatefulElement] with [HookElement], [ZoneElement] and
/// [SliverZoneElementMixin].
class SliverStatefulHookZoneElement extends StatefulElement
    with HookElement, ZoneElement, SliverZoneElementMixin {
  /// Creates a [SliverStatefulHookZoneElement] for the given [widget].
  SliverStatefulHookZoneElement(SliverStatefulHookZoneWidget super.hooks);
}

/// A convenience [SliverHookZoneWidget] that takes a [WidgetBuilder] returning
/// a sliver widget.
///
/// Sliver-shaped counterpart of [HookZoneBuilder]. Hooks can be used inside
/// [builder]; throwing a [Future] there triggers zone-based async handling
/// just like any [SliverHookZoneWidget].
///
/// Example:
/// ```dart
/// AsyncZone(
///   fallback: const Center(child: CircularProgressIndicator()),
///   child: CustomScrollView(
///     slivers: [
///       SliverHookZoneBuilder(
///         builder: (context) {
///           final future = useMemoized(fetchItems);
///           final items = useAsyncZone().use(future);
///           return SliverList.builder(
///             itemCount: items.length,
///             itemBuilder: (context, i) => Text(items[i]),
///           );
///         },
///       ),
///     ],
///   ),
/// )
/// ```
class SliverHookZoneBuilder extends SliverHookZoneWidget {
  /// Creates a [SliverHookZoneBuilder].
  const SliverHookZoneBuilder({super.key, required this.builder});

  /// Called to obtain the sliver child widget. Hooks may be used inside this
  /// function; throwing a [Future] triggers zone-based async handling.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}
