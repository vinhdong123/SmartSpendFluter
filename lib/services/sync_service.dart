import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/utils/app_settings.dart';
import '../core/utils/formatters.dart';
import '../models/user_model.dart';
import 'sqlite_database_service.dart';

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);

  @override
  String toString() => message;
}

/// Gọi sau mỗi thao tác ghi dữ liệu cá nhân để đẩy thay đổi lên Firestore.
Future<T> markSynced<T>(Future<T> action) async {
  final result = await action;
  SyncService.instance.markDirty();
  return result;
}

/// Đồng bộ SQLite <-> Cloud Firestore.
///
/// * Dữ liệu cá nhân: `users/{uid}/{bảng}/{id}` (SQLite là bản làm việc, Firestore là bản sao lưu).
/// * Nhóm chia tiền: `groups/{gid}` (+ `expenses`, `settlements`) dùng chung giữa các thành viên.
///
/// Chỉ hoạt động khi người dùng đăng nhập bằng Firebase Auth.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const List<String> _tables = [
    'wallets',
    'budgets',
    'budget_items',
    'savings_goals',
    'goal_contributions',
    'transactions',
    'debts',
    'debt_payments',
  ];

  static const Duration _timeout = Duration(seconds: 15);

  /// Tăng lên khi dữ liệu local thay đổi do đồng bộ (để UI nạp lại).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final ValueNotifier<String> status = ValueNotifier<String>('Chưa bật đồng bộ');

  bool _active = false;
  bool _busy = false;
  String _uid = '';
  String _name = '';
  String _email = '';
  Timer? _timer;
  Map<String, Map<String, String>> _synced = {};

  bool get isActive => _active;
  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  SQLiteDatabaseService get _sqlite => SQLiteDatabaseService.instance;

  bool _canSync(UserModel user) {
    try {
      final current = fb.FirebaseAuth.instance.currentUser;
      return current != null && current.uid == user.uid;
    } catch (_) {
      return false;
    }
  }

  String _now() {
    final n = DateTime.now();
    return '${two(n.hour)}:${two(n.minute)}';
  }

  String _describe(Object e) {
    if (e is TimeoutException) return 'Không có kết nối mạng';
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Firestore từ chối quyền truy cập – cần cập nhật Firestore Rules';
      }
      return e.message ?? e.code;
    }
    return '$e';
  }

  void _onWriteError(Object e) {
    status.value = 'Lỗi ghi Firestore: ${_describe(e)}';
  }

  // ================= LIFECYCLE ================= //

  void stop() {
    _timer?.cancel();
    _timer = null;
    _active = false;
    _synced = {};
    status.value = 'Chưa bật đồng bộ';
  }

  Future<void> start(UserModel user) async {
    stop();
    if (!_canSync(user)) {
      status.value = 'Chưa đồng bộ (đang dùng tài khoản cục bộ)';
      return;
    }
    _active = true;
    _uid = user.uid;
    _name = user.fullName;
    _email = user.email.trim().toLowerCase();
    status.value = 'Đang đồng bộ...';

    // Hồ sơ công khai để người khác tìm theo email khi thêm vào nhóm.
    _fs
        .collection('users')
        .doc(_uid)
        .set({
          'email': _email,
          'displayName': _name,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true))
        .catchError(_onWriteError);

    final changed = await _syncAll();
    if (changed) revision.value++;
  }

  /// Nút "Đồng bộ ngay". Trả về thông báo lỗi hoặc null nếu thành công.
  Future<String?> syncNow() async {
    if (!_active) return 'Cần đăng nhập bằng tài khoản Firebase để đồng bộ.';
    try {
      await _push();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_dirty_$_uid', false);
    } catch (_) {}
    final changed = await _syncAll();
    if (changed) revision.value++;
    return status.value.startsWith('Lỗi') ? status.value : null;
  }

  /// Chỉ cho phép đồng bộ khi dùng Wi-Fi/Ethernet nếu người dùng bật "Chỉ đồng bộ khi dùng Wi-Fi".
  Future<bool> _networkAllowed() async {
    if (!AppSettings.wifiOnly) return true;
    try {
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.wifi) || result.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return true;
    }
  }

  /// Còn thay đổi chưa được đẩy lên đám mây?
  Future<bool> hasPendingChanges() async {
    if (!_active) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sync_dirty_$_uid') ?? false;
  }

  /// Khôi phục dữ liệu từ đám mây (ghi đè dữ liệu cá nhân trên máy bằng bản đã sao lưu).
  Future<String?> restoreFromCloud() async {
    if (!_active) return 'Cần đăng nhập bằng tài khoản Firebase để khôi phục.';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_dirty_$_uid', false);
    final changed = await _syncAll();
    if (changed) revision.value++;
    return status.value.startsWith('Lỗi') ? status.value : null;
  }

  void markDirty() {
    if (!_active) return;
    SharedPreferences.getInstance().then((p) => p.setBool('sync_dirty_$_uid', true));
    _timer?.cancel();
    if (!AppSettings.autoSync) {
      status.value = 'Có thay đổi chưa sao lưu (đồng bộ tự động đang tắt)';
      return;
    }
    _timer = Timer(const Duration(milliseconds: 600), () async {
      if (!await _networkAllowed()) {
        status.value = 'Đang chờ Wi-Fi để đồng bộ';
        return;
      }
      try {
        await _push();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('sync_dirty_$_uid', false);
        status.value = 'Đã đồng bộ lúc ${_now()}';
      } catch (e) {
        status.value = 'Lỗi đồng bộ: ${_describe(e)}';
      }
    });
  }

  // ================= PERSONAL DATA ================= //

  Future<bool> _syncAll() async {
    if (_busy) return false;
    _busy = true;
    var changed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dirtyKey = 'sync_dirty_$_uid';
      final dirty = prefs.getBool(dirtyKey) ?? false;

      final remote = await _fetchRemote();
      final remoteEmpty = remote.values.every((m) => m.isEmpty);
      // Local đi trước (có thay đổi chưa đẩy, hoặc lần đồng bộ đầu tiên) -> hợp nhất, local thắng.
      final merge = dirty || remoteEmpty;
      if (merge) await _push();

      final db = await _sqlite.readyDatabase;
      final before = jsonEncode(_snapshot(await _localRows(db)));
      await _apply(remote, replace: !merge);
      final localAfter = await _localRows(db);
      changed = before != jsonEncode(_snapshot(localAfter));
      _synced = _snapshot(localAfter);
      await prefs.setBool(dirtyKey, false);

      final g = await pullGroups();
      changed = changed || g.changed;
      status.value = g.error == null ? 'Đã đồng bộ lúc ${_now()}' : 'Lỗi đồng bộ nhóm: ${g.error}';
    } catch (e) {
      status.value = 'Lỗi đồng bộ: ${_describe(e)}';
    } finally {
      _busy = false;
    }
    return changed;
  }

  Future<Map<String, Map<String, Map<String, dynamic>>>> _fetchRemote() async {
    final result = <String, Map<String, Map<String, dynamic>>>{};
    for (final t in _tables) {
      final snap = await _fs.collection('users').doc(_uid).collection(t).get().timeout(_timeout);
      result[t] = {for (final d in snap.docs) d.id: Map<String, dynamic>.from(d.data())};
    }
    return result;
  }

  Future<Map<String, Map<String, Map<String, Object?>>>> _localRows(DatabaseExecutor db) async {
    final queries = <String, String>{
      'wallets': 'SELECT * FROM wallets WHERE user_id = ?',
      'budgets': 'SELECT * FROM budgets WHERE user_id = ?',
      'budget_items':
          'SELECT bi.* FROM budget_items bi JOIN budgets b ON b.id = bi.budget_id WHERE b.user_id = ?',
      'savings_goals': 'SELECT * FROM savings_goals WHERE user_id = ?',
      'goal_contributions':
          'SELECT c.* FROM goal_contributions c JOIN savings_goals g ON g.id = c.goal_id WHERE g.user_id = ?',
      'transactions': 'SELECT * FROM transactions WHERE user_id = ?',
      'debts': 'SELECT * FROM debts WHERE user_id = ?',
      'debt_payments':
          'SELECT p.* FROM debt_payments p JOIN debts d ON d.id = p.debt_id WHERE d.user_id = ?',
    };
    final result = <String, Map<String, Map<String, Object?>>>{};
    for (final t in _tables) {
      final rows = await db.rawQuery(queries[t]!, [_uid]);
      result[t] = {for (final r in rows) (r['id'] as String): Map<String, Object?>.from(r)};
    }
    return result;
  }

  String _json(Map<String, Object?> row) => jsonEncode(SplayTreeMap<String, Object?>.from(row));

  Map<String, Map<String, String>> _snapshot(Map<String, Map<String, Map<String, Object?>>> rows) {
    return {
      for (final t in _tables)
        t: SplayTreeMap<String, String>.from({
          for (final e in rows[t]!.entries) e.key: _json(e.value),
        }),
    };
  }

  /// Đẩy các dòng thay đổi / đã xóa lên Firestore (không chờ xác nhận để chạy được cả khi offline).
  Future<void> _push() async {
    final db = await _sqlite.readyDatabase;
    final rows = await _localRows(db);
    final next = <String, Map<String, String>>{};

    var batch = _fs.batch();
    var count = 0;
    void flush() {
      batch.commit().catchError(_onWriteError);
      batch = _fs.batch();
      count = 0;
    }

    for (final t in _tables) {
      final col = _fs.collection('users').doc(_uid).collection(t);
      final prev = _synced[t] ?? const <String, String>{};
      final cur = <String, String>{};
      for (final e in rows[t]!.entries) {
        final j = _json(e.value);
        cur[e.key] = j;
        if (prev[e.key] != j) {
          batch.set(col.doc(e.key), e.value);
          if (++count >= 400) flush();
        }
      }
      for (final id in prev.keys) {
        if (!cur.containsKey(id)) {
          batch.delete(col.doc(id));
          if (++count >= 400) flush();
        }
      }
      next[t] = cur;
    }
    if (count > 0) flush();
    _synced = next;
  }

  Future<void> _apply(
    Map<String, Map<String, Map<String, dynamic>>> remote, {
    required bool replace,
  }) async {
    final db = await _sqlite.readyDatabase;
    await db.transaction((txn) async {
      final local = await _localRows(txn);

      for (final t in _tables) {
        for (final entry in remote[t]!.entries) {
          final row = Map<String, Object?>.from(entry.value);
          final existing = local[t]![entry.key];
          if (existing != null) {
            if (!replace || _json(existing) == _json(row)) continue;
            final updated = Map<String, Object?>.from(row)..remove('id');
            await txn.update(t, updated, where: 'id = ?', whereArgs: [entry.key]);
          } else {
            await txn.insert(t, row, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }

      if (replace) {
        for (final t in _tables.reversed) {
          if (t == 'wallets') continue;
          for (final id in local[t]!.keys) {
            if (!remote[t]!.containsKey(id)) {
              await txn.delete(t, where: 'id = ?', whereArgs: [id]);
            }
          }
        }
      }
    });
  }

  // ================= SHARED GROUPS ================= //

  Future<String> _groupDigest(Database db) async {
    final buffer = StringBuffer();
    for (final t in const [
      'expense_groups',
      'group_members',
      'group_expenses',
      'group_expense_shares',
      'group_settlements',
    ]) {
      buffer.write(jsonEncode(await db.query(t, orderBy: 'id')));
    }
    return buffer.toString();
  }

  /// Tải các nhóm mà người dùng là thành viên về SQLite.
  Future<({String? error, bool changed})> pullGroups() async {
    if (!_active) return (error: null, changed: false);
    try {
      final db = await _sqlite.readyDatabase;
      final before = await _groupDigest(db);

      final qs = await _fs
          .collection('groups')
          .where('memberUids', arrayContains: _uid)
          .get()
          .timeout(_timeout);

      final remoteIds = <String>{};
      for (final doc in qs.docs) {
        remoteIds.add(doc.id);
        final expenses = await doc.reference.collection('expenses').get().timeout(_timeout);
        final settlements = await doc.reference.collection('settlements').get().timeout(_timeout);
        await _applyGroup(db, doc.id, doc.data(), expenses.docs, settlements.docs);
      }
      await _pushMissingGroups(db, remoteIds);

      final after = await _groupDigest(db);
      return (error: null, changed: before != after);
    } catch (e) {
      return (error: _describe(e), changed: false);
    }
  }

  Future<void> _ensureUser(DatabaseExecutor txn, String id, String? email, String? name) async {
    final existing = await txn.query('users', columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (existing.isNotEmpty) return;

    var mail = (email ?? '').trim().toLowerCase();
    if (mail.isEmpty) {
      mail = id.startsWith('contact_') ? '$id@contacts.smartspend.local' : '$id@remote.smartspend.local';
    } else {
      final dup = await txn.query('users', columns: ['id'], where: 'LOWER(email) = ?', whereArgs: [mail], limit: 1);
      if (dup.isNotEmpty) mail = '$id@remote.smartspend.local';
    }
    await txn.insert('users', {
      'id': id,
      'email': mail,
      'display_name': (name == null || name.trim().isEmpty) ? 'Thành viên' : name.trim(),
      'password_hash': '*',
    });
  }

  Future<void> _applyGroup(
    Database db,
    String gid,
    Map<String, dynamic> data,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> expenseDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> settlementDocs,
  ) async {
    final ownerUid = (data['ownerUid'] as String?) ?? _uid;
    final members = [
      for (final m in (data['members'] as List?) ?? const []) Map<String, dynamic>.from(m as Map),
    ];

    await db.transaction((txn) async {
      // Chủ nhóm + nhóm
      String? ownerName;
      String? ownerEmail;
      for (final m in members) {
        if (m['uid'] == ownerUid) {
          ownerName = m['name'] as String?;
          ownerEmail = m['email'] as String?;
        }
      }
      await _ensureUser(txn, ownerUid, ownerEmail, ownerName ?? 'Chủ nhóm');

      final groupName = (data['name'] as String?) ?? 'Nhóm';
      final g = await txn.query('expense_groups', columns: ['id'], where: 'id = ?', whereArgs: [gid], limit: 1);
      if (g.isEmpty) {
        await txn.insert('expense_groups', {'id': gid, 'owner_id': ownerUid, 'name': groupName});
      } else {
        await txn.update('expense_groups', {'name': groupName}, where: 'id = ?', whereArgs: [gid]);
      }

      // Thành viên
      for (final m in members) {
        final mid = m['id'] as String;
        final uid = m['uid'] as String?;
        final userId = (uid != null && uid.isNotEmpty) ? uid : 'contact_$mid';
        final name = (m['name'] as String?) ?? 'Thành viên';

        final byId = await txn.query('group_members', columns: ['id'], where: 'id = ?', whereArgs: [mid], limit: 1);
        if (byId.isNotEmpty) {
          if (userId != _uid) {
            await txn.update('group_members', {'display_name': name}, where: 'id = ?', whereArgs: [mid]);
          }
          continue;
        }
        final byUser = await txn.query(
          'group_members',
          columns: ['id'],
          where: 'group_id = ? AND user_id = ?',
          whereArgs: [gid, userId],
          limit: 1,
        );
        if (byUser.isNotEmpty) continue;

        await _ensureUser(txn, userId, m['email'] as String?, name);
        await txn.insert('group_members', {
          'id': mid,
          'group_id': gid,
          'user_id': userId,
          'display_name': name,
        });
      }

      // Khoản chi
      final remoteExpenseIds = <String>{};
      for (final d in expenseDocs) {
        final e = d.data();
        remoteExpenseIds.add(d.id);
        final row = {
          'group_id': gid,
          'paid_by_member_id': e['paidByMemberId'],
          'description': e['description'],
          'amount': (e['amount'] as num).toInt(),
          'occurred_on': e['occurredOn'],
        };
        final existing = await txn.query('group_expenses', columns: ['id'], where: 'id = ?', whereArgs: [d.id], limit: 1);
        if (existing.isEmpty) {
          await txn.insert('group_expenses', {'id': d.id, ...row});
        } else {
          await txn.update('group_expenses', row, where: 'id = ?', whereArgs: [d.id]);
        }
        await txn.delete('group_expense_shares', where: 'expense_id = ?', whereArgs: [d.id]);
        final shares = Map<String, dynamic>.from((e['shares'] as Map?) ?? const {});
        for (final s in shares.entries) {
          await txn.insert('group_expense_shares', {
            'id': 'ges_${d.id}_${s.key}',
            'expense_id': d.id,
            'member_id': s.key,
            'share_amount': (s.value as num).toInt(),
          });
        }
      }
      final localExpenses = await txn.query('group_expenses', columns: ['id'], where: 'group_id = ?', whereArgs: [gid]);
      for (final r in localExpenses) {
        final id = r['id'] as String;
        if (!remoteExpenseIds.contains(id)) {
          await txn.delete('group_expense_shares', where: 'expense_id = ?', whereArgs: [id]);
          await txn.delete('group_expenses', where: 'id = ?', whereArgs: [id]);
        }
      }

      // Thanh toán nội bộ
      final remoteSettlementIds = <String>{};
      for (final d in settlementDocs) {
        final s = d.data();
        remoteSettlementIds.add(d.id);
        final existing = await txn.query('group_settlements', columns: ['id'], where: 'id = ?', whereArgs: [d.id], limit: 1);
        if (existing.isEmpty) {
          await txn.insert('group_settlements', {
            'id': d.id,
            'group_id': gid,
            'from_member_id': s['fromMemberId'],
            'to_member_id': s['toMemberId'],
            'amount': (s['amount'] as num).toInt(),
            'occurred_on': s['occurredOn'],
          });
        }
      }
      final localSettlements = await txn.query('group_settlements', columns: ['id'], where: 'group_id = ?', whereArgs: [gid]);
      for (final r in localSettlements) {
        final id = r['id'] as String;
        if (!remoteSettlementIds.contains(id)) {
          await txn.delete('group_settlements', where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }

  /// Nhóm tạo trước khi bật đồng bộ (chỉ có ở local) -> đưa lên Firestore.
  Future<void> _pushMissingGroups(Database db, Set<String> remoteIds) async {
    final mine = await db.query('expense_groups', columns: ['id'], where: 'owner_id = ?', whereArgs: [_uid]);
    for (final r in mine) {
      final gid = r['id'] as String;
      if (remoteIds.contains(gid)) continue;
      await upsertGroup(gid, create: true);
      final expenses = await db.query('group_expenses', columns: ['id'], where: 'group_id = ?', whereArgs: [gid]);
      for (final e in expenses) {
        await upsertExpense(gid, e['id'] as String);
      }
      final settlements = await db.query('group_settlements', columns: ['id'], where: 'group_id = ?', whereArgs: [gid]);
      for (final s in settlements) {
        await upsertSettlement(gid, s['id'] as String);
      }
    }
  }

  Future<void> upsertGroup(String gid, {bool create = false}) async {
    if (!_active) return;
    try {
      final db = await _sqlite.readyDatabase;
      final g = await db.query('expense_groups', where: 'id = ?', whereArgs: [gid], limit: 1);
      if (g.isEmpty) return;
      final rows = await db.rawQuery('''
        SELECT m.id, m.user_id, m.display_name, u.email
        FROM group_members m JOIN users u ON u.id = m.user_id
        WHERE m.group_id = ? ORDER BY m.rowid
      ''', [gid]);

      final members = <Map<String, Object?>>[];
      final uids = <String>[];
      for (final r in rows) {
        final userId = r['user_id'] as String;
        final real = !userId.startsWith('contact_');
        final isMe = userId == _uid;
        var email = isMe ? _email : r['email'] as String?;
        if (email != null && email.endsWith('.smartspend.local')) email = null;
        members.add({
          'id': r['id'],
          'uid': real ? userId : null,
          'name': isMe ? _name : r['display_name'],
          'email': real ? email : null,
        });
        if (real) uids.add(userId);
      }

      final ref = _fs.collection('groups').doc(gid);
      if (create) {
        ref.set({
          'name': g.first['name'],
          'ownerUid': g.first['owner_id'],
          'memberUids': uids,
          'members': members,
          'createdAt': DateTime.now().toIso8601String(),
        }).catchError(_onWriteError);
      } else {
        ref.set({
          'name': g.first['name'],
          'members': members,
          'memberUids': FieldValue.arrayUnion(uids),
        }, SetOptions(merge: true)).catchError(_onWriteError);
      }
    } catch (e) {
      status.value = 'Lỗi đồng bộ nhóm: ${_describe(e)}';
    }
  }

  Future<void> upsertExpense(String gid, String expenseId) async {
    if (!_active) return;
    try {
      final db = await _sqlite.readyDatabase;
      final rows = await db.query('group_expenses', where: 'id = ?', whereArgs: [expenseId], limit: 1);
      if (rows.isEmpty) return;
      final shareRows = await db.query('group_expense_shares', where: 'expense_id = ?', whereArgs: [expenseId]);
      final e = rows.first;
      _fs.collection('groups').doc(gid).collection('expenses').doc(expenseId).set({
        'description': e['description'],
        'amount': e['amount'],
        'paidByMemberId': e['paid_by_member_id'],
        'occurredOn': e['occurred_on'],
        'shares': {for (final s in shareRows) (s['member_id'] as String): s['share_amount']},
        'createdBy': _uid,
      }).catchError(_onWriteError);
    } catch (e) {
      status.value = 'Lỗi đồng bộ nhóm: ${_describe(e)}';
    }
  }

  Future<void> deleteExpense(String gid, String expenseId) async {
    if (!_active) return;
    _fs.collection('groups').doc(gid).collection('expenses').doc(expenseId).delete().catchError(_onWriteError);
  }

  Future<void> upsertSettlement(String gid, String settlementId) async {
    if (!_active) return;
    try {
      final db = await _sqlite.readyDatabase;
      final rows = await db.query('group_settlements', where: 'id = ?', whereArgs: [settlementId], limit: 1);
      if (rows.isEmpty) return;
      final s = rows.first;
      _fs.collection('groups').doc(gid).collection('settlements').doc(settlementId).set({
        'fromMemberId': s['from_member_id'],
        'toMemberId': s['to_member_id'],
        'amount': s['amount'],
        'occurredOn': s['occurred_on'],
      }).catchError(_onWriteError);
    } catch (e) {
      status.value = 'Lỗi đồng bộ nhóm: ${_describe(e)}';
    }
  }

  /// Thêm người dùng SmartSpend khác (theo email) vào nhóm. Trả về tên người được thêm.
  Future<String> addUserToGroup(String gid, String rawEmail) async {
    if (!_active) {
      throw const SyncException('Cần đăng nhập bằng tài khoản Firebase (có mạng) để thêm người dùng vào nhóm.');
    }
    final email = rawEmail.trim().toLowerCase();
    if (email == _email) throw const SyncException('Đó là tài khoản của bạn.');

    QuerySnapshot<Map<String, dynamic>> qs;
    try {
      qs = await _fs
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
    } catch (e) {
      throw SyncException(_describe(e));
    }
    if (qs.docs.isEmpty) {
      throw const SyncException(
        'Không tìm thấy tài khoản SmartSpend với email này. Người đó cần đăng nhập app (có mạng) ít nhất một lần.',
      );
    }

    final doc = qs.docs.first;
    final theirUid = doc.id;
    final theirName = (doc.data()['displayName'] as String?)?.trim().isNotEmpty == true
        ? (doc.data()['displayName'] as String).trim()
        : email.split('@').first;

    final db = await _sqlite.readyDatabase;
    final dup = await db.query(
      'group_members',
      columns: ['id'],
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [gid, theirUid],
      limit: 1,
    );
    if (dup.isNotEmpty) throw SyncException('$theirName đã ở trong nhóm.');

    await db.transaction((txn) async {
      await _ensureUser(txn, theirUid, email, theirName);
      await txn.insert('group_members', {
        'id': 'gm_${DateTime.now().microsecondsSinceEpoch}',
        'group_id': gid,
        'user_id': theirUid,
        'display_name': theirName,
      });
    });
    await upsertGroup(gid);
    return theirName;
  }
}
