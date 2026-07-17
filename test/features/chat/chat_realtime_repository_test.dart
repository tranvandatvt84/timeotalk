import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/core/realtime/realtime_event.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/models/chat_receipt_model.dart';
import 'package:timeotalk/features/chat/repositories/chat_realtime_repository.dart';

void main() {
  test(
    'publishMessageCreated publishes message.created to chat channel',
    () async {
      final transport = _RecordingTransport();
      final repository = AblyChatRealtimeRepository(transport: transport);
      const message = ChatMessageModel(
        clientMessageId: 'client_1',
        conversationId: 'conversation_1',
        senderId: 'user_1',
        type: 'text',
        body: {'text': 'hello'},
        attachments: [],
        persistenceStatus: 'pending',
      );

      await repository.publishMessageCreated(message);

      expect(transport.channelName, 'chat:conversation_1');
      expect(transport.eventName, 'message.created');
      expect(transport.data, {
        'event': 'message.created',
        'version': 1,
        'client_message_id': 'client_1',
        'conversation_id': 'conversation_1',
        'sender_id': 'user_1',
        'type': 'text',
        'body': {'text': 'hello'},
        'attachments': <Object?>[],
        'persistence_status': 'pending',
      });
    },
  );

  test('subscribeToConversation streams realtime events from chat channel', () {
    final transport = _RecordingTransport();
    final repository = AblyChatRealtimeRepository(transport: transport);

    final events = repository.subscribeToConversation('conversation_1');

    expect(transport.subscribedChannelName, 'chat:conversation_1');
    expect(
      events,
      emits(
        isA<RealtimeEvent>()
            .having(
              (event) => event.type,
              'type',
              RealtimeEventType.messageCreated,
            )
            .having(
              (event) => event.message?.clientMessageId,
              'clientMessageId',
              'client_2',
            ),
      ),
    );

    transport.emit({
      'name': 'message.created',
      'data': {
        'client_message_id': 'client_2',
        'conversation_id': 'conversation_1',
        'sender_id': 'user_2',
        'type': 'text',
        'body': {'text': 'incoming'},
        'attachments': <Object?>[],
        'client_created_at': '2026-01-01T12:01:00.000Z',
      },
    });
  });

  test(
    'publishReceiptDelivered publishes receipt.delivered to chat channel',
    () async {
      final transport = _RecordingTransport();
      final repository = AblyChatRealtimeRepository(transport: transport);
      final receipt = ChatReceiptModel(
        messageId: 'server_1',
        clientMessageId: 'client_1',
        userId: 'user_2',
        status: 'delivered',
        createdAt: DateTime.utc(2026, 1, 1, 12, 2),
      );

      await repository.publishReceiptDelivered(
        conversationId: 'conversation_1',
        receipt: receipt,
      );

      expect(transport.published.last.channelName, 'chat:conversation_1');
      expect(transport.published.last.eventName, 'receipt.delivered');
      expect(transport.published.last.data, {
        'event': 'receipt.delivered',
        'version': 1,
        'message_id': 'server_1',
        'client_message_id': 'client_1',
        'user_id': 'user_2',
        'status': 'delivered',
        'created_at': '2026-01-01T12:02:00.000Z',
      });
    },
  );

  test('publishReceiptRead publishes receipt.read to chat channel', () async {
    final transport = _RecordingTransport();
    final repository = AblyChatRealtimeRepository(transport: transport);

    await repository.publishReceiptRead(
      conversationId: 'conversation_1',
      receipt: ChatReceiptModel(
        clientMessageId: 'client_1',
        userId: 'user_2',
        status: 'read',
        createdAt: DateTime.utc(2026, 1, 1, 12, 3),
      ),
    );

    expect(transport.published.last.channelName, 'chat:conversation_1');
    expect(transport.published.last.eventName, 'receipt.read');
    expect(transport.published.last.data, {
      'event': 'receipt.read',
      'version': 1,
      'client_message_id': 'client_1',
      'user_id': 'user_2',
      'status': 'read',
      'created_at': '2026-01-01T12:03:00.000Z',
    });
  });

  test(
    'publishTyping events publish started and stopped to chat channel',
    () async {
      final transport = _RecordingTransport();
      final repository = AblyChatRealtimeRepository(transport: transport);

      await repository.publishTypingStarted(
        conversationId: 'conversation_1',
        userId: 'user_1',
      );
      await repository.publishTypingStopped(
        conversationId: 'conversation_1',
        userId: 'user_1',
      );

      expect(transport.published[0].channelName, 'chat:conversation_1');
      expect(transport.published[0].eventName, 'typing.started');
      expect(transport.published[0].data, {
        'event': 'typing.started',
        'version': 1,
        'conversation_id': 'conversation_1',
        'user_id': 'user_1',
      });
      expect(transport.published[1].channelName, 'chat:conversation_1');
      expect(transport.published[1].eventName, 'typing.stopped');
      expect(transport.published[1].data, {
        'event': 'typing.stopped',
        'version': 1,
        'conversation_id': 'conversation_1',
        'user_id': 'user_1',
      });
    },
  );
}

class _RecordingTransport implements ChatRealtimeTransport {
  String? channelName;
  String? eventName;
  Object? data;
  String? subscribedChannelName;
  final published = <_PublishedEvent>[];
  final _incoming = StreamController<Map<String, Object?>>.broadcast();

  @override
  Future<void> publish({
    required String channelName,
    required String eventName,
    required Object? data,
  }) async {
    this.channelName = channelName;
    this.eventName = eventName;
    this.data = data;
    published.add(
      _PublishedEvent(
        channelName: channelName,
        eventName: eventName,
        data: data,
      ),
    );
  }

  @override
  Stream<Map<String, Object?>> subscribe({required String channelName}) {
    subscribedChannelName = channelName;
    return _incoming.stream;
  }

  void emit(Map<String, Object?> event) {
    _incoming.add(event);
  }
}

class _PublishedEvent {
  const _PublishedEvent({
    required this.channelName,
    required this.eventName,
    required this.data,
  });

  final String channelName;
  final String eventName;
  final Object? data;
}
