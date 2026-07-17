import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
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
}

class _RecordingTransport implements ChatRealtimeTransport {
  String? channelName;
  String? eventName;
  Object? data;

  @override
  Future<void> publish({
    required String channelName,
    required String eventName,
    required Object? data,
  }) async {
    this.channelName = channelName;
    this.eventName = eventName;
    this.data = data;
  }
}
