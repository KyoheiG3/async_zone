import 'dart:async';

import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';

import 'transition_zone_scope.dart';

/// Wraps [child] in a transition scope.
///
/// Descendants can call `TransitionZone.of(context).startTransition(...)` to
/// schedule a state update that keeps the previous subtree visible while
/// suspending `ZoneWidget`s prepare the new state. `TransitionZone.of` also
/// exposes `isPending`, which dependents can subscribe to in order to dim
/// the in-flight subtree.
///
/// Example:
/// ```dart
/// TransitionBoundary(
///   child: MyScreen(),
/// )
///
/// // Anywhere inside MyScreen:
/// final scope = TransitionZone.of(context);
/// scope.startTransition(() => setState(() => userId++));
/// ```
class TransitionBoundary extends StatelessWidget {
  /// Creates a [TransitionBoundary].
  ///
  /// When [forceSameFrameRebuild] is `true`, dirty descendants are
  /// force-built synchronously during this scope's rebuild so any thrown
  /// futures land in `_tracked` before settling, allowing `isPending` to
  /// surface in the same frame the transition starts. When `false`
  /// (default), `isPending` surfaces one frame later via a post-frame
  /// callback. The default is conservative; enable opt-in only when the
  /// extra frame is visually noticeable.
  const TransitionBoundary({
    super.key,
    required this.child,
    this.forceSameFrameRebuild = false,
  });

  /// The subtree placed inside this transition scope.
  final Widget child;

  /// See the constructor doc for [TransitionBoundary.new].
  final bool forceSameFrameRebuild;

  @override
  Widget build(BuildContext context) => child;

  @override
  StatelessElement createElement() => _TransitionBoundaryElement(this);
}

class _TransitionBoundaryElement extends StatelessElement
    with _TransitionZoneState {
  _TransitionBoundaryElement(TransitionBoundary super.widget);

  @override
  bool get forceSameFrameRebuild =>
      (widget as TransitionBoundary).forceSameFrameRebuild;
}

mixin _TransitionZoneState on ComponentElement
    implements TransitionZoneScope, TransitionZoneBridge {
  bool _inTransition = false;
  bool _isPending = false;
  final Set<Future<dynamic>> _tracked = {};
  final Set<Future<dynamic>> _actionFutures = {};

  bool get forceSameFrameRebuild;

  @override
  bool get isPending => _isPending;

  @override
  bool get inTransition => _inTransition;

  @override
  void startTransition(FutureOr<void> Function() action) {
    if (_inTransition) {
      final result = action();
      if (result is Future) _trackAction(result);
      return;
    }
    _inTransition = true;

    try {
      // Run [action] synchronously so state changes are visible to the very
      // next build; deferring would let one rebuild operate on stale state
      // (e.g. [ErrorBoundary.onReset] would re-render the errored subtree).
      final result = action();
      if (result is Future) _trackAction(result);
    } finally {
      // Ensure [performRebuild] / the post-frame settle always run.
      if (mounted) markNeedsBuild();
      // Safety net for cases [performRebuild]'s inline settle misses
      // ([forceSameFrameRebuild] off, or descendants outside the walk).
      WidgetsBinding.instance.addPostFrameCallback((_) => _settleAndNotify());
    }
  }

  /// Reconciles [_isPending] and [_inTransition] with the active future
  /// sets. Returns true if [_isPending] flipped, so the caller can trigger
  /// a rebuild.
  bool _settle() {
    if (!_inTransition) return false;
    final shouldBePending = _tracked.isNotEmpty || _actionFutures.isNotEmpty;
    final flipped = _isPending != shouldBePending;
    if (flipped) _isPending = shouldBePending;
    if (_tracked.isEmpty && _actionFutures.isEmpty) _inTransition = false;
    return flipped;
  }

  /// Runs [_settle] and triggers a rebuild if [_isPending] flipped.
  ///
  /// With [awaitDirty], dirty descendants defer the settle to the next
  /// post-frame so they can register suspending futures via [track]
  /// first; this element is also marked dirty so [performRebuild]'s
  /// inline settle ([forceSameFrameRebuild] path) catches the change in
  /// the same frame.
  void _settleAndNotify({bool awaitDirty = false}) {
    if (!mounted) return;
    if (awaitDirty && _hasDirtyDescendant()) {
      markNeedsBuild();
      WidgetsBinding.instance.addPostFrameCallback((_) => _settleAndNotify());
    } else if (_settle()) {
      markNeedsBuild();
    }
  }

  @override
  void track(Future<dynamic> future) {
    if (!_inTransition) return;
    if (_tracked.add(future)) {
      future.onError((_, _) {}).whenComplete(() {
        if (_tracked.remove(future)) _settleAndNotify();
      });
    }
  }

  /// Tracks the [Future] returned by an async `startTransition` action.
  ///
  /// Action futures complete on a microtask before descendants' rebuild,
  /// so settling inline would tear down the transition prematurely. We
  /// route through [_settleAndNotify] with [awaitDirty] to defer.
  void _trackAction(Future<dynamic> future) {
    if (_actionFutures.add(future)) {
      future.onError((_, _) {}).whenComplete(() {
        if (_actionFutures.remove(future)) _settleAndNotify(awaitDirty: true);
      });
    }
  }

  bool _hasDirtyDescendant() {
    var found = false;
    void visit(Element element) {
      if (found) return;
      if (element.dirty) {
        found = true;
        return;
      }
      element.visitChildren(visit);
    }

    visitChildren(visit);
    return found;
  }

  void _rebuildIfDirty(Element element) {
    if (element.dirty) element.rebuild();
    element.visitChildren(_rebuildIfDirty);
  }

  @override
  void supersede(Future<dynamic> future) {
    _tracked.remove(future);
  }

  @override
  void performRebuild() {
    super.performRebuild();
    if (_inTransition && forceSameFrameRebuild) {
      // Force dirty descendants to rebuild synchronously so any thrown
      // futures land in [_tracked] before settling. If settling flips
      // [_isPending], rebuild inline to surface the new value in the same
      // frame — markNeedsBuild isn't usable here (Element.rebuild asserts
      // [_dirty] is false on return).
      visitChildren(_rebuildIfDirty);
      if (_settle()) super.performRebuild();
    }
  }

  @override
  Widget build() {
    return TransitionZoneProvider(
      bridge: this,
      isPending: _isPending,
      child: super.build(),
    );
  }

  @override
  void unmount() {
    _tracked.clear();
    _actionFutures.clear();
    super.unmount();
  }
}
