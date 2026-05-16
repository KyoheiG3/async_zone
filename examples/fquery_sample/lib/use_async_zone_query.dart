import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';
import 'package:fquery_core/fquery_core.dart';

/// Returns a [Completer] whose future resolves once the query identified by
/// [queryKey] reaches a terminal state in [cache].
///
/// Subscribes to [cache] (which outlives widgets), so the future still
/// resolves while a calling widget is unmounted by [AsyncZone] during
/// suspend. The listener self-removes after firing.
Completer<T> _completerForQuery<T extends Object, E extends Exception>(
  QueryCache cache,
  QueryKey queryKey,
) {
  final c = Completer<T>();
  final subId = identityHashCode(c);
  void unsub() => scheduleMicrotask(() => cache.unsubscribe(subId));
  void listener() {
    if (c.isCompleted) return unsub();
    final q = cache.queries[queryKey];
    if (q == null) return;
    if (q.isError) {
      c.completeError(q.error!);
      unsub();
    } else if (q.data != null) {
      c.complete(q.data as T);
      unsub();
    }
  }

  cache.subscribe(subId, listener);
  return c;
}

/// A useQuery-equivalent that suspends via [AsyncZone] while loading.
///
/// - When the query has data, returns the non-null [data] together with the
///   full [QueryResult] (for [refetch], `isFetching`, etc.).
/// - When the query has an error, throws it (caught by [ErrorBoundary]).
/// - While loading, throws a [Completer.future] that the surrounding
///   [AsyncZone] catches and resolves into its fallback.
({T data, QueryResult<T, E> query}) useAsyncZoneQuery<
  T extends Object,
  E extends Exception
>(RawQueryKey queryKey, QueryFn<T> queryFn, {BuildContext? context}) {
  final hookContext = useContext();
  final ctx = context ?? hookContext;
  final query = useQuery<T, E>(queryKey, queryFn, context: ctx);

  if (query.isError) throw query.error!;
  if (query.data != null) {
    return (data: query.data!, query: query);
  }

  final cache = CacheProvider.get(ctx);
  throw _completerForQuery<T, E>(cache, QueryKey(queryKey)).future;
}
