import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timeotalk/core/database/app_database.dart';
import 'package:timeotalk/core/realtime/realtime_event.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/models/chat_receipt_model.dart';
import 'package:timeotalk/features/chat/repositories/chat_local_repository.dart';
import 'package:timeotalk/features/chat/repositories/chat_realtime_repository.dart';
import 'package:timeotalk/features/chat/viewmodels/chat_view_model.dart';
import 'package:timeotalk/features/chat/views/chat_view.dart';
import 'package:timeotalk/features/chat/views/widgets/message_input.dart';

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

  testWidgets('ChatView renders SQLite messages with receipt states', (
    tester,
  ) async {
    late ChatLocalRepository localRepository;
    await tester.runAsync(() async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
      localRepository = ChatLocalRepository(database: database!);
      await _seed(localRepository, [
        _message(
          'client_pending',
          'Pending copy',
          'pending_realtime',
          null,
          'pending',
        ),
        _message(
          'client_delivered',
          'Delivered copy',
          'sent_realtime',
          'delivered',
          'persisted',
        ),
        _message(
          'client_read',
          'Read copy',
          'sent_realtime',
          'read',
          'persisted',
        ),
        _message(
          'client_failed',
          'Failed copy',
          'failed_realtime',
          null,
          'pending',
        ),
        _message(
          'client_rejected',
          'Rejected copy',
          'rejected',
          null,
          'rejected',
        ),
        _message(
          'client_persisted',
          'Persisted copy',
          'sent_realtime',
          null,
          'persisted',
        ),
      ]);
    });
    final realtimeRepository = _FakeRealtimeRepository();
    addTearDown(realtimeRepository.close);
    final viewModel = ChatViewModel(
      currentUserId: 'user_1',
      localRepository: localRepository,
      realtimeRepository: realtimeRepository,
    );
    addTearDown(viewModel.dispose);
    await tester.runAsync(() => viewModel.openConversation('conversation_1'));

    await tester.pumpWidget(
      MaterialApp(
        home: ChatView(
          conversationId: 'conversation_1',
          viewModel: viewModel,
          autoOpen: false,
        ),
      ),
    );
    await _pumpChatFrame(tester);

    expect(find.byKey(const Key('chat-view')), findsOneWidget);
    expect(find.text('Pending copy'), findsOneWidget);
    expect(find.text('Delivered copy'), findsOneWidget);
    expect(find.text('Read copy'), findsOneWidget);
    expect(find.text('Failed copy'), findsOneWidget);
    expect(find.text('Rejected copy'), findsOneWidget);
    expect(find.text('Persisted copy'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Persisted'), findsOneWidget);
  });

  testWidgets('MessageInput sends text through its callback', (tester) async {
    final sentTexts = <String>[];
    final changedTexts = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageInput(
            isSending: false,
            onChanged: changedTexts.add,
            onSend: (text) async {
              sentTexts.add(text);
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('message-input-text-field')),
      'hello from ui',
    );
    await tester.tap(find.byKey(const Key('message-send-button')));
    await _pumpChatFrame(tester);

    expect(sentTexts, ['hello from ui']);
    expect(changedTexts.last, '');
    expect(find.text('hello from ui'), findsNothing);
  });
}

Future<void> _pumpChatFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _seed(
  ChatLocalRepository localRepository,
  List<ChatMessageModel> messages,
) async {
  for (final message in messages) {
    await localRepository.insertOutgoingMessage(message);
  }
}

ChatMessageModel _message(
  String clientMessageId,
  String text,
  String localStatus,
  String? deliveryStatus,
  String persistenceStatus,
) {
  return ChatMessageModel(
    clientMessageId: clientMessageId,
    conversationId: 'conversation_1',
    senderId: 'user_1',
    type: 'text',
    body: {'text': text},
    attachments: const [],
    localStatus: localStatus,
    deliveryStatus: deliveryStatus,
    persistenceStatus: persistenceStatus,
    clientCreatedAt: DateTime.utc(2026, 1, 1, 12),
    updatedAt: DateTime.utc(2026, 1, 1, 12),
  );
}

class _FakeRealtimeRepository implements ChatRealtimeRepository {
  final published = <ChatMessageModel>[];
  final _events = StreamController<RealtimeEvent>.broadcast(sync: true);

  @override
  Future<void> publishMessageCreated(ChatMessageModel message) async {
    published.add(message);
  }

  @override
  Stream<RealtimeEvent> subscribeToConversation(String conversationId) {
    return _events.stream;
  }

  @override
  Future<void> publishReceiptDelivered({
    required String conversationId,
    required ChatReceiptModel receipt,
  }) async {}

  @override
  Future<void> publishReceiptRead({
    required String conversationId,
    required ChatReceiptModel receipt,
  }) async {}

  @override
  Future<void> publishTypingStarted({
    required String conversationId,
    required String userId,
  }) async {}

  @override
  Future<void> publishTypingStopped({
    required String conversationId,
    required String userId,
  }) async {}

  Future<void> close() {
    return _events.close();
  }
}
