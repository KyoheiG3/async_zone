import 'package:flutter/widgets.dart';

import 'foundation/sliver_empty.dart';
import 'zone_element.dart';

/// A mixin that swaps [ZoneElement.emptyPlaceholder] for a sliver-shaped
/// placeholder so the element stays valid inside a [CustomScrollView] while
/// suspended.
///
/// Mix this in alongside [ZoneElement] when building a custom sliver-shaped
/// element — for example, when combining [ZoneElement] with another mixin
/// (such as `HookElement` from `flutter_hooks`):
///
/// ```dart
/// class MyHookSliverZoneElement extends StatelessElement
///     with HookElement, ZoneElement, SliverZoneElementMixin {
///   MyHookSliverZoneElement(super.widget);
/// }
/// ```
///
/// The [SliverEmpty] sentinel itself is not exported; mix in this mixin to
/// adopt the sliver placeholder behaviour.
mixin SliverZoneElementMixin on ZoneElement {
  @override
  Widget get emptyPlaceholder => const SliverEmpty();
}

/// An abstract base class for stateless sliver widgets with zone-based async
/// and error handling.
///
/// Sliver-shaped counterpart of `ZoneWidget`. Use this when a suspendable
/// widget needs to live directly inside a [CustomScrollView] without being
/// wrapped in [SliverToBoxAdapter].
///
/// Subclasses must implement [build] and return a sliver widget (e.g.
/// [SliverList], [SliverToBoxAdapter]). When the build throws a [Future] or
/// error, the surrounding box-level `AsyncZone` / `ErrorBoundary` catches it
/// just like the box variant; while suspended, this element renders a
/// [SliverEmpty] so the sliver protocol is preserved.
///
/// Example:
/// ```dart
/// class MySliverZoneWidget extends SliverZoneWidget {
///   const MySliverZoneWidget({super.key, required this.future});
///
///   final Future<List<Item>> future;
///
///   @override
///   Widget build(BuildContext context) {
///     final items = AsyncZone.of(context).use(future);
///     return SliverList(
///       delegate: SliverChildBuilderDelegate(
///         (context, i) => ListTile(title: Text(items[i].name)),
///         childCount: items.length,
///       ),
///     );
///   }
/// }
/// ```
abstract class SliverZoneWidget extends StatelessWidget {
  /// Creates a [SliverZoneWidget].
  const SliverZoneWidget({super.key});

  @override
  StatelessSliverZoneElement createElement() =>
      StatelessSliverZoneElement(this);
}

/// An element for [SliverZoneWidget] that combines [StatelessElement] with
/// [ZoneElement] and [SliverZoneElementMixin].
class StatelessSliverZoneElement extends StatelessElement
    with ZoneElement, SliverZoneElementMixin {
  /// Creates a [StatelessSliverZoneElement] for the given [widget].
  StatelessSliverZoneElement(super.widget);
}

/// An abstract base class for stateful sliver widgets with zone-based async
/// and error handling.
///
/// Sliver-shaped counterpart of `StatefulZoneWidget`.
///
/// Example:
/// ```dart
/// class MySliverStatefulZoneWidget extends SliverStatefulZoneWidget {
///   const MySliverStatefulZoneWidget({super.key});
///
///   @override
///   State<MySliverStatefulZoneWidget> createState() => _State();
/// }
///
/// class _State extends State<MySliverStatefulZoneWidget> {
///   late final _future = myAsyncOperation();
///
///   @override
///   Widget build(BuildContext context) {
///     final items = AsyncZone.of(context).use(_future);
///     return SliverList.builder(
///       itemBuilder: (context, i) => Text(items[i]),
///       itemCount: items.length,
///     );
///   }
/// }
/// ```
abstract class SliverStatefulZoneWidget extends StatefulWidget {
  /// Creates a [SliverStatefulZoneWidget].
  const SliverStatefulZoneWidget({super.key});

  @override
  StatefulSliverZoneElement createElement() => StatefulSliverZoneElement(this);
}

/// An element for [SliverStatefulZoneWidget] that combines [StatefulElement]
/// with [ZoneElement] and [SliverZoneElementMixin].
class StatefulSliverZoneElement extends StatefulElement
    with ZoneElement, SliverZoneElementMixin {
  /// Creates a [StatefulSliverZoneElement] for the given [widget].
  StatefulSliverZoneElement(super.widget);
}

/// A sliver widget that builds itself using a builder callback with
/// zone-based async handling.
///
/// Sliver-shaped counterpart of `ZoneBuilder`. The [builder] must return a
/// sliver widget. Throwing a [Future] inside the builder triggers zone-based
/// async handling just like a regular [SliverZoneWidget].
///
/// Example:
/// ```dart
/// final future = fetchItems();
///
/// AsyncZone(
///   fallback: const Center(child: CircularProgressIndicator()),
///   child: CustomScrollView(
///     slivers: [
///       SliverZoneBuilder(
///         builder: (context) {
///           final items = AsyncZone.of(context).use(future);
///           return SliverList.builder(
///             itemBuilder: (context, i) => Text(items[i]),
///             itemCount: items.length,
///           );
///         },
///       ),
///     ],
///   ),
/// )
/// ```
class SliverZoneBuilder extends SliverZoneWidget {
  /// Creates a [SliverZoneBuilder].
  const SliverZoneBuilder({super.key, required this.builder});

  /// Called to obtain the sliver child widget. Throwing a [Future] inside
  /// this function triggers zone-based async handling.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}
