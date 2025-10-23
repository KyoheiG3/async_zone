import 'package:flutter/widgets.dart';

import 'zone_provider.dart';
import 'zone_scope.dart';

class AsyncZone extends StatelessWidget {
  const AsyncZone({
    super.key,
    this.allowParallelBuilds = true,
    required this.fallback,
    required this.child,
  });

  final bool allowParallelBuilds;
  final Widget fallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AsyncZoneProvider(
      allowParallelBuilds: allowParallelBuilds,
      fallback: fallback,
      child: child,
    );
  }

  static AsyncZoneScope of(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AsyncZoneProvider>();

    if (element == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No AsyncZone widget found in context.'),
        ErrorDescription(
          'AsyncZone.of() was called with a context that does not contain an AsyncZone widget.',
        ),
        ErrorHint(
          'Ensure that the context passed to AsyncZone.of() is a descendant of an AsyncZone widget.',
        ),
        context.describeElement('The context used was'),
      ]);
    }

    return element as AsyncZoneScope;
  }
}
