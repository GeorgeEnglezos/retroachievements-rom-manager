typedef SelectionResult = ({Set<String> selected, String? lastSelected});

SelectionResult resolveSelection({
  required Set<String> current,
  required List<String> sortedPaths,
  required String tapped,
  required String? lastSelected,
  required bool isShift,
}) {
  if (isShift && lastSelected != null) {
    final a = sortedPaths.indexOf(lastSelected);
    final b = sortedPaths.indexOf(tapped);
    if (a != -1 && b != -1) {
      final lo = a < b ? a : b;
      final hi = a < b ? b : a;
      final next = Set<String>.from(current);
      for (var i = lo; i <= hi; i++) {
        next.add(sortedPaths[i]);
      }
      return (selected: next, lastSelected: lastSelected);
    }
  }
  final next = Set<String>.from(current);
  if (!next.remove(tapped)) next.add(tapped);
  return (selected: next, lastSelected: tapped);
}
