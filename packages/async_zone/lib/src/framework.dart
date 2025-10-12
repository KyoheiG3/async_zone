import 'package:async_zone/async_zone.dart';
import 'package:flutter/widgets.dart';

import 'zone_value.dart';

mixin ZoneElement on ComponentElement {
  final Set<Future<dynamic>> _tasks = {};

  @override
  void performRebuild() {
    final originalOnError = FlutterError.onError;

    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is! ZoneValue) {
        originalOnError?.call(details);
      }
    };

    try {
      super.performRebuild();
    } finally {
      FlutterError.onError = originalOnError;
    }
  }

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    return _tasks.isNotEmpty && child != null
        ? child
        : super.updateChild(child, newWidget, newSlot);
  }

  @override
  Widget build() {
    try {
      return super.build();
    } on Future catch (future) {
      AsyncZone.of(this).showFallback(future);

      _tasks.add(future);
      future
          .onError((_, _) {
            // Do nothing
          })
          .whenComplete(() {
            _tasks.remove(future);

            if (_tasks.isEmpty && mounted) {
              markNeedsBuild();
            }
          });

      throw ZoneValue(future);
    }
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
