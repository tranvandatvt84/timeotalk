import 'package:timeotalk/core/realtime/ably_client_provider.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';

abstract class ChatRealtimeRepository {
  Future<void> publishMessageCreated(ChatMessageModel message);
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
  Future<void> publishMessageCreated(ChatMessageModel message) {
    return _transport.publish(
      channelName: 'chat:${message.conversationId}',
      eventName: 'message.created',
      data: messageCreatedPayload(message),
    );
  }
}

abstract class ChatRealtimeTransport {
  Future<void> publish({
    required String channelName,
    required String eventName,
    required Object? data,
  });
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
