import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

abstract class AsyncZoneScope {
  T use<T>(Future<T> future);
  void invalidateCache();

  @internal
  void showFallback(Future<dynamic> future);
}

class AsyncZone extends StatelessWidget {
  const AsyncZone({super.key, required this.child, required this.fallback});

  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return AsyncZoneProvider(fallback: fallback, child: child);
  }

  static AsyncZoneScope of(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AsyncZoneProvider>();
    assert(element != null, 'No AsyncZoneProvider found in context');
    return element! as AsyncZoneScope;
  }
}

class AsyncZoneProvider extends InheritedWidget {
  const AsyncZoneProvider({
    super.key,
    required super.child,
    required this.fallback,
  });

  final Widget fallback;

  @override
  AsyncZoneProviderElement createElement() => AsyncZoneProviderElement(this);

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

class AsyncZoneProviderElement extends InheritedElement with AsyncZoneElement {
  AsyncZoneProviderElement(AsyncZoneProvider super.widget);
}

mixin AsyncZoneElement on ComponentElement implements AsyncZoneScope {
  final _cache = <Future<dynamic>, Object>{};
  final _errors = <Future<dynamic>, dynamic>{};
  final _tasks = <Future<dynamic>>{};

  var _isDuringPerformRebuild = false;

  AsyncZoneProvider get _provider => widget as AsyncZoneProvider;

  @override
  void performRebuild() {
    _isDuringPerformRebuild = true;
    final shouldShowFallbackBefore = _tasks.isNotEmpty;

    try {
      super.performRebuild();

      // If fallback display is needed, rebuild again to show the fallback
      if (shouldShowFallbackBefore != _tasks.isNotEmpty) {
        super.performRebuild();
      }
    } finally {
      _isDuringPerformRebuild = false;
    }
  }

  @override
  Widget build() {
    return _tasks.isNotEmpty ? _provider.fallback : super.build();
  }

  @override
  void showFallback(Future<dynamic> future) {
    if (_errors.containsKey(future)) {
      throw _errors[future];
    }

    if (!_isDuringPerformRebuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => markNeedsBuild());
    }

    _tasks.add(future);
    future
        .onError((error, _) {
          _errors[future] = error;
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
    if (_cache.containsKey(future)) {
      return _cache[future] as T;
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
  void invalidateCache() {
    _cache.clear();
    _errors.clear();
  }
}
