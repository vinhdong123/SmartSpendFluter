class SavingsGoalModel {
  final String id;
  final String name;
  final int target;
  final int saved;
  final DateTime? deadline;

  const SavingsGoalModel({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    this.deadline,
  });

  double get ratio => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  int get percent => (ratio * 100).round();
  bool get isDone => saved >= target;
}
