import 'package:flutter/widgets.dart';

/// A widget that renders nothing and takes up no space.
///
/// [Empty] is used as a placeholder widget when no content should be displayed.
/// It creates a render object with zero size and no visual representation.
///
/// Used internally by [ZoneElement] and [ErrorZoneElement] to occupy a build
/// slot when the actual subtree is being suspended or escalated to an outer
/// zone. The user-visible fallback UI is rendered by [AsyncZone.fallback], not
/// by this widget.
class Empty extends SingleChildRenderObjectWidget {
  /// Creates an [Empty] widget.
  const Empty({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderNoop();
  }
}

/// A render object that takes up zero space and renders nothing.
class _RenderNoop extends RenderBox {
  @override
  void performLayout() {
    size = constraints.constrain(Size.zero);
  }
}
