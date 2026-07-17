import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:timeotalk/core/database/database_migrations.dart';

class AppDatabase {
  const AppDatabase._(this._database);

  final Database _database;

  static Future<AppDatabase> open({String? path}) async {
    final databasePath = path ?? await _defaultDatabasePath();
    final database = await openDatabase(
      databasePath,
      version: DatabaseMigrations.currentVersion,
      onCreate: (database, _) => DatabaseMigrations.create(database),
    );

    return AppDatabase._(database);
  }

  Future<bool> tableExists(String tableName) async {
    final rows = await _database.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? and name = ?',
      whereArgs: ['table', tableName],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<T> transaction<T>(Future<T> Function(Transaction transaction) action) {
    return _database.transaction(action);
  }

  Future<void> close() {
    return _database.close();
  }

  static Future<String> _defaultDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return path.join(databasesPath, 'timeotalk.db');
  }
}
