import 'package:flutter/widgets.dart';

import 'zone_provider.dart';
import 'zone_scope.dart';

/// A widget that manages async operations and displays fallback UI while they complete.
///
/// [AsyncZone] provides a declarative way to handle async operations in Flutter.
/// When an async operation is pending (via the [use] method), it automatically
/// shows the [fallback] widget instead of the [child].
///
/// Example:
/// ```dart
/// AsyncZone(
///   fallback: CircularProgressIndicator(),
///   child: MyContentWidget(),
/// )
/// ```
///
/// Inside [child], you can use [AsyncZone.of(context).use(future)] to handle
/// async operations. When a future is thrown, the zone catches it and shows
/// the fallback UI until it completes.
///
/// The [allowParallelBuilds] parameter controls whether child widgets can
/// build while async operations are pending from other parts of the tree.
///
/// See also:
/// - [AsyncZoneScope], which provides the [use] method for consuming futures.
/// - [ZoneWidget], which integrates with AsyncZone for automatic async handling.
class AsyncZone extends StatelessWidget {
  /// Creates an [AsyncZone] widget.
  ///
  /// The [fallback] and [child] parameters are required.
  /// The [allowParallelBuilds] parameter defaults to `true`.
  const AsyncZone({
    super.key,
    this.allowParallelBuilds = true,
    required this.fallback,
    required this.child,
  });

  /// Whether to allow child widgets to build while async operations are pending.
  ///
  /// When `true` (default), child widgets can continue building even if there
  /// are pending async operations from other parts of the tree.
  ///
  /// When `false`, all child builds are blocked while any async operation is pending.
  final bool allowParallelBuilds;

  /// The widget to display while async operations are pending.
  ///
  /// This is typically a loading indicator or placeholder UI.
  final Widget fallback;

  /// The main content widget to display when no async operations are pending.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AsyncZoneProvider(
      allowParallelBuilds: allowParallelBuilds,
      fallback: fallback,
      child: child,
    );
  }

  /// Returns the [AsyncZoneScope] from the closest [AsyncZone] ancestor.
  ///
  /// This method provides access to the [use] method for consuming futures
  /// within the async zone.
  ///
  /// If no [AsyncZone] is found in the widget tree, this method throws a [FlutterError].
  ///
  /// Example:
  /// ```dart
  /// final asyncZone = AsyncZone.of(context);
  /// final data = asyncZone.use(future);
  /// ```
  static AsyncZoneScope of(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AsyncZoneProvider>();

    if (element == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No AsyncZone widget found in context.'),
        ErrorDescription(
          'AsyncZone.of() was called with a context that does not contain an AsyncZone widget.',
        ),
        ErrorHint(
          'Ensure that the context passed to AsyncZone.of() is a descendant of an AsyncZone widget.',
        ),
        context.describeElement('The context used was'),
      ]);
    }

    return element as AsyncZoneScope;
  }
}
