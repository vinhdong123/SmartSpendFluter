import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants/categories.dart';
import '../core/utils/formatters.dart';
import '../models/bill_model.dart';
import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import 'sqlite_database_service.dart';
import 'sync_service.dart';

/// Truy vấn bổ sung: ví, danh mục, ảnh hóa đơn, giao dịch định kỳ, nhắc hóa đơn, tài khoản.
extension ExtraQueries on SQLiteDatabaseService {
  // ================= WALLETS ================= //

  /// Sửa tên, loại và số dư hiện tại của ví (số dư ban đầu được điều chỉnh tương ứng).
  Future<void> updateWallet({
    required String id,
    required String name,
    required String type,
    required int currentBalance,
  }) async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT w.initial_balance,
        COALESCE((SELECT SUM(amount) FROM transactions WHERE wallet_id = w.id AND type = 'income'), 0)
        - COALESCE((SELECT SUM(amount) FROM transactions WHERE wallet_id = w.id AND type = 'expense'), 0)
        + COALESCE((SELECT SUM(amount) FROM transactions WHERE to_wallet_id = w.id AND type = 'transfer'), 0)
        - COALESCE((SELECT SUM(amount) FROM transactions WHERE wallet_id = w.id AND type = 'transfer'), 0)
        AS movement
      FROM wallets w WHERE w.id = ? AND w.user_id = ?
    ''', [id, uid]);
    if (rows.isEmpty) throw StateError('Không tìm thấy ví.');
    final movement = (rows.first['movement'] as num).toInt();
    await db.update(
      'wallets',
      {'name': name.trim(), 'type': type, 'initial_balance': currentBalance - movement},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, uid],
    );
  }

  /// "Xóa" ví: ẩn khỏi danh sách và không còn tính vào số dư. Giao dịch cũ vẫn được giữ.
  Future<void> archiveWallet(String id) async {
    final db = await readyDatabase;
    final active = await db.query(
      'wallets',
      columns: ['id'],
      where: 'user_id = ? AND is_archived = 0',
      whereArgs: [uid],
    );
    if (active.length <= 1) {
      throw StateError('Cần giữ lại ít nhất một ví.');
    }
    await db.update('wallets', {'is_archived': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, uid]);
    await db.delete('recurring_transactions', where: 'wallet_id = ? AND user_id = ?', whereArgs: [id, uid]);
  }

  // ================= CATEGORIES ================= //

  Future<void> applyCategoryRename({required String code, required String oldLabel, required String newLabel}) async {
    final db = await readyDatabase;
    await db.update(
      'transactions',
      {'kind': newLabel},
      where: 'user_id = ? AND category_code = ? AND kind = ?',
      whereArgs: [uid, code, oldLabel],
    );
  }

  /// Giao dịch thuộc danh mục bị xóa chuyển sang "Khác"; bỏ hạn mức ngân sách của danh mục đó.
  Future<void> applyCategoryDelete(String code) async {
    final db = await readyDatabase;
    await db.update(
      'transactions',
      {'kind': 'Khác', 'category_code': 'khac'},
      where: 'user_id = ? AND category_code = ?',
      whereArgs: [uid, code],
    );
    await db.update(
      'recurring_transactions',
      {'kind': 'Khác', 'category_code': 'khac'},
      where: 'user_id = ? AND category_code = ?',
      whereArgs: [uid, code],
    );
    await db.delete(
      'budget_items',
      where: 'category_code = ? AND budget_id IN (SELECT id FROM budgets WHERE user_id = ?)',
      whereArgs: [code, uid],
    );
  }

  // ================= RECEIPT ATTACHMENTS ================= //

  /// Lưu ảnh hóa đơn: sao chép vào thư mục của ứng dụng rồi gắn với giao dịch.
  Future<void> setReceipt(String transactionId, String sourcePath) async {
    final db = await readyDatabase;
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'receipts'));
    if (!await folder.exists()) await folder.create(recursive: true);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final dest = p.join(folder.path, '${transactionId}_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(sourcePath).copy(dest);

    await db.delete('attachments', where: 'transaction_id = ?', whereArgs: [transactionId]);
    await db.insert('attachments', {
      'id': 'att_${DateTime.now().microsecondsSinceEpoch}',
      'transaction_id': transactionId,
      'file_uri': dest,
      'mime_type': ext.toLowerCase() == '.png' ? 'image/png' : 'image/jpeg',
    });
  }

  Future<String?> getReceiptPath(String transactionId) async {
    final db = await readyDatabase;
    final rows = await db.query(
      'attachments',
      columns: ['file_uri'],
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'rowid DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final path = rows.first['file_uri'] as String;
    return File(path).existsSync() ? path : null;
  }

  Future<void> removeReceipt(String transactionId) async {
    final db = await readyDatabase;
    final path = await getReceiptPath(transactionId);
    await db.delete('attachments', where: 'transaction_id = ?', whereArgs: [transactionId]);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  // ================= RECURRING ================= //

  Future<List<RecurringModel>> getRecurring() async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT r.*, w.name AS wallet_name
      FROM recurring_transactions r
      LEFT JOIN wallets w ON w.id = r.wallet_id
      WHERE r.user_id = ?
      ORDER BY r.rowid
    ''', [uid]);
    return rows
        .map((r) => RecurringModel(
              id: r['id'] as String,
              isExpense: r['type'] == 'expense',
              category: r['kind'] as String,
              wallet: (r['wallet_name'] as String?) ?? 'Ví',
              amount: (r['amount'] as num).toInt(),
              frequency: r['frequency'] as String,
              startOn: DateTime.tryParse(r['start_on'] as String) ?? DateTime.now(),
              nextOn: DateTime.tryParse(r['next_on'] as String) ?? DateTime.now(),
              note: (r['note'] as String?) ?? '',
              active: (r['is_active'] as num) == 1,
            ))
        .toList();
  }

  Future<void> saveRecurring({
    String? id,
    required bool isExpense,
    required String category,
    required String walletName,
    required int amount,
    required String frequency,
    required DateTime startOn,
    String note = '',
  }) async {
    final db = await readyDatabase;
    final walletId = await resolveWalletId(walletName);
    final row = {
      'user_id': uid,
      'wallet_id': walletId,
      'type': isExpense ? 'expense' : 'income',
      'kind': category,
      'category_code': Categories.codeOf(category),
      'amount': amount,
      'frequency': frequency,
      'start_on': dbDate(startOn),
      'next_on': dbDate(startOn),
      'note': note.trim().isEmpty ? null : note.trim(),
      'is_active': 1,
    };
    if (id == null) {
      await db.insert('recurring_transactions', {'id': 'rec_${DateTime.now().microsecondsSinceEpoch}', ...row});
    } else {
      await db.update('recurring_transactions', row, where: 'id = ? AND user_id = ?', whereArgs: [id, uid]);
    }
  }

  Future<void> setRecurringActive(String id, bool active) async {
    final db = await readyDatabase;
    await db.update(
      'recurring_transactions',
      {'is_active': active ? 1 : 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, uid],
    );
  }

  Future<void> deleteRecurring(String id) async {
    final db = await readyDatabase;
    await db.delete('recurring_transactions', where: 'id = ? AND user_id = ?', whereArgs: [id, uid]);
  }

  /// Tạo các giao dịch định kỳ đã đến hạn (kể cả những kỳ bị lỡ khi chưa mở ứng dụng).
  /// Trả về số giao dịch đã tạo.
  Future<int> processRecurring() async {
    final db = await readyDatabase;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rows = await db.query(
      'recurring_transactions',
      where: 'user_id = ? AND is_active = 1 AND next_on <= ?',
      whereArgs: [uid, dbDate(today)],
    );
    var created = 0;
    for (final r in rows) {
      final id = r['id'] as String;
      final anchor = DateTime.tryParse(r['start_on'] as String) ?? today;
      var next = DateTime.tryParse(r['next_on'] as String) ?? today;
      final walletRows = await db.query(
        'wallets',
        columns: ['id'],
        where: 'id = ? AND user_id = ? AND is_archived = 0',
        whereArgs: [r['wallet_id'], uid],
        limit: 1,
      );
      if (walletRows.isEmpty) {
        await db.update('recurring_transactions', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
        continue;
      }
      var guard = 0;
      await db.transaction((txn) async {
        while (!next.isAfter(today) && guard < 400) {
          guard++;
          final inserted = await txn.insert(
            'transactions',
            {
              'id': 'tx_${id}_${dbDate(next)}',
              'user_id': uid,
              'wallet_id': r['wallet_id'],
              'category_code': r['category_code'],
              'type': r['type'],
              'kind': r['kind'],
              'amount': r['amount'],
              'occurred_on': dbDate(next),
              'note': (r['note'] as String?) ?? '${r['kind']} (định kỳ)',
              'created_at': DateTime(next.year, next.month, next.day, 7, 0).toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (inserted > 0) created++;
          next = RecurringModel.advance(next, r['frequency'] as String, anchor);
        }
        await txn.update('recurring_transactions', {'next_on': dbDate(next)}, where: 'id = ?', whereArgs: [id]);
      });
    }
    if (created > 0) SyncService.instance.markDirty();
    return created;
  }

  // ================= BILL REMINDERS ================= //

  Future<List<BillModel>> getBills({bool includePaid = false}) async {
    final db = await readyDatabase;
    final rows = await db.query(
      'bill_reminders',
      where: includePaid ? 'user_id = ?' : 'user_id = ? AND is_paid = 0',
      whereArgs: [uid],
      orderBy: 'due_on ASC',
    );
    return rows
        .map((r) => BillModel(
              id: r['id'] as String,
              title: r['title'] as String,
              amount: (r['amount'] as num).toInt(),
              dueOn: DateTime.tryParse(r['due_on'] as String) ?? DateTime.now(),
              repeatMonthly: (r['repeat_monthly'] as num) == 1,
              paid: (r['is_paid'] as num) == 1,
            ))
        .toList();
  }

  Future<void> saveBill({
    String? id,
    required String title,
    required int amount,
    required DateTime dueOn,
    required bool repeatMonthly,
  }) async {
    final db = await readyDatabase;
    final row = {
      'user_id': uid,
      'title': title.trim(),
      'amount': amount,
      'due_on': dbDate(dueOn),
      'repeat_monthly': repeatMonthly ? 1 : 0,
      'is_paid': 0,
    };
    if (id == null) {
      await db.insert('bill_reminders', {'id': 'bill_${DateTime.now().microsecondsSinceEpoch}', ...row});
    } else {
      await db.update('bill_reminders', row, where: 'id = ? AND user_id = ?', whereArgs: [id, uid]);
    }
  }

  Future<void> deleteBill(String id) async {
    final db = await readyDatabase;
    await db.delete('bill_reminders', where: 'id = ? AND user_id = ?', whereArgs: [id, uid]);
  }

  /// Đánh dấu đã thanh toán: ghi một khoản chi "Hóa đơn" và dời hạn sang tháng sau (nếu lặp lại).
  Future<void> payBill(BillModel bill, String walletName) async {
    final db = await readyDatabase;
    if (bill.amount > 0) {
      final walletId = await resolveWalletId(walletName);
      final now = DateTime.now();
      await db.insert('transactions', {
        'id': 'tx_bill_${DateTime.now().microsecondsSinceEpoch}',
        'user_id': uid,
        'wallet_id': walletId,
        'category_code': 'hoa_don',
        'type': 'expense',
        'kind': 'Hóa đơn',
        'amount': bill.amount,
        'occurred_on': dbDate(now),
        'note': bill.title,
        'created_at': now.toIso8601String(),
      });
    }
    if (bill.repeatMonthly) {
      final next = RecurringModel.advance(bill.dueOn, 'monthly', bill.dueOn);
      await db.update('bill_reminders', {'due_on': dbDate(next)}, where: 'id = ?', whereArgs: [bill.id]);
    } else {
      await db.update('bill_reminders', {'is_paid': 1}, where: 'id = ?', whereArgs: [bill.id]);
    }
    SyncService.instance.markDirty();
  }

  // ================= TRANSACTIONS ================= //

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT t.id, t.type, t.kind, t.amount, t.occurred_on, t.note, t.created_at, w.name AS wallet_name
      FROM transactions t
      LEFT JOIN wallets w ON w.id = t.wallet_id AND w.user_id = t.user_id
      WHERE t.id = ? AND t.user_id = ?
    ''', [id, uid]);
    if (rows.isEmpty) return null;
    return transactionFromRow(rows.first);
  }

  // ================= ACCOUNT ================= //

  /// Uid của tài khoản cục bộ theo email (null nếu không có).
  Future<String?> getLocalUserUid(String email) async {
    final db = await database;
    final rows = await db.query(
      'users',
      columns: ['id'],
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  Future<void> updateLocalPassword(String email, String newPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password_hash': newPassword},
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
  }
}
