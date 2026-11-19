class SeriesPoint {
  final String label;
  final int value;
  final bool isCurrent;

  const SeriesPoint({required this.label, required this.value, required this.isCurrent});
}

class CategoryTotal {
  final String label;
  final int total;

  const CategoryTotal({required this.label, required this.total});
}
