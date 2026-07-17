import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timeotalk/core/database/app_database.dart';
import 'package:timeotalk/core/realtime/realtime_event.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/models/chat_receipt_model.dart';
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

  test(
    'openConversation subscribes, stores incoming messages once, and emits receipts',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final localRepository = ChatLocalRepository(database: database!);
      final realtimeRepository = _FakeRealtimeRepository();
      addTearDown(realtimeRepository.close);
      final viewModel = ChatViewModel(
        currentUserId: 'user_1',
        localRepository: localRepository,
        realtimeRepository: realtimeRepository,
        clock: () => DateTime.utc(2026, 1, 1, 12, 4),
      );
      addTearDown(viewModel.dispose);

      await viewModel.openConversation('conversation_1');
      realtimeRepository.emit(
        RealtimeEvent.fromJson({
          'event': 'message.created',
          'client_message_id': 'client_incoming',
          'server_message_id': 'server_incoming',
          'conversation_id': 'conversation_1',
          'sender_id': 'user_2',
          'type': 'text',
          'body': {'text': 'incoming hello'},
          'attachments': <Object?>[],
          'client_created_at': '2026-01-01T12:01:00.000Z',
        }),
      );
      await pumpEventQueue();

      realtimeRepository.emit(
        RealtimeEvent.fromJson({
          'event': 'message.created',
          'client_message_id': 'client_incoming',
          'server_message_id': 'server_incoming',
          'conversation_id': 'conversation_1',
          'sender_id': 'user_2',
          'type': 'text',
          'body': {'text': 'incoming hello'},
          'attachments': <Object?>[],
          'client_created_at': '2026-01-01T12:01:00.000Z',
        }),
      );
      await pumpEventQueue();

      expect(realtimeRepository.subscribedConversationIds, ['conversation_1']);
      final rows = await database!.transaction((transaction) {
        return transaction.query(
          'local_messages',
          where: 'client_message_id = ?',
          whereArgs: ['client_incoming'],
        );
      });
      expect(rows, hasLength(1));
      expect(rows.single['local_status'], 'received');
      expect(rows.single['delivery_status'], 'read');
      expect(jsonDecode(rows.single['body_json'] as String), {
        'text': 'incoming hello',
      });
      expect(viewModel.state.messages, hasLength(1));
      expect(viewModel.state.messages.single.body['text'], 'incoming hello');
      expect(realtimeRepository.deliveredReceipts, hasLength(1));
      expect(
        realtimeRepository.deliveredReceipts.single.receipt.clientMessageId,
        'client_incoming',
      );
      expect(realtimeRepository.readReceipts, hasLength(1));
      expect(
        realtimeRepository.readReceipts.single.receipt.clientMessageId,
        'client_incoming',
      );
    },
  );

  test(
    'openConversation does not mark all loaded messages read immediately',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final localRepository = ChatLocalRepository(database: database!);
      await localRepository.insertReceivedMessage(
        ChatMessageModel(
          clientMessageId: 'client_loaded',
          conversationId: 'conversation_1',
          senderId: 'user_2',
          type: 'text',
          body: {'text': 'loaded but not viewed yet'},
          attachments: const [],
          persistenceStatus: 'persisted',
          clientCreatedAt: DateTime.utc(2026, 1, 1, 12),
          updatedAt: DateTime.utc(2026, 1, 1, 12),
        ),
      );
      final realtimeRepository = _FakeRealtimeRepository();
      addTearDown(realtimeRepository.close);
      final viewModel = ChatViewModel(
        currentUserId: 'user_1',
        localRepository: localRepository,
        realtimeRepository: realtimeRepository,
        clock: () => DateTime.utc(2026, 1, 1, 12, 4),
      );
      addTearDown(viewModel.dispose);

      await viewModel.openConversation('conversation_1');

      expect(realtimeRepository.readReceipts, isEmpty);
      expect(
        (await localRepository.fetchMessageByClientId(
          'client_loaded',
        ))?.deliveryStatus,
        isNull,
      );

      await viewModel.markMessageVisible(viewModel.state.messages.single);
      await pumpEventQueue();

      expect(realtimeRepository.readReceipts, hasLength(1));
      expect(
        (await localRepository.fetchMessageByClientId(
          'client_loaded',
        ))?.deliveryStatus,
        'read',
      );
    },
  );

  test(
    'receipt publish failures are retried instead of permanently deduped',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final localRepository = ChatLocalRepository(database: database!);
      final realtimeRepository = _FakeRealtimeRepository()
        ..failNextDeliveredReceipt = true
        ..failNextReadReceipt = true;
      addTearDown(realtimeRepository.close);
      final viewModel = ChatViewModel(
        currentUserId: 'user_1',
        localRepository: localRepository,
        realtimeRepository: realtimeRepository,
        clock: () => DateTime.utc(2026, 1, 1, 12, 4),
      );
      addTearDown(viewModel.dispose);
      await viewModel.openConversation('conversation_1');
      final event = RealtimeEvent.fromJson({
        'event': 'message.created',
        'client_message_id': 'client_retry',
        'server_message_id': 'server_retry',
        'conversation_id': 'conversation_1',
        'sender_id': 'user_2',
        'type': 'text',
        'body': {'text': 'retry receipts'},
        'attachments': <Object?>[],
        'client_created_at': '2026-01-01T12:01:00.000Z',
      });

      await viewModel.handleRealtimeEvent(event);
      await pumpEventQueue();

      expect(realtimeRepository.deliveredReceipts, isEmpty);
      expect(realtimeRepository.readReceipts, isEmpty);
      expect(
        (await localRepository.fetchMessageByClientId(
          'client_retry',
        ))?.deliveryStatus,
        isNull,
      );

      await viewModel.handleRealtimeEvent(event);
      await pumpEventQueue();

      expect(realtimeRepository.deliveredReceipts, hasLength(1));
      expect(realtimeRepository.readReceipts, hasLength(1));
      expect(
        (await localRepository.fetchMessageByClientId(
          'client_retry',
        ))?.deliveryStatus,
        'read',
      );
    },
  );

  test(
    'handleRealtimeEvent applies delivered and read receipts to local messages',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final localRepository = ChatLocalRepository(database: database!);
      final realtimeRepository = _FakeRealtimeRepository();
      final viewModel = ChatViewModel(
        currentUserId: 'user_1',
        localRepository: localRepository,
        realtimeRepository: realtimeRepository,
        clientMessageIdGenerator: () => 'client_1',
        clock: () => DateTime.utc(2026, 1, 1, 12),
      );
      await viewModel.sendTextMessage('conversation_1', 'hello there');

      await viewModel.handleRealtimeEvent(
        RealtimeEvent.fromJson({
          'event': 'receipt.delivered',
          'client_message_id': 'client_1',
          'user_id': 'user_2',
          'created_at': '2026-01-01T12:02:00.000Z',
        }),
      );
      await viewModel.handleRealtimeEvent(
        RealtimeEvent.fromJson({
          'event': 'receipt.read',
          'client_message_id': 'client_1',
          'user_id': 'user_2',
          'created_at': '2026-01-01T12:03:00.000Z',
        }),
      );

      final row = await localRepository.fetchMessageByClientId('client_1');
      expect(row?.deliveryStatus, 'read');
      expect(viewModel.state.messages.single.deliveryStatus, 'read');
    },
  );

  test(
    'updateComposerText publishes typing started once and stopped after debounce',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final realtimeRepository = _FakeRealtimeRepository();
      addTearDown(realtimeRepository.close);
      final viewModel = ChatViewModel(
        currentUserId: 'user_1',
        localRepository: ChatLocalRepository(database: database!),
        realtimeRepository: realtimeRepository,
        typingStopDelay: const Duration(milliseconds: 10),
      );
      addTearDown(viewModel.dispose);

      await viewModel.openConversation('conversation_1');
      viewModel.updateComposerText('h');
      viewModel.updateComposerText('he');
      await pumpEventQueue();

      expect(realtimeRepository.typingStartedUsers, ['user_1']);

      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(realtimeRepository.typingStoppedUsers, ['user_1']);
    },
  );

  test(
    'openConversation resets typing debounce when switching conversations',
    () async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      final realtimeRepository = _FakeRealtimeRepository();
      addTearDown(realtimeRepository.close);
      final viewModel = ChatViewModel(
        currentUserId: 'user_1',
        localRepository: ChatLocalRepository(database: database!),
        realtimeRepository: realtimeRepository,
        typingStopDelay: const Duration(milliseconds: 50),
      );
      addTearDown(viewModel.dispose);

      await viewModel.openConversation('conversation_1');
      viewModel.updateComposerText('hello');
      await pumpEventQueue();
      await viewModel.openConversation('conversation_2');
      viewModel.updateComposerText('next');
      await pumpEventQueue();

      expect(realtimeRepository.typingStartedConversations, [
        'conversation_1',
        'conversation_2',
      ]);
      expect(realtimeRepository.typingStoppedConversations, ['conversation_1']);
    },
  );
}

class _FakeRealtimeRepository implements ChatRealtimeRepository {
  final published = <ChatMessageModel>[];
  final subscribedConversationIds = <String>[];
  final deliveredReceipts = <_ReceiptPublish>[];
  final readReceipts = <_ReceiptPublish>[];
  final typingStartedUsers = <String>[];
  final typingStoppedUsers = <String>[];
  final typingStartedConversations = <String>[];
  final typingStoppedConversations = <String>[];
  final _events = StreamController<RealtimeEvent>.broadcast(sync: true);
  bool failNextDeliveredReceipt = false;
  bool failNextReadReceipt = false;

  @override
  Future<void> publishMessageCreated(ChatMessageModel message) async {
    published.add(message);
  }

  @override
  Stream<RealtimeEvent> subscribeToConversation(String conversationId) {
    subscribedConversationIds.add(conversationId);
    return _events.stream;
  }

  @override
  Future<void> publishReceiptDelivered({
    required String conversationId,
    required ChatReceiptModel receipt,
  }) async {
    if (failNextDeliveredReceipt) {
      failNextDeliveredReceipt = false;
      throw StateError('delivered receipt publish failed');
    }

    deliveredReceipts.add(
      _ReceiptPublish(conversationId: conversationId, receipt: receipt),
    );
  }

  @override
  Future<void> publishReceiptRead({
    required String conversationId,
    required ChatReceiptModel receipt,
  }) async {
    if (failNextReadReceipt) {
      failNextReadReceipt = false;
      throw StateError('read receipt publish failed');
    }

    readReceipts.add(
      _ReceiptPublish(conversationId: conversationId, receipt: receipt),
    );
  }

  @override
  Future<void> publishTypingStarted({
    required String conversationId,
    required String userId,
  }) async {
    typingStartedUsers.add(userId);
    typingStartedConversations.add(conversationId);
  }

  @override
  Future<void> publishTypingStopped({
    required String conversationId,
    required String userId,
  }) async {
    typingStoppedUsers.add(userId);
    typingStoppedConversations.add(conversationId);
  }

  void emit(RealtimeEvent event) {
    _events.add(event);
  }

  Future<void> close() {
    return _events.close();
  }
}

class _ReceiptPublish {
  const _ReceiptPublish({required this.conversationId, required this.receipt});

  final String conversationId;
  final ChatReceiptModel receipt;
}
