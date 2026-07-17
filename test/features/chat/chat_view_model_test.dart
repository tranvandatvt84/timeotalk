import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timeotalk/core/database/app_database.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/repositories/chat_local_repository.dart';
import 'package:timeotalk/features/chat/repositories/chat_realtime_repository.dart';
import 'package:timeotalk/features/chat/viewmodels/chat_view_model.dart';

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
    'sendTextMessage stores a pending local text message before publishing',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final localRepository = ChatLocalRepository(database: database!);
      final realtimeRepository = _FakeRealtimeRepository();
      final viewModel = ChatViewModel(
        currentUserId: 'user_1',
        senderDeviceId: 'device_1',
        localRepository: localRepository,
        realtimeRepository: realtimeRepository,
        clientMessageIdGenerator: () => 'client_1',
        clock: () => DateTime.utc(2026, 1, 1, 12),
      );

      final message = await viewModel.sendTextMessage(
        'conversation_1',
        '  hello there  ',
      );

      expect(message.clientMessageId, 'client_1');
      expect(message.persistenceStatus, 'pending');
      expect(realtimeRepository.published.single.clientMessageId, 'client_1');

      final rows = await database!.transaction((transaction) {
        return transaction.query(
          'local_messages',
          where: 'client_message_id = ?',
          whereArgs: ['client_1'],
        );
      });
      expect(rows, hasLength(1));
      expect(rows.single['conversation_id'], 'conversation_1');
      expect(rows.single['sender_id'], 'user_1');
      expect(rows.single['sender_device_id'], 'device_1');
      expect(rows.single['type'], 'text');
      expect(rows.single['persistence_status'], 'pending');
      expect(jsonDecode(rows.single['body_json'] as String), {
        'text': 'hello there',
      });
    },
  );
}

class _FakeRealtimeRepository implements ChatRealtimeRepository {
  final published = <ChatMessageModel>[];

  @override
  Future<void> publishMessageCreated(ChatMessageModel message) async {
    published.add(message);
  }
}
