import 'package:flutter/widgets.dart';

class Empty extends SingleChildRenderObjectWidget {
  const Empty({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderNoop();
  }
}

class _RenderNoop extends RenderBox {
  @override
  void performLayout() {
    size = constraints.constrain(Size.zero);
  }
}
