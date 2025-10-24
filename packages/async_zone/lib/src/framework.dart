import 'package:flutter/widgets.dart';

import 'async/zone_provider.dart';
import 'error/zone_provider.dart';
import 'foundation/empty.dart';

/// A mixin that provides zone-based async and error handling capabilities to Flutter elements.
///
/// This mixin extends [ComponentElement] to automatically handle:
/// - Async operations that throw futures during the build phase
/// - Error boundaries for catching and handling errors
/// - Task tracking to prevent child updates while async operations are pending
///
/// When a future is thrown during the build phase, [ZoneElement] catches it,
/// tracks its completion, and triggers a rebuild when all pending tasks complete.
///
/// This mixin integrates with [AsyncZoneProvider] to show fallback UI during
/// async operations and [ErrorZoneProvider] to handle errors gracefully.
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

/// An abstract base class for stateless widgets with zone-based async and error handling.
///
/// [ZoneWidget] extends [StatelessWidget] and creates a [StatelessZoneElement]
/// which provides automatic handling of async operations and errors during the build phase.
///
/// Subclasses should implement the [build] method and can throw futures or errors
/// which will be caught and handled by the [ZoneElement] mixin.
///
/// Example:
/// ```dart
/// class MyZoneWidget extends ZoneWidget {
///   @override
///   Widget build(BuildContext context) {
///     final data = AsyncZone.of(context).use(myAsyncOperation());
///     return Text(data);
///   }
/// }
/// ```
abstract class ZoneWidget extends StatelessWidget {
  const ZoneWidget({super.key});

  @override
  StatelessZoneElement createElement() => StatelessZoneElement(this);
}

/// An element for [ZoneWidget] that combines [StatelessElement] with [ZoneElement].
///
/// This element provides zone-based async and error handling capabilities
/// for stateless widgets.
class StatelessZoneElement extends StatelessElement with ZoneElement {
  /// Creates a [StatelessZoneElement] for the given [widget].
  StatelessZoneElement(super.widget);
}

/// An abstract base class for stateful widgets with zone-based async and error handling.
///
/// [StatefulZoneWidget] extends [StatefulWidget] and creates a [StatefulZoneElement]
/// which provides automatic handling of async operations and errors during the build phase.
///
/// Subclasses should implement [createState] to return a [State] object, and the state's
/// [build] method can throw futures or errors which will be caught and handled by
/// the [ZoneElement] mixin.
///
/// Example:
/// ```dart
/// class MyStatefulZoneWidget extends StatefulZoneWidget {
///   @override
///   State<MyStatefulZoneWidget> createState() => _MyStatefulZoneWidgetState();
/// }
///
/// class _MyStatefulZoneWidgetState extends State<MyStatefulZoneWidget> {
///   @override
///   Widget build(BuildContext context) {
///     final data = AsyncZone.of(context).use(myAsyncOperation());
///     return Text(data);
///   }
/// }
/// ```
abstract class StatefulZoneWidget extends StatefulWidget {
  const StatefulZoneWidget({super.key});

  @override
  StatefulZoneElement createElement() => StatefulZoneElement(this);
}

/// An element for [StatefulZoneWidget] that combines [StatefulElement] with [ZoneElement].
///
/// This element provides zone-based async and error handling capabilities
/// for stateful widgets.
class StatefulZoneElement extends StatefulElement with ZoneElement {
  /// Creates a [StatefulZoneElement] for the given [widget].
  StatefulZoneElement(super.widget);
}
