import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../core/constants/categories.dart';
import '../core/utils/formatters.dart';
import 'sync_service.dart';

class SQLiteDatabaseService {
  SQLiteDatabaseService._();
  static final SQLiteDatabaseService instance = SQLiteDatabaseService._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_spend.db');

    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Clear & recreate schema on version upgrade
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
        );
        for (final table in tables) {
          final tableName = table['name'] as String;
          await db.execute('DROP TABLE IF EXISTS "$tableName";');
        }
        await _onCreate(db, newVersion);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. USERS
    await db.execute('''
      CREATE TABLE users (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        email TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(email)) > 0),
        display_name TEXT NOT NULL CHECK (length(trim(display_name)) > 0),
        password_hash TEXT NOT NULL CHECK (length(password_hash) > 0),
        timezone TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh'
            CHECK (length(trim(timezone)) > 0),
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      );
    ''');

    // 2. WALLETS
    await db.execute('''
      CREATE TABLE wallets (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        type TEXT NOT NULL CHECK (length(trim(type)) > 0),
        initial_balance INTEGER NOT NULL DEFAULT 0
            CHECK (typeof(initial_balance) = 'integer'),
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        UNIQUE (id, user_id)
      );
    ''');

    // 3. BUDGETS
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        month_start TEXT NOT NULL CHECK (
            length(month_start) = 10
            AND date(month_start, '+0 days') IS month_start
            AND substr(month_start, 9, 2) = '01'
        ),
        total_limit INTEGER NOT NULL CHECK (
            typeof(total_limit) = 'integer' AND total_limit >= 0
        ),
        alert_threshold_pct INTEGER NOT NULL DEFAULT 80 CHECK (
            typeof(alert_threshold_pct) = 'integer'
            AND alert_threshold_pct BETWEEN 0 AND 100
        ),
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        UNIQUE (user_id, month_start)
      );
    ''');

    // 4. BUDGET ITEMS
    await db.execute('''
      CREATE TABLE budget_items (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        budget_id TEXT NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
        category_code TEXT NOT NULL CHECK (length(trim(category_code)) > 0),
        limit_amount INTEGER NOT NULL CHECK (
            typeof(limit_amount) = 'integer' AND limit_amount >= 0
        ),
        alert_threshold_pct INTEGER NOT NULL DEFAULT 80 CHECK (
            typeof(alert_threshold_pct) = 'integer'
            AND alert_threshold_pct BETWEEN 0 AND 100
        ),
        UNIQUE (budget_id, category_code)
      );
    ''');

    // 5. TRANSACTIONS
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        wallet_id TEXT NOT NULL,
        to_wallet_id TEXT,
        category_code TEXT CHECK (
            category_code IS NULL OR length(trim(category_code)) > 0
        ),
        type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
        kind TEXT NOT NULL CHECK (length(trim(kind)) > 0),
        amount INTEGER NOT NULL CHECK (typeof(amount) = 'integer' AND amount > 0),
        occurred_on TEXT NOT NULL CHECK (
            length(occurred_on) = 10 AND date(occurred_on, '+0 days') IS occurred_on
        ),
        note TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        UNIQUE (id, user_id),
        FOREIGN KEY (wallet_id, user_id)
            REFERENCES wallets(id, user_id) ON DELETE RESTRICT,
        FOREIGN KEY (to_wallet_id, user_id)
            REFERENCES wallets(id, user_id) ON DELETE RESTRICT,
        CHECK (
            (type = 'transfer' AND to_wallet_id IS NOT NULL
                AND to_wallet_id <> wallet_id AND category_code IS NULL)
            OR (type IN ('income', 'expense') AND to_wallet_id IS NULL)
        )
      );
    ''');

    // 6. NOTIFICATIONS
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        type TEXT NOT NULL CHECK (length(trim(type)) > 0),
        title TEXT NOT NULL CHECK (length(trim(title)) > 0),
        body TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        read_at TEXT
      );
    ''');

    // 7. ATTACHMENTS
    await db.execute('''
      CREATE TABLE attachments (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        transaction_id TEXT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
        file_uri TEXT NOT NULL CHECK (length(trim(file_uri)) > 0),
        mime_type TEXT NOT NULL CHECK (length(trim(mime_type)) > 0),
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      );
    ''');

    // 8. SAVINGS GOALS
    await db.execute('''
      CREATE TABLE savings_goals (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        target_amount INTEGER NOT NULL CHECK (
            typeof(target_amount) = 'integer' AND target_amount > 0
        ),
        deadline TEXT CHECK (
            deadline IS NULL OR (
                length(deadline) = 10 AND date(deadline, '+0 days') IS deadline
            )
        ),
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      );
    ''');

    // 9. GOAL CONTRIBUTIONS
    await db.execute('''
      CREATE TABLE goal_contributions (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        goal_id TEXT NOT NULL REFERENCES savings_goals(id) ON DELETE RESTRICT,
        wallet_id TEXT NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
        direction TEXT NOT NULL CHECK (direction IN ('allocate', 'release')),
        amount INTEGER NOT NULL CHECK (typeof(amount) = 'integer' AND amount > 0),
        occurred_on TEXT NOT NULL CHECK (
            length(occurred_on) = 10 AND date(occurred_on, '+0 days') IS occurred_on
        ),
        note TEXT
      );
    ''');

    // 10. DEBTS
    await db.execute('''
      CREATE TABLE debts (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        counterparty_name TEXT NOT NULL CHECK (length(trim(counterparty_name)) > 0),
        direction TEXT NOT NULL CHECK (direction IN ('borrowed', 'lent')),
        principal_amount INTEGER NOT NULL CHECK (
            typeof(principal_amount) = 'integer' AND principal_amount > 0
        ),
        opening_transaction_id TEXT UNIQUE,
        opened_on TEXT NOT NULL CHECK (
            length(opened_on) = 10 AND date(opened_on, '+0 days') IS opened_on
        ),
        due_on TEXT CHECK (
            due_on IS NULL OR (
                length(due_on) = 10 AND date(due_on, '+0 days') IS due_on
                AND due_on >= opened_on
            )
        ),
        note TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
        FOREIGN KEY (opening_transaction_id, user_id)
            REFERENCES transactions(id, user_id) ON DELETE RESTRICT
      );
    ''');

    // 11. DEBT PAYMENTS
    await db.execute('''
      CREATE TABLE debt_payments (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        debt_id TEXT NOT NULL REFERENCES debts(id) ON DELETE RESTRICT,
        transaction_id TEXT NOT NULL UNIQUE
            REFERENCES transactions(id) ON DELETE RESTRICT
      );
    ''');

    // 12. EXPENSE GROUPS
    await db.execute('''
      CREATE TABLE expense_groups (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      );
    ''');

    // 13. GROUP MEMBERS
    await db.execute('''
      CREATE TABLE group_members (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        group_id TEXT NOT NULL REFERENCES expense_groups(id) ON DELETE RESTRICT,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        display_name TEXT NOT NULL CHECK (length(trim(display_name)) > 0),
        joined_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        left_at TEXT,
        UNIQUE (group_id, user_id),
        UNIQUE (id, group_id)
      );
    ''');

    // 14. GROUP EXPENSES
    await db.execute('''
      CREATE TABLE group_expenses (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        group_id TEXT NOT NULL REFERENCES expense_groups(id) ON DELETE RESTRICT,
        paid_by_member_id TEXT NOT NULL,
        description TEXT NOT NULL CHECK (length(trim(description)) > 0),
        amount INTEGER NOT NULL CHECK (typeof(amount) = 'integer' AND amount > 0),
        occurred_on TEXT NOT NULL CHECK (
            length(occurred_on) = 10 AND date(occurred_on, '+0 days') IS occurred_on
        ),
        FOREIGN KEY (paid_by_member_id, group_id)
            REFERENCES group_members(id, group_id) ON DELETE RESTRICT
      );
    ''');

    // 15. GROUP EXPENSE SHARES
    await db.execute('''
      CREATE TABLE group_expense_shares (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        expense_id TEXT NOT NULL REFERENCES group_expenses(id) ON DELETE CASCADE,
        member_id TEXT NOT NULL REFERENCES group_members(id) ON DELETE RESTRICT,
        share_amount INTEGER NOT NULL CHECK (
            typeof(share_amount) = 'integer' AND share_amount >= 0
        ),
        UNIQUE (expense_id, member_id)
      );
    ''');

    // 16. GROUP SETTLEMENTS
    await db.execute('''
      CREATE TABLE group_settlements (
        id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
        group_id TEXT NOT NULL REFERENCES expense_groups(id) ON DELETE RESTRICT,
        from_member_id TEXT NOT NULL,
        to_member_id TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (typeof(amount) = 'integer' AND amount > 0),
        occurred_on TEXT NOT NULL CHECK (
            length(occurred_on) = 10 AND date(occurred_on, '+0 days') IS occurred_on
        ),
        FOREIGN KEY (from_member_id, group_id)
            REFERENCES group_members(id, group_id) ON DELETE RESTRICT,
        FOREIGN KEY (to_member_id, group_id)
            REFERENCES group_members(id, group_id) ON DELETE RESTRICT,
        CHECK (from_member_id <> to_member_id)
      );
    ''');

    // ================= TRIGGERS ================= //

    await db.execute('''
      CREATE TRIGGER goal_contributions_owner_insert
      BEFORE INSERT ON goal_contributions
      WHEN NOT EXISTS (
          SELECT 1 FROM savings_goals g JOIN wallets w ON w.user_id = g.user_id
          WHERE g.id = NEW.goal_id AND w.id = NEW.wallet_id
      )
      BEGIN
          SELECT RAISE(ABORT, 'Goal and wallet must belong to the same user');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER goal_contributions_owner_update
      BEFORE UPDATE OF goal_id, wallet_id ON goal_contributions
      WHEN NOT EXISTS (
          SELECT 1 FROM savings_goals g JOIN wallets w ON w.user_id = g.user_id
          WHERE g.id = NEW.goal_id AND w.id = NEW.wallet_id
      )
      BEGIN
          SELECT RAISE(ABORT, 'Goal and wallet must belong to the same user');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER debt_payments_owner_insert
      BEFORE INSERT ON debt_payments
      WHEN NOT EXISTS (
          SELECT 1 FROM debts d JOIN transactions t ON t.user_id = d.user_id
          WHERE d.id = NEW.debt_id AND t.id = NEW.transaction_id
      )
      BEGIN
          SELECT RAISE(ABORT, 'Debt and transaction must belong to the same user');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER debt_payments_owner_update
      BEFORE UPDATE OF debt_id, transaction_id ON debt_payments
      WHEN NOT EXISTS (
          SELECT 1 FROM debts d JOIN transactions t ON t.user_id = d.user_id
          WHERE d.id = NEW.debt_id AND t.id = NEW.transaction_id
      )
      BEGIN
          SELECT RAISE(ABORT, 'Debt and transaction must belong to the same user');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER group_expense_shares_group_insert
      BEFORE INSERT ON group_expense_shares
      WHEN NOT EXISTS (
          SELECT 1 FROM group_expenses e JOIN group_members m ON m.group_id = e.group_id
          WHERE e.id = NEW.expense_id AND m.id = NEW.member_id
      )
      BEGIN
          SELECT RAISE(ABORT, 'Expense and member must belong to the same group');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER group_expense_shares_group_update
      BEFORE UPDATE OF expense_id, member_id ON group_expense_shares
      WHEN NOT EXISTS (
          SELECT 1 FROM group_expenses e JOIN group_members m ON m.group_id = e.group_id
          WHERE e.id = NEW.expense_id AND m.id = NEW.member_id
      )
      BEGIN
          SELECT RAISE(ABORT, 'Expense and member must belong to the same group');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER wallets_owner_immutable
      BEFORE UPDATE OF user_id ON wallets WHEN NEW.user_id IS NOT OLD.user_id
      BEGIN
          SELECT RAISE(ABORT, 'Wallet ownership cannot be changed');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER transactions_owner_immutable
      BEFORE UPDATE OF user_id ON transactions WHEN NEW.user_id IS NOT OLD.user_id
      BEGIN
          SELECT RAISE(ABORT, 'Transaction ownership cannot be changed');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER savings_goals_owner_immutable
      BEFORE UPDATE OF user_id ON savings_goals WHEN NEW.user_id IS NOT OLD.user_id
      BEGIN
          SELECT RAISE(ABORT, 'Goal ownership cannot be changed');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER debts_owner_immutable
      BEFORE UPDATE OF user_id ON debts WHEN NEW.user_id IS NOT OLD.user_id
      BEGIN
          SELECT RAISE(ABORT, 'Debt ownership cannot be changed');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER group_members_group_immutable
      BEFORE UPDATE OF group_id ON group_members WHEN NEW.group_id IS NOT OLD.group_id
      BEGIN
          SELECT RAISE(ABORT, 'Move a member by creating a new membership');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER group_expenses_group_immutable
      BEFORE UPDATE OF group_id ON group_expenses WHEN NEW.group_id IS NOT OLD.group_id
      BEGIN
          SELECT RAISE(ABORT, 'An expense cannot be moved to another group');
      END;
    ''');

    // ================= INDEXES ================= //

    await db.execute('CREATE INDEX idx_wallets_user ON wallets(user_id, is_archived);');
    await db.execute('CREATE INDEX idx_transactions_user_date ON transactions(user_id, occurred_on);');
    await db.execute('CREATE INDEX idx_transactions_wallet_date ON transactions(wallet_id, occurred_on);');
    await db.execute('CREATE INDEX idx_transactions_to_wallet_date ON transactions(to_wallet_id, occurred_on);');
    await db.execute('CREATE INDEX idx_notifications_user_read ON notifications(user_id, read_at, created_at);');
    await db.execute('CREATE INDEX idx_attachments_transaction ON attachments(transaction_id);');
    await db.execute('CREATE INDEX idx_savings_goals_user ON savings_goals(user_id, is_archived);');
    await db.execute('CREATE INDEX idx_goal_contributions_goal ON goal_contributions(goal_id, occurred_on);');
    await db.execute('CREATE INDEX idx_goal_contributions_wallet ON goal_contributions(wallet_id);');
    await db.execute('CREATE INDEX idx_debts_user ON debts(user_id, is_archived);');
    await db.execute('CREATE INDEX idx_debt_payments_debt ON debt_payments(debt_id);');
    await db.execute('CREATE INDEX idx_expense_groups_owner ON expense_groups(owner_id);');
    await db.execute('CREATE INDEX idx_group_members_user ON group_members(user_id);');
    await db.execute('CREATE INDEX idx_group_expenses_group ON group_expenses(group_id, occurred_on);');
    await db.execute('CREATE INDEX idx_group_expenses_payer ON group_expenses(paid_by_member_id);');
    await db.execute('CREATE INDEX idx_group_expense_shares_member ON group_expense_shares(member_id);');
    await db.execute('CREATE INDEX idx_group_settlements_group ON group_settlements(group_id, occurred_on);');
    await db.execute('CREATE INDEX idx_group_settlements_from ON group_settlements(from_member_id);');
    await db.execute('CREATE INDEX idx_group_settlements_to ON group_settlements(to_member_id);');

    // Seed default system user & default wallet to satisfy foreign key constraints
    await db.execute('''
      INSERT OR IGNORE INTO users (id, email, display_name, password_hash)
      VALUES ('default_user', 'user@smartspend.vn', 'Người dùng', '123456');
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO wallets (id, user_id, name, type, initial_balance)
      VALUES ('default_wallet', 'default_user', 'Ví Tiền mặt', 'cash', 0);
    ''');
  }

  // ================= CURRENT USER ================= //

  String _uid = 'default_user';
  Future<void> _ready = Future<void>.value();

  /// Id người dùng đang đăng nhập (mọi truy vấn đều lọc theo id này).
  String get uid => _uid;
  bool get isDemoUser => _uid == 'demo_user_id';

  /// Database đã được seed đầy đủ user + ví của người dùng hiện tại.
  Future<Database> get readyDatabase async {
    await _ready;
    return database;
  }

  /// Gọi ngay sau khi đăng nhập / khôi phục phiên.
  void setCurrentUser(UserModel user) {
    final id = user.uid.trim().isEmpty ? 'default_user' : user.uid.trim();
    _uid = id;
    final seeded = _seedUser(user, id).catchError((Object _) {});
    _ready = seeded;
    seeded.then((_) => SyncService.instance.start(user));
  }

  Future<void> _seedUser(UserModel user, String id) async {
    final db = await database;

    final existing = await db.query('users', columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (existing.isEmpty) {
      final name = user.fullName.trim().isEmpty ? 'User' : user.fullName.trim();
      final email = user.email.trim().isEmpty ? '$id@smartspend.local' : user.email.trim().toLowerCase();
      try {
        await db.insert('users', {
          'id': id,
          'email': email,
          'display_name': name,
          'password_hash': '*',
        });
      } catch (_) {
        // Email đã thuộc về tài khoản local khác -> dùng email nội bộ.
        await db.insert('users', {
          'id': id,
          'email': '$id@smartspend.local',
          'display_name': name,
          'password_hash': '*',
        });
      }
    }

    final isDemo = id == 'demo_user_id';
    final defaults = <(String, String, String, int)>[
      ('w_${id}_cash', 'Tiền mặt', 'cash', 0),
      ('w_${id}_momo', 'Ví MoMo', 'ewallet', 0),
      ('w_${id}_bank', 'Ngân hàng', 'bank', isDemo ? 12450000 : 0),
    ];
    for (final w in defaults) {
      await db.insert(
        'wallets',
        {'id': w.$1, 'user_id': id, 'name': w.$2, 'type': w.$3, 'initial_balance': w.$4},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ================= USERS ================= //

  /// Insert user
  Future<void> insertUser(UserModel user, String password) async {
    final db = await database;
    final validId = user.uid.trim().isEmpty ? 'user_${DateTime.now().millisecondsSinceEpoch}' : user.uid.trim();
    final validEmail = user.email.trim().isEmpty ? '$validId@smartspend.vn' : user.email.trim().toLowerCase();
    final validName = user.fullName.trim().isEmpty ? 'User' : user.fullName.trim();

    await db.insert(
      'users',
      {
        'id': validId,
        'display_name': validName,
        'email': validEmail,
        'password_hash': password.isEmpty ? '123456' : password,
        'created_at': user.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Ví mặc định được tạo trong setCurrentUser() ngay sau khi đăng nhập.
  }

  /// Get user by email & password
  Future<UserModel?> getUserByEmailAndPassword(String email, String password) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'LOWER(email) = ? AND password_hash = ?',
      whereArgs: [email.trim().toLowerCase(), password],
    );

    if (maps.isNotEmpty) {
      final row = maps.first;
      return UserModel(
        uid: row['id'] as String,
        fullName: row['display_name'] as String,
        email: row['email'] as String,
        createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      );
    }
    return null;
  }

  /// Check if user exists
  Future<bool> isUserExists(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    return maps.isNotEmpty;
  }

  // ================= TRANSACTIONS ================= //

  Future<String> resolveWalletId(String name) async {
    final db = await readyDatabase;
    return _walletIdByName(db, name);
  }

  Future<String> _walletIdByName(DatabaseExecutor db, String name) async {
    final rows = await db.query(
      'wallets',
      columns: ['id'],
      where: 'user_id = ? AND name = ? AND is_archived = 0',
      whereArgs: [_uid, name],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;

    final any = await db.query(
      'wallets',
      columns: ['id'],
      where: 'user_id = ? AND is_archived = 0',
      whereArgs: [_uid],
      orderBy: 'rowid',
      limit: 1,
    );
    if (any.isNotEmpty) return any.first['id'] as String;
    throw StateError('Chưa có ví nào. Hãy tạo ví trước khi thêm giao dịch.');
  }

  Map<String, Object?> _transactionRow(TransactionModel t, String walletId) {
    final amountInt = t.amount.round().abs();
    final category = t.category.trim().isEmpty ? 'Khác' : t.category.trim();
    final note = (t.note ?? '').trim();
    return {
      'id': t.id.trim().isEmpty ? 'tx_${DateTime.now().microsecondsSinceEpoch}' : t.id.trim(),
      'user_id': _uid,
      'wallet_id': walletId,
      'category_code': Categories.codeOf(category),
      'type': t.isExpense ? 'expense' : 'income',
      'kind': category,
      'amount': amountInt <= 0 ? 1 : amountInt,
      'occurred_on': dbDate(t.date),
      'note': note.isEmpty ? t.title : note,
      'created_at': t.date.toIso8601String(),
    };
  }

  /// Insert transaction into SQLite
  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await readyDatabase;
    final walletId = await _walletIdByName(db, transaction.wallet);
    await db.insert(
      'transactions',
      _transactionRow(transaction, walletId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await readyDatabase;
    final walletId = await _walletIdByName(db, transaction.wallet);
    final row = _transactionRow(transaction, walletId)
      ..remove('id')
      ..remove('user_id');
    await db.update(
      'transactions',
      row,
      where: 'id = ? AND user_id = ?',
      whereArgs: [transaction.id, _uid],
    );
  }

  TransactionModel transactionFromRow(Map<String, Object?> map) {
    final kind = (map['kind'] as String?) ?? 'Khác';
    final note = map['note'] as String?;
    final day = DateTime.tryParse((map['occurred_on'] as String?) ?? '') ?? DateTime.now();
    var date = day;
    final created = DateTime.tryParse((map['created_at'] as String?) ?? '')?.toLocal();
    if (created != null && isSameDay(created, day)) {
      date = created;
    }
    return TransactionModel(
      id: map['id'] as String,
      title: note != null && note.isNotEmpty ? note : kind,
      amount: (map['amount'] as num).toDouble(),
      isExpense: (map['type'] as String?) == 'expense',
      category: kind,
      wallet: (map['wallet_name'] as String?) ?? 'Ví',
      date: date,
      note: note,
    );
  }

  /// Giao dịch thu/chi của người dùng hiện tại (mới nhất trước).
  Future<List<TransactionModel>> getAllTransactions({
    DateTime? from,
    DateTime? toExclusive,
    int? limit,
  }) async {
    final db = await readyDatabase;
    final where = StringBuffer("t.user_id = ? AND t.type IN ('income','expense')");
    final args = <Object?>[_uid];
    if (from != null) {
      where.write(' AND t.occurred_on >= ?');
      args.add(dbDate(from));
    }
    if (toExclusive != null) {
      where.write(' AND t.occurred_on < ?');
      args.add(dbDate(toExclusive));
    }
    final rows = await db.rawQuery('''
      SELECT t.id, t.type, t.kind, t.amount, t.occurred_on, t.note, t.created_at,
             w.name AS wallet_name
      FROM transactions t
      LEFT JOIN wallets w ON w.id = t.wallet_id AND w.user_id = t.user_id
      WHERE $where
      ORDER BY t.occurred_on DESC, t.created_at DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', args);
    return rows.map(transactionFromRow).toList();
  }

  /// Delete transaction by ID (đồng thời gỡ liên kết với khoản nợ nếu có)
  Future<void> deleteTransaction(String id) async {
    final db = await readyDatabase;
    await db.transaction((txn) async {
      await txn.delete('debt_payments', where: 'transaction_id = ?', whereArgs: [id]);
      await txn.update(
        'debts',
        {'opening_transaction_id': null},
        where: 'opening_transaction_id = ? AND user_id = ?',
        whereArgs: [id, _uid],
      );
      await txn.delete('transactions', where: 'id = ? AND user_id = ?', whereArgs: [id, _uid]);
    });
  }

  /// Tổng thu / chi trong khoảng [from, toExclusive)
  Future<({int income, int expense})> getPeriodTotals(DateTime from, DateTime toExclusive) async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT type, COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE user_id = ? AND type IN ('income','expense')
        AND occurred_on >= ? AND occurred_on < ?
      GROUP BY type
    ''', [_uid, dbDate(from), dbDate(toExclusive)]);
    var income = 0;
    var expense = 0;
    for (final r in rows) {
      final total = (r['total'] as num).toInt();
      if (r['type'] == 'income') {
        income = total;
      } else {
        expense = total;
      }
    }
    return (income: income, expense: expense);
  }
}
