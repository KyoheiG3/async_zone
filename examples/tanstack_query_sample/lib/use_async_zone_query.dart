import 'dart:async';

import 'package:tanstack_query/tanstack_query.dart';

/// Returns a [Completer] whose future resolves once the query identified by
/// [cacheKey] reaches a terminal state in [cache].
///
/// Subscribes to [cache] (which outlives widgets), so the future still
/// resolves while a calling widget is unmounted by [AsyncZone] during
/// suspend. The listener self-removes after firing.
Completer<T> _completerForQuery<T>(QueryCache cache, String cacheKey) {
  final c = Completer<T>();
  late final void Function() unsubscribe;
  void settle() => scheduleMicrotask(unsubscribe);
  void listener(QueryCacheNotifyEvent event) {
    if (c.isCompleted) return settle();
    if (event.cacheKey != cacheKey) return;
    final res = event.entry?.result;
    if (res is! QueryResult) return;
    if (res.isError) {
      c.completeError(res.error ?? Exception('Query failed'));
      settle();
    } else if (res.data != null) {
      c.complete(res.data as T);
      settle();
    }
  }

  unsubscribe = cache.subscribe(listener);
  return c;
}

/// A useQuery-equivalent that suspends via [AsyncZone] while loading.
///
/// - When the query has data, returns the non-null [data] together with the
///   full [QueryResult] (for [refetch], `isFetching`, etc.).
/// - When the query has an error, throws it (caught by [ErrorBoundary]).
/// - While loading, throws a [Completer.future] that the surrounding
///   [AsyncZone] catches and resolves into its fallback.
({T data, QueryResult<T> query}) useAsyncZoneQuery<T>(
  List<Object> queryKey,
  Future<T> Function() queryFn,
) {
  final query = useQuery<T>(queryKey: queryKey, queryFn: queryFn);

  if (query.isError) throw query.error!;
  if (query.data != null) {
    return (data: query.data as T, query: query);
  }

  final client = useQueryClient();
  throw _completerForQuery<T>(client.queryCache, query.key).future;
}
