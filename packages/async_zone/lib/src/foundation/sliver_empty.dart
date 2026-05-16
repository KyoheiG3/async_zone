import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'empty.dart';

/// A sliver placeholder that occupies no scroll extent and paints nothing.
///
/// Sliver counterpart of [Empty]. Used internally by sliver-shaped
/// [ZoneElement] subclasses to keep the slot valid inside a
/// [CustomScrollView] while the underlying widget cannot yet be built.
class SliverEmpty extends LeafRenderObjectWidget {
  /// Creates a [SliverEmpty] widget.
  const SliverEmpty({super.key});

  @override
  RenderSliver createRenderObject(BuildContext context) => _RenderSliverEmpty();
}

class _RenderSliverEmpty extends RenderSliver {
  @override
  void performLayout() {
    geometry = SliverGeometry.zero;
  }
}
