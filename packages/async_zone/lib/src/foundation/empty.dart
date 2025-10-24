import 'package:flutter/widgets.dart';

/// A widget that renders nothing and takes up no space.
///
/// [Empty] is used as a placeholder widget when no content should be displayed.
/// It creates a render object with zero size and no visual representation.
///
/// This is commonly used in async zones or error boundaries when waiting for
/// content to load or when displaying fallback UI.
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
