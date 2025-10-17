import 'package:flutter/widgets.dart';

import 'async_zone.dart';
import 'empty.dart';

mixin ZoneElement on ComponentElement {
  final Set<Future<dynamic>> _tasks = {};

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    return _tasks.isNotEmpty && child != null
        ? child
        : super.updateChild(child, newWidget, newSlot);
  }

  @override
  Widget build() {
    final zone = AsyncZone.of(this);

    try {
      return zone.canBuildChild() ? super.build() : Empty();
    } on Future catch (future) {
      zone.showFallback(future);

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

      return Empty();
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
