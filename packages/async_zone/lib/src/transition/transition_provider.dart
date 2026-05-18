import 'dart:async';

import 'package:flutter/widgets.dart';

import 'transition_scope.dart';

/// An [InheritedWidget] that publishes a [TransitionZoneBridge] to
/// descendants, used by [TransitionZone.bridgeOf].
///
/// Created internally by [TransitionZoneElement.build]; not intended to be
/// instantiated directly.
class TransitionZoneProvider extends InheritedWidget {
  /// Creates a [TransitionZoneProvider].
  const TransitionZoneProvider({
    super.key,
    required this.scope,
    required this.isPending,
    required super.child,
  });

  /// The scope owned by the surrounding [TransitionZoneElement]. The same
  /// object also implements [TransitionZoneBridge].
  final TransitionZoneScope scope;

  /// Snapshot of [TransitionZoneScope.isPending] at the time this widget was
  /// created. Used by [updateShouldNotify] to flip dependents only when the
  /// flag actually changes.
  final bool isPending;

  /// Returns the [TransitionZoneBridge] from the closest
  /// [TransitionZoneProvider] ancestor, if any. Does not register the caller
  /// as a dependent.
  static TransitionZoneBridge? maybeOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<TransitionZoneProvider>();
    return (element?.widget as TransitionZoneProvider?)?.scope
        as TransitionZoneBridge?;
  }

  @override
  bool updateShouldNotify(TransitionZoneProvider old) =>
      isPending != old.isPending;
}

/// A mixin that turns a [ComponentElement] into a transition scope.
///
/// The mixin holds the transition state (`isPending`, the tracked futures)
/// and overrides [build] to publish the scope through a
/// [TransitionZoneProvider] wrapped around `super.build()`. Mix into any
/// element type to integrate transition coordination — for example:
///
/// ```dart
/// class HookTransitionZoneElement extends HookElement
///     with TransitionZoneElement {
///   HookTransitionZoneElement(super.widget);
/// }
/// ```
mixin TransitionZoneElement on ComponentElement
    implements TransitionZoneScope, TransitionZoneBridge {
  bool _inTransition = false;
  bool _isPending = false;
  final Set<Future<dynamic>> _tracked = {};

  @override
  bool get isPending => _isPending;

  @override
  bool get inTransition => _inTransition;

  @override
  void startTransition(FutureOr<void> Function() action) {
    if (_inTransition) {
      // Nested call: just run, the outer transition still tracks new futures.
      final result = action();
      if (result is Future) track(result);
      return;
    }
    _inTransition = true;

    try {
      // Run [action] synchronously so any state changes it performs are in
      // place for the very next build. Deferring it would leave one rebuild
      // operating on stale state — e.g. an [ErrorBoundary.onReset] callback
      // would re-render the previous errored subtree before the new state
      // arrives.
      final result = action();
      if (result is Future) track(result);
    } finally {
      // Drive [performRebuild]'s two-phase logic so descendants observe
      // isPending in the same frame the transition starts.
      if (mounted) markNeedsBuild();
    }
  }

  @override
  void track(Future<dynamic> future) {
    if (!_inTransition) return;
    if (_tracked.add(future)) {
      future
          .onError((_, _) {
            // Do nothing
          })
          .whenComplete(() {
            if (_tracked.remove(future)) _finishIfIdle();
          });
    }
  }

  @override
  void supersede(Future<dynamic> future) {
    // Drop without firing [_finishIfIdle]; [performRebuild] reconciles
    // _tracked once the rebuild has collected any new throws. Calling
    // [_finishIfIdle] here would race with [track] re-adding the future
    // in the same build.
    _tracked.remove(future);
  }

  void _finishIfIdle() {
    if (!mounted) return;
    if (_inTransition && _tracked.isEmpty) {
      _inTransition = false;
      if (_isPending) {
        _isPending = false;
        markNeedsBuild();
      }
    }
  }

  @override
  void performRebuild() {
    super.performRebuild();
    if (_inTransition) {
      // Two-phase rebuild: after the first build descendants have had a
      // chance to register futures into [_tracked]; if that diverges from
      // [_isPending], rebuild once more so descendants observe the
      // corresponding isPending value in the same frame.
      final shouldBePending = _tracked.isNotEmpty;
      if (_isPending != shouldBePending) {
        _isPending = shouldBePending;
        super.performRebuild();
      }
      // If nothing suspended, end the transition so a follow-up
      // startTransition starts from a clean slate.
      if (!shouldBePending) {
        _inTransition = false;
      }
    }
  }

  @override
  Widget build() {
    return TransitionZoneProvider(
      scope: this,
      isPending: _isPending,
      child: super.build(),
    );
  }

  @override
  void unmount() {
    _tracked.clear();
    super.unmount();
  }
}

/// A [StatelessElement] with [TransitionZoneElement] mixed in, used by
/// [TransitionZoneWidget].
class StatelessTransitionZoneElement extends StatelessElement
    with TransitionZoneElement {
  /// Creates a [StatelessTransitionZoneElement] for the given [widget].
  StatelessTransitionZoneElement(super.widget);
}

/// A [StatefulElement] with [TransitionZoneElement] mixed in, for users who
/// need transition coordination on a stateful widget without writing the
/// boilerplate element class themselves.
class StatefulTransitionZoneElement extends StatefulElement
    with TransitionZoneElement {
  /// Creates a [StatefulTransitionZoneElement] for the given [widget].
  StatefulTransitionZoneElement(super.widget);
}
