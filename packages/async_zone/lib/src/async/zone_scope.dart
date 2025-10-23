abstract class AsyncZoneScope {
  T use<T>(Future<T> future);
  void invalidateCache();
}

abstract class AsyncZoneProviderScope {
  void showFallback(Future future);
  bool canBuildChild();
}
