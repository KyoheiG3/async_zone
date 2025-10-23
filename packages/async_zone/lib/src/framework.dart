import 'package:flutter/widgets.dart';

import 'async/zone_provider.dart';
import 'error/zone_provider.dart';
import 'foundation/empty.dart';

mixin ZoneElement on ComponentElement {
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

abstract class ZoneWidget extends StatelessWidget {
  const ZoneWidget({super.key});

  @override
  StatelessZoneElement createElement() => StatelessZoneElement(this);
}

class StatelessZoneElement extends StatelessElement with ZoneElement {
  StatelessZoneElement(super.widget);
}

abstract class StatefulZoneWidget extends StatefulWidget {
  const StatefulZoneWidget({super.key});

  @override
  StatefulZoneElement createElement() => StatefulZoneElement(this);
}

class StatefulZoneElement extends StatefulElement with ZoneElement {
  StatefulZoneElement(super.widget);
}
