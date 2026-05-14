import 'package:flutter/widgets.dart';

import 'frozen_future.dart';
import 'zone_scope.dart';

/// An [InheritedWidget] that provides async zone functionality to descendant widgets.
///
/// This widget is created by [AsyncZone] and manages the state and caching
/// for async operations. It implements both [AsyncZoneScope] and [AsyncZoneProviderScope]
/// through its element.
///
/// This class is typically not used directly. Use [AsyncZone] instead.
class AsyncZoneProvider extends InheritedWidget {
  /// Creates an [AsyncZoneProvider].
  ///
  /// All parameters are required.
  const AsyncZoneProvider({
    super.key,
    required this.allowConcurrentBuilds,
    required this.fallback,
    required super.child,
  });

  /// Whether sibling [ZoneWidget]s in this zone may build concurrently while
  /// another future is pending. See [AsyncZone.allowConcurrentBuilds].
  final bool allowConcurrentBuilds;

  /// The fallback widget to show while async operations are pending.
  final Widget fallback;

  /// Returns the [AsyncZoneProviderScope] from the closest [AsyncZoneProvider] ancestor, if any.
  ///
  /// This method is used internally by the framework to access async zone functionality.
  /// Returns `null` if no [AsyncZoneProvider] is found in the widget tree.
  static AsyncZoneProviderScope? maybeOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AsyncZoneProvider>();
    return element as AsyncZoneProviderScope?;
  }

  @override
  AsyncZoneProviderElement createElement() => AsyncZoneProviderElement(this);

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// The element for [AsyncZoneProvider] that manages async operation state.
///
/// This element implements both [AsyncZoneScope] and [AsyncZoneProviderScope]
/// to provide async functionality to descendant widgets. It manages:
/// - Caching of completed future results
/// - Tracking of pending async operations
/// - Automatic rebuilds when async state changes
class AsyncZoneProviderElement extends InheritedElement
    implements AsyncZoneScope, AsyncZoneProviderScope {
  /// Creates an [AsyncZoneProviderElement] for the given [widget].
  AsyncZoneProviderElement(this._widget) : super(_widget);

  final _cache = Expando<({Object? value})>('AsyncZone cache');
  final _errors = Expando<Object>('AsyncZone errors');
  final _tasks = <Future<dynamic>, bool>{};

  var _isDuringPerformRebuild = false;

  final AsyncZoneProvider _widget;

  @override
  void performRebuild() {
    _isDuringPerformRebuild = true;
    final hasTaskBefore = _tasks.isNotEmpty;

    try {
      super.performRebuild();

      // If fallback display is needed, rebuild again to show the fallback
      if (hasTaskBefore != _tasks.isNotEmpty) {
        super.performRebuild();
      }
    } finally {
      _isDuringPerformRebuild = false;
    }
  }

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    final hasFrozen = _tasks.values.any((freeze) => freeze);
    return hasFrozen && child != null
        ? child
        : super.updateChild(child, newWidget, newSlot);
  }

  @override
  Widget build() {
    return Stack(
      children: [
        Visibility(
          visible: _tasks.isEmpty,
          maintainState: true,
          child: super.build(),
        ),
        if (_tasks.isNotEmpty) _widget.fallback,
      ],
    );
  }

  @override
  bool canBuildChild() => _widget.allowConcurrentBuilds || _tasks.isEmpty;

  @override
  void showFallback(Future<dynamic> future, {bool freeze = false}) {
    final cachedError = _errors[future];
    if (cachedError != null) {
      throw cachedError;
    }

    if (!_isDuringPerformRebuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => markNeedsBuild());
    }

    _tasks[future] = freeze;
    future
        .onError((error, _) {
          _errors[future] = error;
        })
        .whenComplete(() {
          // Skip if already superseded: remove returns null when the entry
          // is no longer tracked, short-circuiting the rebuild.
          if (_tasks.remove(future) != null && _tasks.isEmpty && mounted) {
            markNeedsBuild();
          }
        });
  }

  @override
  void supersedeFuture(Future<dynamic> future) {
    _tasks.remove(future);
  }

  /// Consumes a future and returns its value when complete.
  ///
  /// If the future has already completed, returns the cached result immediately.
  /// Otherwise, throws the future to trigger async handling, which will cause
  /// the fallback UI to be displayed until the future completes.
  ///
  /// This method caches the result of completed futures, so subsequent calls
  /// with the same future instance will return the cached value without
  /// triggering async handling again.
  @override
  T use<T>(Future<T> future, {bool freeze = false}) {
    final cached = _cache[future];
    if (cached != null) {
      return cached.value as T;
    }

    future
        .then((value) {
          _cache[future] = (value: value);
        })
        .onError((_, _) {
          // Do nothing
        });

    throw freeze ? FrozenFuture(future) : future;
  }

  @override
  void unmount() {
    _tasks.clear();
    super.unmount();
  }
}
