/// A scope that provides the [use] method for consuming futures in an async zone.
///
/// This interface is implemented by [AsyncZoneProviderElement] and accessed
/// through [AsyncZone.of(context)].
///
/// Example:
/// ```dart
/// final zone = AsyncZone.of(context);
/// final data = zone.use(future);
/// ```
abstract class AsyncZoneScope {
  /// Consumes a future and returns its value when complete.
  ///
  /// If the future has already completed, returns the cached result.
  /// Otherwise, throws the future to trigger the async zone's fallback UI.
  ///
  /// When [freeze] is `true`, the previously rendered subtree below the
  /// enclosing [AsyncZone] is **kept on screen** while the future is pending,
  /// instead of being swapped out for the fallback. Use this for transition-
  /// style updates where flashing a loading indicator would be jarring.
  /// While frozen, no further widget updates propagate down through the zone
  /// until the future completes.
  T use<T>(Future<T> future, {bool freeze = false});
}

/// Internal scope interface for async zone provider functionality.
///
/// This interface is used by [ZoneElement] to interact with the async zone.
/// It is not intended to be used directly by application code.
abstract class AsyncZoneProviderScope {
  /// Shows the fallback UI for the given future.
  ///
  /// This method is called when a future is thrown during the build phase.
  /// When [freeze] is `true`, the existing subtree is retained instead of
  /// being replaced with the fallback widget.
  void showFallback(Future future, {bool freeze = false});

  /// Returns whether child widgets are allowed to build.
  ///
  /// Returns `false` if concurrent builds are disabled and there are pending tasks.
  bool canBuildChild();
}

/// Marker interface implemented by Elements whose build phase can catch the
/// [Future] thrown by [AsyncZoneScope.use].
///
/// The [ZoneElement] mixin implements this. [AsyncZone.of] uses it to detect
/// when a non-ZoneWidget calls into the scope and produce a descriptive error
/// instead of letting the thrown Future leak into Flutter's generic build
/// error handler.
///
/// Not exported from the package — this is an internal contract between
/// `AsyncZone` and the `ZoneElement` mixin.
abstract interface class AsyncZoneCaller {}

