import '../services/sqlite_database_service.dart';

class ReportController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<List<Map<String, dynamic>>> fetchCategoryBreakdown() async {
    return await _sqlite.getReportCategoryBreakdown();
  }
}
