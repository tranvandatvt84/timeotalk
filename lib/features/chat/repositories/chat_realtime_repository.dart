import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:timeotalk/core/realtime/realtime_event.dart';
import 'package:timeotalk/core/realtime/ably_client_provider.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/models/chat_receipt_model.dart';

abstract class ChatRealtimeRepository {
  Stream<RealtimeEvent> subscribeToConversation(String conversationId);

  Future<void> publishMessageCreated(ChatMessageModel message);

  Future<void> publishReceiptDelivered({
    required String conversationId,
    required ChatReceiptModel receipt,
  });

  Future<void> publishReceiptRead({
    required String conversationId,
    required ChatReceiptModel receipt,
  });

  Future<void> publishTypingStarted({
    required String conversationId,
    required String userId,
  });

  Future<void> publishTypingStopped({
    required String conversationId,
    required String userId,
  });
}

class AblyChatRealtimeRepository implements ChatRealtimeRepository {
  AblyChatRealtimeRepository({
    ChatRealtimeTransport? transport,
    AblyClientProvider? clientProvider,
    AblyClientProvider Function()? clientProviderFactory,
  }) : _transport =
           transport ??
           AblyChatRealtimeTransport(
             clientProvider: clientProvider,
             clientProviderFactory: clientProviderFactory,
           );

  final ChatRealtimeTransport _transport;

  @override
  Stream<RealtimeEvent> subscribeToConversation(String conversationId) {
    return _transport
        .subscribe(channelName: _chatChannel(conversationId))
        .map(RealtimeEvent.fromJson);
  }

  @override
  Future<void> publishMessageCreated(ChatMessageModel message) {
    return _transport.publish(
      channelName: _chatChannel(message.conversationId),
      eventName: 'message.created',
      data: messageCreatedPayload(message),
    );
  }

  @override
  Future<void> publishReceiptDelivered({
    required String conversationId,
    required ChatReceiptModel receipt,
  }) {
    return _transport.publish(
      channelName: _chatChannel(conversationId),
      eventName: 'receipt.delivered',
      data: receiptPayload('receipt.delivered', receipt),
    );
  }

  @override
  Future<void> publishReceiptRead({
    required String conversationId,
    required ChatReceiptModel receipt,
  }) {
    return _transport.publish(
      channelName: _chatChannel(conversationId),
      eventName: 'receipt.read',
      data: receiptPayload('receipt.read', receipt),
    );
  }

  @override
  Future<void> publishTypingStarted({
    required String conversationId,
    required String userId,
  }) {
    return _transport.publish(
      channelName: _chatChannel(conversationId),
      eventName: 'typing.started',
      data: typingPayload(
        'typing.started',
        conversationId: conversationId,
        userId: userId,
      ),
    );
  }

  @override
  Future<void> publishTypingStopped({
    required String conversationId,
    required String userId,
  }) {
    return _transport.publish(
      channelName: _chatChannel(conversationId),
      eventName: 'typing.stopped',
      data: typingPayload(
        'typing.stopped',
        conversationId: conversationId,
        userId: userId,
      ),
    );
  }
}

abstract class ChatRealtimeTransport {
  Future<void> publish({
    required String channelName,
    required String eventName,
    required Object? data,
  });

  Stream<Map<String, Object?>> subscribe({required String channelName});
}

class AblyChatRealtimeTransport implements ChatRealtimeTransport {
  AblyChatRealtimeTransport({
    AblyClientProvider? clientProvider,
    AblyClientProvider Function()? clientProviderFactory,
  }) : _clientProvider = clientProvider,
       _clientProviderFactory =
           clientProviderFactory ?? (() => AblyClientProvider());

  final AblyClientProvider? _clientProvider;
  final AblyClientProvider Function() _clientProviderFactory;

  AblyClientProvider? _createdClientProvider;

  @override
  Future<void> publish({
    required String channelName,
    required String eventName,
    required Object? data,
  }) async {
    final channel = _provider().channel(channelName);
    await channel.publish(name: eventName, data: data);
  }

  @override
  Stream<Map<String, Object?>> subscribe({required String channelName}) {
    final channel = _provider().channel(channelName);
    return channel.subscribe().map(_ablyMessageToJson);
  }

  AblyClientProvider _provider() {
    final provider = _clientProvider;
    if (provider != null) {
      return provider;
    }

    return _createdClientProvider ??= _clientProviderFactory();
  }
}

Map<String, Object?> messageCreatedPayload(ChatMessageModel message) {
  return {'event': 'message.created', 'version': 1, ...message.toJson()};
}

Map<String, Object?> receiptPayload(
  String eventName,
  ChatReceiptModel receipt,
) {
  return {'event': eventName, 'version': 1, ...receipt.toJson()};
}

Map<String, Object?> typingPayload(
  String eventName, {
  required String conversationId,
  required String userId,
}) {
  return {
    'event': eventName,
    'version': 1,
    'conversation_id': conversationId,
    'user_id': userId,
  };
}

String _chatChannel(String conversationId) {
  return 'chat:$conversationId';
}

Map<String, Object?> _ablyMessageToJson(ably.Message message) {
  final data = message.data;
  if (data is Map<String, Object?>) {
    return {'name': message.name, 'data': data};
  }
  if (data is Map) {
    return {
      'name': message.name,
      'data': data.map((key, value) => MapEntry(key.toString(), value)),
    };
  }

  return {'name': message.name, 'data': data};
}
