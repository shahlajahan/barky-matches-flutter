extension DistinctBy<E> on Iterable<E> {
  List<E> distinctBy<K>(K Function(E e) keyOf) {
    final seen = <K>{};
    final out = <E>[];
    for (final e in this) {
      final k = keyOf(e);
      if (seen.add(k)) out.add(e);
    }
    return out;
  }
}