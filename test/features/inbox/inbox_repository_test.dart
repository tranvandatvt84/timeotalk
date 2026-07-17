import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/core/database/app_database.dart';
import 'package:timeotalk/features/inbox/models/conversation_model.dart';
import 'package:timeotalk/features/inbox/repositories/inbox_repository.dart';

void main() {
  AppDatabase? database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await database?.close();
    database = null;
  });

  test(
    'syncConversations stores remote conversations and cursor rows',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final repository = _TestInboxRepository(
        database: database!,
        remoteConversations: [
          ConversationModel(
            id: 'conversation_1',
            type: 'direct',
            title: 'Alex Rivera',
            lastMessagePreview: 'Fresh from Supabase',
            lastServerMessageId: 'message_1',
            lastServerCreatedAt: DateTime.utc(2026, 1, 1, 12),
            unreadCount: 3,
            updatedAt: DateTime.utc(2026, 1, 1, 12, 1),
          ),
        ],
      );

      await repository.syncConversations();

      final conversations = await repository.watchLocalConversations().first;
      expect(conversations, hasLength(1));
      expect(conversations.single.id, 'conversation_1');
      expect(conversations.single.title, 'Alex Rivera');
      expect(conversations.single.lastServerMessageId, 'message_1');
      expect(conversations.single.unreadCount, 3);

      final cursorRows = await database!.transaction((transaction) {
        return transaction.query(
          'sync_cursors',
          where: 'conversation_id = ?',
          whereArgs: ['conversation_1'],
        );
      });
      expect(cursorRows, hasLength(1));
      expect(cursorRows.single['last_server_message_id'], 'message_1');
      expect(cursorRows.single['last_synced_at'], isNotNull);
    },
  );
}

class _TestInboxRepository extends SupabaseInboxRepository {
  _TestInboxRepository({
    required AppDatabase database,
    required this.remoteConversations,
  }) : super(
         client: SupabaseClient('https://example.supabase.co', 'anon-key'),
         database: database,
       );

  final List<ConversationModel> remoteConversations;

  @override
  Future<List<ConversationModel>> fetchRemoteConversations() async {
    return remoteConversations;
  }
}
