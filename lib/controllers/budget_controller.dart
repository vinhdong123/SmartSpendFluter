import '../services/sqlite_database_service.dart';

class BudgetController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<Map<String, dynamic>> fetchBudgetData() async {
    return await _sqlite.getBudgetData();
  }
}
