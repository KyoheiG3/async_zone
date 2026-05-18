import 'package:flutter/widgets.dart';

import 'async/zone_provider.dart';
import 'async/zone_scope.dart';
import 'error/zone_provider.dart';
import 'foundation/empty.dart';
import 'transition/transition_provider.dart';
import 'transition/transition_scope.dart';

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

  /// Whether [super.build] has ever returned a widget for this element.
  ///
  /// A surrounding transition only has a prior subtree to preserve once
  /// this is `true`. On a fresh mount we instead route the suspending
  /// future to the [AsyncZone] fallback.
  bool _hasCommittedBuild = false;

  /// Placeholder widget returned when this element cannot build its child
  /// because a thrown future or error was routed to a fallback this frame.
  ///
  /// Defaults to the box-shaped [Empty] sentinel. Sliver-shaped subclasses
  /// (e.g. `StatelessSliverZoneElement`) override this so the placeholder
  /// remains a valid sliver inside a [CustomScrollView].
  Widget get emptyPlaceholder => const Empty();

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
    final transition = TransitionZoneProvider.maybeOf(this);

    // A rebuild means the widget/state has potentially changed, so any future
    // left over from a previous attempt is no longer the one we're waiting on.
    // Drop it before throwing the new one, so the provider's tracked task set
    // reflects only the futures from this build pass.
    _supersedePendingTasks(asyncZone, transition);

    void handleFuture(Future future) {
      // A surrounding transition wants the previous subtree kept on screen,
      // not the AsyncZone fallback — but only when there is a previously
      // committed build to preserve. On a fresh mount (e.g. an ErrorBoundary
      // just swapped back to its children after a retry) there is no prior
      // subtree, so we let the AsyncZone fallback show instead of extending
      // the transition.
      final inTransition = transition?.inTransition ?? false;
      final extendTransition = inTransition && _hasCommittedBuild;

      if (asyncZone != null && !extendTransition) {
        asyncZone.showFallback(future);
      }
      if (extendTransition) {
        transition!.track(future);
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
      final widget = super.build();
      _hasCommittedBuild = true;
      return widget;
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

    return emptyPlaceholder;
  }

  @override
  void deactivate() {
    // Ancestor lookup is only safe while still active. supersede here rather
    // than in unmount so the provider can drop these tasks from its set.
    _supersedePendingTasks(
      AsyncZoneProvider.maybeOf(this),
      TransitionZoneProvider.maybeOf(this),
    );
    super.deactivate();
  }

  @override
  void unmount() {
    _tasks.clear();
    _error = null;
    super.unmount();
  }

  /// Asks [asyncZone] and [transition] to drop every future this element is
  /// currently tracking, then clears the local set. No-op when there is
  /// nothing pending.
  void _supersedePendingTasks(
    AsyncZoneProviderScope? asyncZone,
    TransitionZoneBridge? transition,
  ) {
    if (_tasks.isEmpty) return;
    for (final future in _tasks) {
      asyncZone?.supersede(future);
      transition?.supersede(future);
    }
    _tasks.clear();
  }
}
