abstract class AsyncZoneScope {
  T use<T>(Future<T> future);
}

abstract class AsyncZoneProviderScope {
  void showFallback(Future future);
  bool canBuildChild();
}
