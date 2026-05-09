import 'dart:async';

/// A [Future] wrapper thrown by [AsyncZoneScope.use] when called with
/// `freeze: true`.
///
/// Acts as a signal to the surrounding [ZoneElement] that the previously
/// rendered subtree should be retained while [inner] is pending, rather than
/// being replaced with the [AsyncZone] fallback. Implements [Future] so that
/// existing `on Future catch` blocks still work when this type is not handled
/// explicitly.
///
/// Not exported from the package — this is an internal protocol type used
/// only between [AsyncZoneScope.use] and the [ZoneElement] mixin.
class FrozenFuture<T> implements Future<T> {
  /// Creates a [FrozenFuture] wrapping the given [inner] future.
  const FrozenFuture(this.inner);

  /// The underlying future being awaited.
  final Future<T> inner;

  @override
  Stream<T> asStream() => inner.asStream();

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      inner.catchError(onError, test: test);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => inner.then(onValue, onError: onError);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      inner.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      inner.whenComplete(action);
}
