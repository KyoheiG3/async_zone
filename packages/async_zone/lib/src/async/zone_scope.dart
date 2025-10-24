/// A scope that provides the [use] method for consuming futures in an async zone.
///
/// This interface is implemented by [AsyncZoneProviderElement] and accessed
/// through [AsyncZone.of(context)].
///
/// Example:
/// ```dart
/// final scope = AsyncZone.of(context);
/// final data = scope.use(fetchData());
/// ```
abstract class AsyncZoneScope {
  /// Consumes a future and returns its value when complete.
  ///
  /// If the future has already completed, returns the cached result.
  /// Otherwise, throws the future to trigger the async zone's fallback UI.
  T use<T>(Future<T> future);
}

/// Internal scope interface for async zone provider functionality.
///
/// This interface is used by [ZoneElement] to interact with the async zone.
/// It is not intended to be used directly by application code.
abstract class AsyncZoneProviderScope {
  /// Shows the fallback UI for the given future.
  ///
  /// This method is called when a future is thrown during the build phase.
  void showFallback(Future future);

  /// Returns whether child widgets are allowed to build.
  ///
  /// Returns `false` if parallel builds are disabled and there are pending tasks.
  bool canBuildChild();
}
