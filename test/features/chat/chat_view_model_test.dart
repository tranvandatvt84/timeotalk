import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timeotalk/core/database/app_database.dart';
import 'package:timeotalk/core/realtime/realtime_event.dart';
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

  test(
    'handleRealtimeEvent merges persisted messages into SQLite by client id',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final localRepository = ChatLocalRepository(database: database!);
      final viewModel = ChatViewModel(
        currentUserId: 'user_1',
        localRepository: localRepository,
        realtimeRepository: _FakeRealtimeRepository(),
        clientMessageIdGenerator: () => 'client_1',
        clock: () => DateTime.utc(2026, 1, 1, 12),
      );
      await viewModel.sendTextMessage('conversation_1', 'hello there');

      await viewModel.handleRealtimeEvent(
        RealtimeEvent.fromJson({
          'event': 'message.persisted',
          'client_message_id': 'client_1',
          'server_message_id': 'server_1',
          'conversation_id': 'conversation_1',
          'sender_id': 'user_1',
          'type': 'text',
          'body': {'text': 'hello there'},
          'server_created_at': '2026-01-01T12:00:01.000Z',
          'updated_at': '2026-01-01T12:00:01.000Z',
        }),
      );

      final rows = await database!.transaction((transaction) {
        return transaction.query(
          'local_messages',
          where: 'client_message_id = ?',
          whereArgs: ['client_1'],
        );
      });
      expect(rows.single['server_message_id'], 'server_1');
      expect(rows.single['persistence_status'], 'persisted');
      expect(rows.single['server_created_at'], '2026-01-01T12:00:01.000Z');
      expect(viewModel.state.messages.single.serverMessageId, 'server_1');
      expect(viewModel.state.messages.single.persistenceStatus, 'persisted');
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
