import '../services/sqlite_database_service.dart';

class GroupDebtController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<Map<String, dynamic>> fetchGroupDebtData() async {
    return await _sqlite.getGroupAndDebtData();
  }
}
