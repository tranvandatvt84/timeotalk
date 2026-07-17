import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/repositories/chat_remote_repository.dart';

void main() {
  test('persistMessage invokes the persist-message function', () async {
    final invoker = _RecordingPersistMessageInvoker();
    final repository = SupabaseChatRemoteRepository(invoker: invoker);
    const message = ChatMessageModel(
      clientMessageId: 'client_1',
      conversationId: 'conversation_1',
      senderId: 'user_1',
      type: 'text',
      body: {'text': 'hello'},
      attachments: [],
      persistenceStatus: 'pending',
    );

    await repository.persistMessage(message);

    expect(invoker.functionName, 'persist-message');
    expect(invoker.body, {
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
  });
}

class _RecordingPersistMessageInvoker implements PersistMessageInvoker {
  String? functionName;
  Object? body;

  @override
  Future<void> invoke(String functionName, {required Object body}) async {
    this.functionName = functionName;
    this.body = body;
  }
}
