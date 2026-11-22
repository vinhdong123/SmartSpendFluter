import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'sqlite_database_service.dart';

/// Tự động đồng bộ dữ liệu SQLite của người dùng lên Cloud Firestore.
///
/// Cách hoạt động:
///  - SQLite vẫn là nguồn dữ liệu chính của app (chạy offline bình thường).
///  - Cứ vài giây service kiểm tra `total_changes()` của SQLite; nếu có thay đổi
///    (thêm/sửa/xóa ở bất kỳ bảng nào) thì đẩy bản chụp mới lên Firestore.
///  - Khi đăng nhập / mở app: nếu trên cloud có bản mới hơn bản đã đồng bộ gần nhất
///    của máy này (và máy không có thay đổi chưa đẩy) thì tải về và khôi phục.
///  - Chỉ đồng bộ với tài khoản Firebase thật. Tài khoản demo / local_ bị bỏ qua.
///
/// Dữ liệu trên Firestore:
///   users/{uid}/sync/_meta            -> { updatedAt, chunks: {bảng: số_chunk} }
///   users/{uid}/sync/{bảng}__{index}  -> { table, idx, rows: "<json>" }
class FirestoreSyncService with WidgetsBindingObserver {
  FirestoreSyncService._();
  static final FirestoreSyncService instance = FirestoreSyncService._();

  static const int _rowsPerChunk = 300;
  static const Duration _tick = Duration(seconds: 5);

  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  /// Thứ tự bảng thỏa khóa ngoại + điều kiện lọc theo người dùng (?1 = uid).
  static const List<(String, String)> _tables = [
    ('wallets', 'user_id = ?1'),
    ('budgets', 'user_id = ?1'),
    ('budget_items', 'budget_id IN (SELECT id FROM budgets WHERE user_id = ?1)'),
    ('transactions', 'user_id = ?1'),
    ('attachments', 'transaction_id IN (SELECT id FROM transactions WHERE user_id = ?1)'),
    ('notifications', 'user_id = ?1'),
    ('savings_goals', 'user_id = ?1'),
    ('goal_contributions', 'goal_id IN (SELECT id FROM savings_goals WHERE user_id = ?1)'),
    ('debts', 'user_id = ?1'),
    ('debt_payments', 'debt_id IN (SELECT id FROM debts WHERE user_id = ?1)'),
    ('expense_groups', 'owner_id = ?1'),
    ('group_members', 'group_id IN (SELECT id FROM expense_groups WHERE owner_id = ?1)'),
    ('group_expenses', 'group_id IN (SELECT id FROM expense_groups WHERE owner_id = ?1)'),
    ('group_expense_shares',
        'expense_id IN (SELECT id FROM group_expenses WHERE group_id IN '
            '(SELECT id FROM expense_groups WHERE owner_id = ?1))'),
    ('group_settlements', 'group_id IN (SELECT id FROM expense_groups WHERE owner_id = ?1)'),
  ];

  /// "Người liên hệ" (bảng users) được nhóm chi tiêu tham chiếu tới.
  static const String _contactsWhere =
      'id <> ?1 AND id IN (SELECT user_id FROM group_members WHERE group_id IN '
      '(SELECT id FROM expense_groups WHERE owner_id = ?1))';

  Timer? _timer;
  String? _uid;
  int _baseline = -1;
  bool _busy = false;
  bool _observing = false;

  // ---------------------------------------------------------------- helpers

  /// Trả về uid Firebase nếu app đang đăng nhập Firebase khớp với user SQLite.
  String? _syncableUid() {
    try {
      final fbUid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (fbUid == null || fbUid != _sqlite.uid) return null;
      return fbUid;
    } catch (_) {
      return null; // Firebase chưa khởi tạo
    }
  }

  DocumentReference<Map<String, dynamic>> _meta(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('sync').doc('_meta');

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('sync');

  Future<int> _totalChanges() async {
    final db = await _sqlite.readyDatabase;
    final r = await db.rawQuery('SELECT total_changes() AS c');
    return (r.first['c'] as num).toInt();
  }

  Future<int> _getInt(String key) async =>
      (await SharedPreferences.getInstance()).getInt(key) ?? 0;
  Future<void> _setInt(String key, int v) async =>
      (await SharedPreferences.getInstance()).setInt(key, v);
  Future<bool> _getBool(String key) async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;
  Future<void> _setBool(String key, bool v) async =>
      (await SharedPreferences.getInstance()).setBool(key, v);

  String _kLast(String uid) => 'sync_last_$uid';
  String _kDirty(String uid) => 'sync_dirty_$uid';

  // ------------------------------------------------------------- lifecycle

  /// Gọi khi vào màn hình chính (sau setCurrentUser).
  /// Trả về `true` nếu dữ liệu local vừa được thay bằng bản từ cloud
  /// (UI nên làm mới lại).
  Future<bool> start() async {
    stop();
    final uid = _syncableUid();
    if (uid == null) return false;
    _uid = uid;

    var restored = false;
    try {
      await _sqlite.readyDatabase;
      restored = await _pullIfNewer(uid);
    } catch (e) {
      debugPrint('Firestore pull error: $e');
    }

    _baseline = await _totalChanges();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _timer = Timer.periodic(_tick, (_) => _poll());
    // Nếu còn thay đổi chưa đẩy từ lần trước (offline) thì đẩy ngay.
    if (await _getBool(_kDirty(uid)) || await _getInt(_kLast(uid)) == 0) {
      unawaited(_push(uid));
    }
    return restored;
  }

  /// Gọi khi đăng xuất (đẩy nốt thay đổi rồi dừng).
  Future<void> stopAfterFlush() async {
    await flush();
    stop();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _uid = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(flush());
    }
  }

  /// Đẩy ngay nếu có thay đổi chưa đồng bộ.
  Future<void> flush() async {
    final uid = _uid;
    if (uid == null) return;
    await _markDirtyIfChanged(uid);
    if (await _getBool(_kDirty(uid))) await _push(uid);
  }

  // ------------------------------------------------------------------ push

  Future<void> _markDirtyIfChanged(String uid) async {
    final now = await _totalChanges();
    if (now != _baseline) await _setBool(_kDirty(uid), true);
  }

  Future<void> _poll() async {
    final uid = _uid;
    if (uid == null || _busy) return;
    try {
      await _markDirtyIfChanged(uid);
      if (await _getBool(_kDirty(uid))) await _push(uid);
    } catch (e) {
      debugPrint('Firestore sync poll error: $e');
    }
  }

  Future<void> _push(String uid) async {
    if (_busy) return;
    _busy = true;
    try {
      final db = await _sqlite.readyDatabase;
      final changesBefore = await _totalChanges();

      final writes = <String, Map<String, dynamic>>{};
      final chunkCounts = <String, int>{};

      Future<void> addTable(String table, String where) async {
        final rows = await db.rawQuery('SELECT * FROM $table WHERE $where', [uid]);
        final n = (rows.length / _rowsPerChunk).ceil();
        chunkCounts[table] = n;
        for (var i = 0; i < n; i++) {
          final part = rows.skip(i * _rowsPerChunk).take(_rowsPerChunk).toList();
          writes['${table}__$i'] = {'table': table, 'idx': i, 'rows': jsonEncode(part)};
        }
      }

      // Người liên hệ nằm trong bảng users nên lấy riêng.
      final contacts = await db.rawQuery(
        'SELECT id, email, display_name, created_at FROM users WHERE $_contactsWhere',
        [uid],
      );
      if (contacts.isNotEmpty) {
        chunkCounts['contacts'] = 1;
        writes['contacts__0'] = {'table': 'contacts', 'idx': 0, 'rows': jsonEncode(contacts)};
      }
      for (final t in _tables) {
        await addTable(t.$1, t.$2);
      }

      final col = _col(uid);
      final existing = await col.get();
      final staleIds = existing.docs
          .map((d) => d.id)
          .where((id) => id != '_meta' && !writes.containsKey(id))
          .toList();

      // Ghi theo lô (Firestore giới hạn 500 thao tác/lô).
      final ops = <void Function(WriteBatch)>[
        for (final e in writes.entries) (b) => b.set(col.doc(e.key), e.value),
        for (final id in staleIds) (b) => b.delete(col.doc(id)),
      ];
      for (var i = 0; i < ops.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final op in ops.skip(i).take(400)) {
          op(batch);
        }
        await batch.commit();
      }

      // Ghi meta SAU CÙNG: nó là "dấu hiệu hoàn tất" của bản chụp.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await _meta(uid).set({'updatedAt': stamp, 'chunks': chunkCounts});

      await _setInt(_kLast(uid), stamp);
      await _setBool(_kDirty(uid), false);
      _baseline = changesBefore; // nếu có thay đổi trong lúc đẩy, tick sau sẽ phát hiện
    } catch (e) {
      debugPrint('Firestore push error (sẽ thử lại): $e');
    } finally {
      _busy = false;
    }
  }

  // ------------------------------------------------------------------ pull

  /// Nếu cloud mới hơn và máy không có thay đổi chưa đẩy -> khôi phục từ cloud.
  Future<bool> _pullIfNewer(String uid) async {
    final metaSnap = await _meta(uid).get();
    if (!metaSnap.exists) return false; // chưa có gì trên cloud
    final meta = metaSnap.data()!;
    final cloudStamp = (meta['updatedAt'] as num).toInt();

    final lastLocal = await _getInt(_kLast(uid));
    final dirty = await _getBool(_kDirty(uid));
    if (cloudStamp <= lastLocal || dirty) return false; // local mới hơn hoặc có sửa đổi offline

    final chunks = Map<String, dynamic>.from(meta['chunks'] as Map);
    final snap = await _col(uid).get();
    final byTable = <String, List<Map<String, dynamic>>>{};
    final seen = <String, int>{};
    for (final d in snap.docs) {
      if (d.id == '_meta') continue;
      final data = d.data();
      final table = data['table'] as String;
      final rows = (jsonDecode(data['rows'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      (byTable[table] ??= []).addAll(rows);
      seen[table] = (seen[table] ?? 0) + 1;
    }
    // Bản chụp phải đủ chunk, nếu không thì bỏ qua (tránh khôi phục dở dang).
    for (final e in chunks.entries) {
      if ((seen[e.key] ?? 0) != (e.value as num).toInt()) return false;
    }

    await _restore(uid, byTable);
    await _setInt(_kLast(uid), cloudStamp);
    await _setBool(_kDirty(uid), false);
    return true;
  }

  Future<void> _restore(String uid, Map<String, List<Map<String, dynamic>>> data) async {
    final db = await _sqlite.readyDatabase;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        // Xóa dữ liệu hiện tại của user theo thứ tự ngược.
        final oldContacts = await txn.rawQuery(
          'SELECT id FROM users WHERE $_contactsWhere',
          [uid],
        );
        for (final t in _tables.reversed) {
          await txn.rawDelete('DELETE FROM ${t.$1} WHERE ${t.$2}', [uid]);
        }
        for (final c in oldContacts) {
          await txn.delete('users', where: 'id = ?', whereArgs: [c['id']]);
        }

        // Nạp dữ liệu từ cloud.
        for (final c in data['contacts'] ?? const <Map<String, dynamic>>[]) {
          await txn.insert(
            'users',
            {
              'id': c['id'],
              'email': c['email'],
              'display_name': c['display_name'],
              'password_hash': '*',
              if (c['created_at'] != null) 'created_at': c['created_at'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final t in _tables) {
          for (final row in data[t.$1] ?? const <Map<String, dynamic>>[]) {
            await txn.insert(t.$1, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }
}
