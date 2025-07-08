// lib/services/database_helper.dart

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Completer<Database>? _databaseCompleter;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Use a Completer to prevent multiple initialization attempts
    if (_databaseCompleter == null) {
      _databaseCompleter = Completer<Database>();
      try {
        _database = await _initDatabase();
        _databaseCompleter!.complete(_database);
      } catch (e) {
        _databaseCompleter!.completeError(e);
        rethrow;
      }
    }

    return _databaseCompleter!.future;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'attendance_app.db');

    print('Initializing database at $path');

    // Open/create the database
    return await openDatabase(
      path,
      version: 5, // ← Updated version for leave management features
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    print('Creating database tables for version $version');

    // Attendance table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS attendance(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      employee_id TEXT NOT NULL,
      date TEXT NOT NULL,
      check_in TEXT,
      check_out TEXT,
      location_id TEXT,
      is_synced INTEGER DEFAULT 0,
      sync_error TEXT,
      raw_data TEXT
    )
    ''');

    // Employees table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS employees(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      designation TEXT,
      department TEXT,
      image TEXT,
      face_data TEXT,
      last_updated INTEGER
    )
    ''');

    // Locations table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS locations(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      radius REAL NOT NULL,
      is_active INTEGER DEFAULT 1,
      last_updated INTEGER
    )
    ''');

    // Polygon locations table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS polygon_locations(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      coordinates TEXT NOT NULL,
      is_active INTEGER DEFAULT 1,
      center_latitude REAL NOT NULL,
      center_longitude REAL NOT NULL,
      last_updated INTEGER
    )
    ''');

    // Overtime requests table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS overtime_requests(
      id TEXT PRIMARY KEY,
      project_name TEXT NOT NULL,
      project_code TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      requester_id TEXT NOT NULL,
      approver_id TEXT NOT NULL,
      status TEXT NOT NULL,
      request_time TEXT NOT NULL,
      response_message TEXT,
      response_time TEXT,
      is_synced INTEGER DEFAULT 0,
      employee_ids TEXT NOT NULL,
      sync_error TEXT,
      last_updated INTEGER
    )
    ''');

    // ✅ ENHANCED Leave applications table with all required fields
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS leave_applications(
      id TEXT PRIMARY KEY,
      employee_id TEXT NOT NULL,
      employee_name TEXT NOT NULL,
      employee_pin TEXT NOT NULL,
      leave_type TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL,
      total_days INTEGER NOT NULL,
      reason TEXT NOT NULL,
      is_already_taken INTEGER DEFAULT 0,
      certificate_url TEXT,
      certificate_file_name TEXT,
      status TEXT DEFAULT 'pending',
      application_date TEXT NOT NULL,
      line_manager_id TEXT NOT NULL,
      line_manager_name TEXT NOT NULL,
      review_date TEXT,
      review_comments TEXT,
      reviewed_by TEXT,
      is_active INTEGER DEFAULT 1,
      is_synced INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT,
      INDEX idx_employee_id (employee_id),
      INDEX idx_manager_id (line_manager_id),
      INDEX idx_status (status),
      INDEX idx_leave_type (leave_type)
    )
    ''');

    // ✅ ENHANCED Leave balances table with proper structure
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS leave_balances(
      id TEXT PRIMARY KEY,
      employee_id TEXT NOT NULL,
      year INTEGER NOT NULL,
      total_days TEXT NOT NULL,
      used_days TEXT NOT NULL,
      pending_days TEXT NOT NULL,
      last_updated TEXT,
      is_synced INTEGER DEFAULT 1,
      UNIQUE(employee_id, year),
      INDEX idx_employee_year (employee_id, year)
    )
    ''');

    print('Database tables created successfully');
  }

  Future<void> _createTableIfNotExists(Database db, String sql) async {
    try {
      await db.execute(sql);
      print('SQL executed successfully: ${sql.substring(0, sql.indexOf('('))}');
    } catch (e) {
      print('Table operation error: $e');
      // Table might already exist, which is fine
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from $oldVersion to $newVersion');

    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add new overtime_requests table if upgrading from version 1
      await _createTableIfNotExists(db, '''
      CREATE TABLE IF NOT EXISTS overtime_requests(
        id TEXT PRIMARY KEY,
        project_name TEXT NOT NULL,
        project_code TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        requester_id TEXT NOT NULL,
        approver_id TEXT NOT NULL,
        status TEXT NOT NULL,
        request_time TEXT NOT NULL,
        response_message TEXT,
        response_time TEXT,
        is_synced INTEGER DEFAULT 0,
        employee_ids TEXT NOT NULL,
        sync_error TEXT,
        last_updated INTEGER
      )
      ''');
    }

    if (oldVersion < 4) {
      // Force recreate leave tables with basic structure
      await db.execute('DROP TABLE IF EXISTS leave_applications');
      await db.execute('DROP TABLE IF EXISTS leave_balances');

      // Recreate with correct schema
      await _createTableIfNotExists(db, '''
      CREATE TABLE IF NOT EXISTS leave_applications(
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        employee_pin TEXT NOT NULL,
        leave_type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        total_days INTEGER NOT NULL,
        reason TEXT NOT NULL,
        is_already_taken INTEGER DEFAULT 0,
        certificate_url TEXT,
        certificate_file_name TEXT,
        status TEXT DEFAULT 'pending',
        application_date TEXT NOT NULL,
        line_manager_id TEXT NOT NULL,
        line_manager_name TEXT NOT NULL,
        review_date TEXT,
        review_comments TEXT,
        reviewed_by TEXT,
        is_active INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
      ''');

      await _createTableIfNotExists(db, '''
      CREATE TABLE IF NOT EXISTS leave_balances(
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        total_days TEXT NOT NULL,
        used_days TEXT NOT NULL,
        pending_days TEXT NOT NULL,
        last_updated TEXT,
        is_synced INTEGER DEFAULT 1
      )
      ''');
    }

    if (oldVersion < 5) {
      // ✅ ENHANCED: Add indexes and constraints for better performance
      try {
        // Add indexes for leave_applications if they don't exist
        await db.execute('CREATE INDEX IF NOT EXISTS idx_employee_id ON leave_applications(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_manager_id ON leave_applications(line_manager_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_status ON leave_applications(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_type ON leave_applications(leave_type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_application_date ON leave_applications(application_date)');

        // Add indexes for leave_balances
        await db.execute('CREATE INDEX IF NOT EXISTS idx_employee_year ON leave_balances(employee_id, year)');

        // Ensure created_at field exists and has default values
        await db.execute('''
        UPDATE leave_applications 
        SET created_at = application_date 
        WHERE created_at IS NULL OR created_at = ''
        ''');

        print('Enhanced indexes and constraints added successfully');
      } catch (e) {
        print('Error adding indexes: $e');
      }
    }
  }

  // Enhanced query methods with better error handling
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    try {
      return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error inserting into $table: $e');
      print('Data: $data');

      // Try to handle specific table creation if needed
      if (e.toString().contains('no such table')) {
        await _createMissingTable(db, table);
        // Retry insert
        return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    try {
      return await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('Error querying $table: $e');
      print('Where: $where, Args: $whereArgs');

      // Return empty list if table doesn't exist yet
      if (e.toString().contains('no such table')) {
        return [];
      }

      rethrow;
    }
  }

  Future<int> update(String table, Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    try {
      return await db.update(
        table,
        data,
        where: where,
        whereArgs: whereArgs,
      );
    } catch (e) {
      print('Error updating $table: $e');
      print('Data: $data, Where: $where, Args: $whereArgs');
      return 0;
    }
  }

  Future<int> delete(String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    try {
      return await db.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      );
    } catch (e) {
      print('Error deleting from $table: $e');
      return 0;
    }
  }

  // Count records in a table
  Future<int> count(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    try {
      final result = await db.query(
        table,
        columns: ['COUNT(*) as count'],
        where: where,
        whereArgs: whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('Error counting records in $table: $e');
      return 0;
    }
  }

  // Execute custom SQL
  Future<void> execute(String sql) async {
    final db = await database;
    try {
      await db.execute(sql);
    } catch (e) {
      print('Error executing SQL: $e');
      print('SQL: $sql');
      rethrow;
    }
  }

  // Helper method to create missing tables
  Future<void> _createMissingTable(Database db, String tableName) async {
    switch (tableName) {
      case 'leave_applications':
        await _createTableIfNotExists(db, '''
        CREATE TABLE IF NOT EXISTS leave_applications(
          id TEXT PRIMARY KEY,
          employee_id TEXT NOT NULL,
          employee_name TEXT NOT NULL,
          employee_pin TEXT NOT NULL,
          leave_type TEXT NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          total_days INTEGER NOT NULL,
          reason TEXT NOT NULL,
          is_already_taken INTEGER DEFAULT 0,
          certificate_url TEXT,
          certificate_file_name TEXT,
          status TEXT DEFAULT 'pending',
          application_date TEXT NOT NULL,
          line_manager_id TEXT NOT NULL,
          line_manager_name TEXT NOT NULL,
          review_date TEXT,
          review_comments TEXT,
          reviewed_by TEXT,
          is_active INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
        ''');
        break;

      case 'leave_balances':
        await _createTableIfNotExists(db, '''
        CREATE TABLE IF NOT EXISTS leave_balances(
          id TEXT PRIMARY KEY,
          employee_id TEXT NOT NULL,
          year INTEGER NOT NULL,
          total_days TEXT NOT NULL,
          used_days TEXT NOT NULL,
          pending_days TEXT NOT NULL,
          last_updated TEXT,
          is_synced INTEGER DEFAULT 1
        )
        ''');
        break;

      default:
        print('Unknown table: $tableName');
    }
  }

  // Method to clear all data (useful for debugging)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Get all table names
      final tables = await txn.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );

      // Drop each table
      for (final table in tables) {
        if (table['name'] != 'android_metadata' &&
            table['name'] != 'sqlite_sequence') {
          await txn.execute('DROP TABLE IF EXISTS ${table['name']}');
        }
      }
    });

    // Reinitialize the database
    await _createDb(db, 5);

    print('Database cleared and reinitialized');
  }

  // ✅ NEW: Method to get database info for debugging
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    try {
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );

      final info = <String, dynamic>{
        'path': db.path,
        'version': await db.getVersion(),
        'tables': [],
      };

      for (final table in tables) {
        final tableName = table['name'] as String;
        if (tableName != 'android_metadata' && tableName != 'sqlite_sequence') {
          final count = await this.count(tableName);
          info['tables'].add({
            'name': tableName,
            'count': count,
          });
        }
      }

      return info;
    } catch (e) {
      print('Error getting database info: $e');
      return {'error': e.toString()};
    }
  }

  // ✅ NEW: Method to vacuum database for better performance
  Future<void> vacuum() async {
    final db = await database;
    try {
      await db.execute('VACUUM');
      print('Database vacuumed successfully');
    } catch (e) {
      print('Error vacuuming database: $e');
    }
  }
}