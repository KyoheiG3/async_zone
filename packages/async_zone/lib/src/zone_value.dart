class ZoneValue<T> {
  const ZoneValue(this.future);

  final Future<T> future;

  @override
  int get hashCode => identityHashCode(future);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZoneValue<T> && identical(other.future, future));
}
