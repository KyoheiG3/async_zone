import 'package:flutter/widgets.dart';

import 'async/frozen_future.dart';
import 'async/zone_provider.dart';
import 'async/zone_scope.dart';
import 'error/zone_provider.dart';
import 'foundation/empty.dart';

/// A mixin that provides zone-based async and error handling capabilities to Flutter elements.
///
/// This mixin extends [ComponentElement] to automatically handle:
/// - Async operations that throw futures during the build phase
/// - Error boundaries for catching and handling errors
/// - Task tracking to prevent child updates while async operations are pending
///
/// When a future is thrown during the build phase, [ZoneElement] catches it,
/// tracks its completion, and triggers a rebuild when all pending tasks complete.
///
/// This mixin integrates with [AsyncZoneProvider] to show fallback UI during
/// async operations and [ErrorZoneProvider] to handle errors gracefully.
mixin ZoneElement on ComponentElement implements AsyncZoneCaller {
  final Set<Future<dynamic>> _tasks = {};
  dynamic _error;

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    return _tasks.isNotEmpty && child != null
        ? child
        : super.updateChild(child, newWidget, newSlot);
  }

  @override
  Widget build() {
    if (_error != null) {
      throw _error;
    }

    final asyncZone = AsyncZoneProvider.maybeOf(this);
    final errorZone = ErrorZoneProvider.maybeOf(this);

    // A rebuild means the widget/state has potentially changed, so any future
    // left over from a previous attempt is no longer the one we're waiting
    // on. Drop it before consulting canBuildChild — superseding may also
    // empty the provider's tracked tasks and re-enable building.
    _supersedePendingTasks(asyncZone);

    void handleFuture(Future future, {bool freeze = false}) {
      // Frozen futures stay local to this element: skipping showFallback
      // keeps the provider's tracked task set empty so the fallback never
      // appears, while this element's own _tasks still gates updateChild
      // to retain the previous subtree.
      if (asyncZone != null && !freeze) {
        asyncZone.showFallback(future);
      }

      void completeHandler() {
        if (_tasks.remove(future) && _tasks.isEmpty && mounted) {
          markNeedsBuild();
        }
      }

      _tasks.add(future);
      if (errorZone != null) {
        future.then((_) => completeHandler()).onError(errorZone.markShowError);
      } else {
        future
            .onError((error, _) => _error = error)
            .whenComplete(completeHandler);
      }
    }

    try {
      return (asyncZone?.canBuildChild() ?? true) ? super.build() : Empty();
    } on FrozenFuture catch (frozen) {
      handleFuture(frozen.inner, freeze: true);
    } on Future catch (future) {
      handleFuture(future);
    } catch (error, stackTrace) {
      if (errorZone == null) {
        rethrow;
      }

      if (errorZone.canShowError) {
        errorZone.markShowError(error, stackTrace);
      } else {
        handleFuture(Future.error(error, stackTrace));
      }
    }

    return Empty();
  }

  @override
  void deactivate() {
    // Ancestor lookup is only safe while still active. supersede here rather
    // than in unmount so the provider can drop these tasks from its set.
    _supersedePendingTasks(AsyncZoneProvider.maybeOf(this));
    super.deactivate();
  }

  @override
  void unmount() {
    _tasks.clear();
    _error = null;
    super.unmount();
  }

  /// Asks [asyncZone] to drop every future this element is currently tracking,
  /// then clears the local set. No-op when there is nothing pending.
  void _supersedePendingTasks(AsyncZoneProviderScope? asyncZone) {
    if (_tasks.isEmpty) return;
    if (asyncZone != null) {
      for (final future in _tasks) {
        asyncZone.supersedeFuture(future);
      }
    }
    _tasks.clear();
  }
}
