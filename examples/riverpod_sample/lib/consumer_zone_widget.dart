import 'package:async_zone/async_zone.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/src/internals.dart';

/// A widget that is both a [ConsumerWidget] and a zone-aware widget.
///
/// Combines Riverpod's `ref.watch`/`ref.listen`/`ref.read` capabilities with
/// the ability for [AsyncZone] and [ErrorBoundary] to catch [Future]s and
/// errors thrown during build.
///
/// Modeled after `HookConsumerWidget` from `hooks_riverpod`, which fuses
/// `HookElement` with `ConsumerStatefulElement`. Here we fuse [ZoneElement]
/// instead.
abstract class ConsumerZoneWidget extends ConsumerWidget {
  const ConsumerZoneWidget({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ConsumerZoneElement createElement() => _ConsumerZoneElement(this);
}

// ignore: invalid_use_of_internal_member
final class _ConsumerZoneElement extends ConsumerStatefulElement
    with ZoneElement {
  _ConsumerZoneElement(ConsumerZoneWidget super.widget);
}
