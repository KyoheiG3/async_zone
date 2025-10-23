import 'package:flutter/widgets.dart';

import 'zone_element.dart';
import 'zone_widget.dart';

abstract class ErrorZone<T> extends StatelessWidget with ErrorZoneWidget<T> {
  ErrorZone({super.key});

  @override
  StatelessErrorZoneElement<T> createElement() =>
      StatelessErrorZoneElement(this);
}

class StatelessErrorZoneElement<T> extends StatelessElement
    with ErrorZoneElement<T> {
  StatelessErrorZoneElement(super.widget);

  @override
  ErrorZone<T> get widget => super.widget as ErrorZone<T>;
}

abstract class StatefulErrorZone<T> extends StatefulWidget
    with ErrorZoneWidget<T> {
  StatefulErrorZone({super.key});

  @override
  StatefulErrorZoneElement<T> createElement() => StatefulErrorZoneElement(this);
}

class StatefulErrorZoneElement<T> extends StatefulElement
    with ErrorZoneElement<T> {
  StatefulErrorZoneElement(super.widget);

  @override
  StatefulErrorZone<T> get widget => super.widget as StatefulErrorZone<T>;
}
