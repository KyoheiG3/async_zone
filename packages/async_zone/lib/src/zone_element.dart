import 'package:flutter/widgets.dart';

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

    void handleFuture(Future future) {
      asyncZone?.showFallback(future);

      void completeHandler() {
        _tasks.remove(future);

        if (_tasks.isEmpty && mounted) {
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
  void unmount() {
    _tasks.clear();
    _error = null;
    super.unmount();
  }
}
