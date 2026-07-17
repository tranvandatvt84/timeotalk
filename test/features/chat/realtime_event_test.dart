import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/core/realtime/realtime_event.dart';

void main() {
  test('RealtimeEvent parses message.created events', () {
    final event = RealtimeEvent.fromJson(const {
      'event': 'message.created',
      'client_message_id': 'client_1',
      'conversation_id': 'conversation_1',
      'sender_id': 'sender_1',
      'type': 'text',
      'body': {'text': 'Hello'},
      'attachments': [],
      'client_created_at': '2026-07-17T10:00:00.000Z',
    });

    expect(event.type, RealtimeEventType.messageCreated);
    expect(event.message?.clientMessageId, 'client_1');
    expect(event.message?.conversationId, 'conversation_1');
    expect(event.message?.body['text'], 'Hello');
    expect(event.message?.persistenceStatus, 'pending');
    expect(event.receipt, isNull);
  });

  test('RealtimeEvent parses message.persisted events', () {
    final event = RealtimeEvent.fromJson(const {
      'event': 'message.persisted',
      'client_message_id': 'client_2',
      'server_message_id': 'server_2',
      'conversation_id': 'conversation_1',
      'sender_id': 'sender_1',
      'type': 'text',
      'body': {'text': 'Stored'},
      'attachments': [],
      'server_created_at': '2026-07-17T10:00:01.000Z',
    });

    expect(event.type, RealtimeEventType.messagePersisted);
    expect(event.message?.serverMessageId, 'server_2');
    expect(event.message?.persistenceStatus, 'persisted');
  });

  test('RealtimeEvent parses message.rejected events', () {
    final event = RealtimeEvent.fromJson(const {
      'event': 'message.rejected',
      'client_message_id': 'client_3',
      'conversation_id': 'conversation_1',
      'type': 'text',
      'body': {'text': 'Nope'},
      'attachments': [],
      'error': 'Conversation membership required',
    });

    expect(event.type, RealtimeEventType.messageRejected);
    expect(event.message?.clientMessageId, 'client_3');
    expect(event.message?.persistenceStatus, 'rejected');
    expect(event.errorMessage, 'Conversation membership required');
  });

  test('RealtimeEvent parses receipt.delivered events', () {
    final event = RealtimeEvent.fromJson(const {
      'event': 'receipt.delivered',
      'message_id': 'server_1',
      'client_message_id': 'client_1',
      'user_id': 'reader_1',
      'created_at': '2026-07-17T10:00:02.000Z',
    });

    expect(event.type, RealtimeEventType.receiptDelivered);
    expect(event.receipt?.messageId, 'server_1');
    expect(event.receipt?.clientMessageId, 'client_1');
    expect(event.receipt?.status, 'delivered');
    expect(event.message, isNull);
  });

  test('RealtimeEvent parses receipt.read events from nested Ably data', () {
    final event = RealtimeEvent.fromJson(const {
      'name': 'receipt.read',
      'data': {
        'message_id': 'server_1',
        'user_id': 'reader_1',
        'created_at': '2026-07-17T10:00:03.000Z',
      },
    });

    expect(event.type, RealtimeEventType.receiptRead);
    expect(event.receipt?.messageId, 'server_1');
    expect(event.receipt?.status, 'read');
  });

  test('RealtimeEvent parses typing events from nested Ably data', () {
    final started = RealtimeEvent.fromJson(const {
      'name': 'typing.started',
      'data': {'conversation_id': 'conversation_1', 'user_id': 'user_2'},
    });
    final stopped = RealtimeEvent.fromJson(const {
      'name': 'typing.stopped',
      'data': {'conversation_id': 'conversation_1', 'user_id': 'user_2'},
    });

    expect(started.type, RealtimeEventType.typingStarted);
    expect(started.payload['user_id'], 'user_2');
    expect(stopped.type, RealtimeEventType.typingStopped);
    expect(stopped.payload['conversation_id'], 'conversation_1');
  });
}
