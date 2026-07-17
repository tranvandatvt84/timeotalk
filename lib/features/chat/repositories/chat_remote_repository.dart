import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/core/network/supabase_client_provider.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/repositories/chat_realtime_repository.dart';

abstract class ChatRemoteRepository {
  Future<void> persistMessage(ChatMessageModel message);
}

class SupabaseChatRemoteRepository implements ChatRemoteRepository {
  SupabaseChatRemoteRepository({PersistMessageInvoker? invoker})
    : _invoker = invoker ?? SupabasePersistMessageInvoker();

  final PersistMessageInvoker _invoker;

  @override
  Future<void> persistMessage(ChatMessageModel message) {
    return _invoker.invoke(
      'persist-message',
      body: messageCreatedPayload(message),
    );
  }
}

abstract class PersistMessageInvoker {
  Future<void> invoke(String functionName, {required Object body});
}

class SupabasePersistMessageInvoker implements PersistMessageInvoker {
  SupabasePersistMessageInvoker({
    SupabaseClient? client,
    SupabaseClient Function()? clientProvider,
  }) : _client = client,
       _clientProvider =
           clientProvider ?? (() => SupabaseClientProvider.client);

  final SupabaseClient? _client;
  final SupabaseClient Function() _clientProvider;

  @override
  Future<void> invoke(String functionName, {required Object body}) async {
    final response = await (_client ?? _clientProvider()).functions.invoke(
      functionName,
      body: body,
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError('$functionName failed with ${response.status}.');
    }
  }
}
