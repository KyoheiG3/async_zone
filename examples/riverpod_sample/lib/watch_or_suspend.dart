import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Watches the current [AsyncValue] of [provider] and:
///
/// - returns the non-null `data` together with the [AsyncData] state (for
///   `isLoading`, `isRefreshing`, etc.) whenever the provider holds data —
///   stale-while-revalidate during refresh,
/// - throws `error` (caught by [ErrorBoundary]) when in [AsyncError] without
///   previous data,
/// - while [AsyncLoading] with no previous value, throws the underlying
///   [Future] that [AsyncZone] resolves when the provider completes.
///
/// `AsyncZone` keeps this widget mounted via `Visibility(maintainState: true)`
/// while suspended, so the `ref.watch` subscription stays alive across the
/// fallback cycle.
({T data, AsyncData<T> asyncData}) watchOrSuspend<T>(
  WidgetRef ref,
  FutureProvider<T> provider,
) {
  final value = ref.watch(provider);
  if (value is AsyncError<T>) throw value.error;
  if (value is AsyncData<T>) {
    return (data: value.value, asyncData: value);
  }
  throw ref.watch(provider.future);
}
