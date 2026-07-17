import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';

void main() {
  group('ChatMessageModel', () {
    test('parses message.created events', () {
      final message = ChatMessageModel.fromJson({
        'event': 'message.created',
        'version': 1,
        'client_message_id': '01JABC123LOCALTEMP',
        'conversation_id': 'conv_123',
        'sender_device_id': 'device_abc',
        'type': 'text',
        'body': {'text': 'Hey, are you free later?'},
        'attachments': <Map<String, Object?>>[],
        'reply_to': null,
        'client_created_at': '2026-07-16T22:10:30.000Z',
      });

      expect(message.clientMessageId, '01JABC123LOCALTEMP');
      expect(message.serverMessageId, isNull);
      expect(message.conversationId, 'conv_123');
      expect(message.senderDeviceId, 'device_abc');
      expect(message.type, 'text');
      expect(message.body['text'], 'Hey, are you free later?');
      expect(message.attachments, isEmpty);
      expect(message.persistenceStatus, 'pending');
      expect(
        message.clientCreatedAt,
        DateTime.parse('2026-07-16T22:10:30.000Z'),
      );
    });

    test('parses message.persisted events', () {
      final message = ChatMessageModel.fromJson({
        'event': 'message.persisted',
        'version': 1,
        'client_message_id': '01JABC123LOCALTEMP',
        'server_message_id': 'msg_789',
        'conversation_id': 'conv_123',
        'server_created_at': '2026-07-16T22:10:31.000Z',
      });

      expect(message.clientMessageId, '01JABC123LOCALTEMP');
      expect(message.serverMessageId, 'msg_789');
      expect(message.conversationId, 'conv_123');
      expect(message.persistenceStatus, 'persisted');
      expect(
        message.serverCreatedAt,
        DateTime.parse('2026-07-16T22:10:31.000Z'),
      );
    });

    test('parses local SQLite rows', () {
      final message = ChatMessageModel.fromLocalRow({
        'client_message_id': 'local_123',
        'server_message_id': 'msg_123',
        'conversation_id': 'conv_123',
        'sender_id': 'user_456',
        'sender_device_id': 'device_abc',
        'type': 'image',
        'body_json': '{"text":"Look at this"}',
        'attachments_json':
            '[{"client_attachment_id":"att_local_1","storage_path":"chat/conv_123/local_123/image.jpg","mime_type":"image/jpeg","size_bytes":248000,"width":1200,"height":900}]',
        'local_status': 'sent_realtime',
        'delivery_status': 'delivered',
        'persistence_status': 'persisted',
        'client_created_at': '2026-07-16T22:10:30.000Z',
        'server_created_at': '2026-07-16T22:10:31.000Z',
        'updated_at': '2026-07-16T22:10:32.000Z',
      });

      expect(message.clientMessageId, 'local_123');
      expect(message.serverMessageId, 'msg_123');
      expect(message.senderId, 'user_456');
      expect(message.body['text'], 'Look at this');
      expect(
        message.attachments.single.storagePath,
        'chat/conv_123/local_123/image.jpg',
      );
      expect(message.localStatus, 'sent_realtime');
      expect(message.deliveryStatus, 'delivered');
      expect(message.persistenceStatus, 'persisted');
    });

    test('serializes and copies message data', () {
      final pending = ChatMessageModel.fromJson({
        'event': 'message.created',
        'version': 1,
        'client_message_id': 'local_123',
        'conversation_id': 'conv_123',
        'type': 'text',
        'body': {'text': 'hello'},
        'client_created_at': '2026-07-16T22:10:30.000Z',
      });

      final persisted = pending.copyWith(
        serverMessageId: 'msg_123',
        persistenceStatus: 'persisted',
        serverCreatedAt: DateTime.parse('2026-07-16T22:10:31.000Z'),
      );

      expect(pending.serverMessageId, isNull);
      expect(persisted.serverMessageId, 'msg_123');
      expect(persisted.toJson()['server_message_id'], 'msg_123');
      expect(persisted.toJson()['persistence_status'], 'persisted');
    });
  });
}
