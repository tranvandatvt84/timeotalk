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

  test('sendTextMessage queues message when Ably is disconnected', () async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final localRepository = ChatLocalRepository(database: database!);
    final viewModel = ChatViewModel(
      currentUserId: 'user_1',
      localRepository: localRepository,
      realtimeRepository: _DisconnectedRealtimeRepository(),
      clientMessageIdGenerator: () => 'client_offline',
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );

    await viewModel.sendTextMessage('conversation_1', 'offline hello');

    final rows = await database!.transaction((transaction) {
      return transaction.query('outgoing_queue');
    });
    expect(rows, hasLength(1));
    expect(rows.single['client_message_id'], 'client_offline');
    expect(rows.single['conversation_id'], 'conversation_1');

    final payload = jsonDecode(rows.single['payload_json'] as String) as Map;
    expect(payload['event'], 'message.created');
    expect(payload['body'], {'text': 'offline hello'});
  });

  test('flush publishes queued messages and removes them', () async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    final localRepository = ChatLocalRepository(database: database!);
    final disconnectedViewModel = ChatViewModel(
      currentUserId: 'user_1',
      localRepository: localRepository,
      realtimeRepository: _DisconnectedRealtimeRepository(),
      clientMessageIdGenerator: () => 'client_reconnect',
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    await disconnectedViewModel.sendTextMessage(
      'conversation_1',
      'send after reconnect',
    );

    final realtimeRepository = _RecordingRealtimeRepository();
    final queue = OutgoingQueue(
      localRepository: localRepository,
      realtimeRepository: realtimeRepository,
    );

    await queue.flush();

    expect(
      realtimeRepository.published.single.clientMessageId,
      'client_reconnect',
    );
    final rows = await database!.transaction((transaction) {
      return transaction.query('outgoing_queue');
    });
    expect(rows, isEmpty);
  });
}

class _DisconnectedRealtimeRepository implements ChatRealtimeRepository {
  @override
  Future<void> publishMessageCreated(ChatMessageModel message) {
    throw StateError('Ably is not connected.');
  }
}

class _RecordingRealtimeRepository implements ChatRealtimeRepository {
  final published = <ChatMessageModel>[];

  @override
  Future<void> publishMessageCreated(ChatMessageModel message) async {
    published.add(message);
  }
}
