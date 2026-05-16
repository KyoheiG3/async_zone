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
  /// When [freeze] is `true`, the calling widget's previously rendered
  /// subtree is **kept on screen** while the future is pending, instead of the
  /// enclosing [AsyncZone] swapping to its fallback. Use this for transition-
  /// style updates where flashing a loading indicator would be jarring.
  /// The freeze is local to the calling widget: sibling [ZoneWidget]s under
  /// the same [AsyncZone] continue to build normally and the provider does
  /// not treat the pending future as a tracked task, so [AsyncZone]'s
  /// fallback never appears for a frozen future.
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
  /// Frozen futures (`use(future, freeze: true)`) are handled entirely
  /// inside [ZoneElement] and must not be reported here — registering one
  /// would cause the provider to swap to its fallback, defeating the
  /// purpose of freezing.
  void showFallback(Future future);

  /// Drops [future] from the set of tracked tasks without waiting for it to
  /// complete.
  ///
  /// Used when a caller has decided that a previously-tracked future is no
  /// longer relevant — typically because the caller rebuilt with new state
  /// and threw a fresh future. The listener chain attached in [showFallback]
  /// stays bound to the original future, but becomes a no-op once the entry
  /// is removed here.
  void supersedeFuture(Future future);
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
