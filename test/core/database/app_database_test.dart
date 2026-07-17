import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timeotalk/core/database/app_database.dart';

void main() {
  AppDatabase? appDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await appDatabase?.close();
  });

  test('open creates every local persistence table', () async {
    appDatabase = await AppDatabase.open(path: inMemoryDatabasePath);
    final database = appDatabase!;

    for (final tableName in [
      'local_conversations',
      'local_messages',
      'local_contacts',
      'local_invitations',
      'outgoing_queue',
      'sync_cursors',
    ]) {
      expect(
        await database.tableExists(tableName),
        isTrue,
        reason: '$tableName should exist',
      );
    }
  });
}
