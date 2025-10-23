import 'package:flutter/widgets.dart';

import 'zone_scope.dart';

class AsyncZoneProvider extends InheritedWidget {
  const AsyncZoneProvider({
    super.key,
    required this.allowParallelBuilds,
    required this.fallback,
    required super.child,
  });

  final bool allowParallelBuilds;
  final Widget fallback;

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

class AsyncZoneProviderElement extends InheritedElement
    implements AsyncZoneScope, AsyncZoneProviderScope {
  AsyncZoneProviderElement(this._widget) : super(_widget);

  final _cache = Expando<Object>('AsyncZone cache');
  final _errors = Expando<Object>('AsyncZone errors');
  final _tasks = <Future<dynamic>>{};

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
  Widget build() {
    return _tasks.isNotEmpty ? _widget.fallback : super.build();
  }

  @override
  bool canBuildChild() => _widget.allowParallelBuilds || _tasks.isEmpty;

  @override
  void showFallback(Future<dynamic> future) {
    final cachedError = _errors[future];
    if (cachedError != null) {
      throw cachedError;
    }

    if (!_isDuringPerformRebuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => markNeedsBuild());
    }

    _tasks.add(future);
    future
        .onError((error, _) {
          _errors[future] = error!;
        })
        .whenComplete(() {
          _tasks.remove(future);

          if (_tasks.isEmpty && mounted) {
            markNeedsBuild();
          }
        });
  }

  @override
  T use<T>(Future<T> future) {
    final cached = _cache[future];
    if (cached != null) {
      return cached as T;
    }

    future
        .then((value) {
          _cache[future] = value as Object;
        })
        .onError((_, _) {
          // Do nothing
        });

    throw future;
  }

  @override
  void unmount() {
    _tasks.clear();
    super.unmount();
  }
}
