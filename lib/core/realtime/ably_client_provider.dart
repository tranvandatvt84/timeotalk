import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/core/config/app_config.dart';
import 'package:timeotalk/core/network/supabase_client_provider.dart';

typedef AblyRealtimeFactory =
    ably.Realtime Function(ably.ClientOptions options);

class AblyClientProvider {
  AblyClientProvider({
    SupabaseClient? supabaseClient,
    String? tokenFunctionName,
    AblyRealtimeFactory? realtimeFactory,
  }) : _supabase = supabaseClient ?? SupabaseClientProvider.client,
       _tokenFunctionName =
           tokenFunctionName ??
           AppConfig.fromEnvironment().ablyTokenFunctionName,
       _realtimeFactory =
           realtimeFactory ?? ((options) => ably.Realtime(options: options));

  final SupabaseClient _supabase;
  final String _tokenFunctionName;
  final AblyRealtimeFactory _realtimeFactory;

  ably.Realtime? _realtime;

  Future<ably.Realtime> connect() async {
    final existing = _realtime;
    if (existing != null) {
      await existing.connect();
      return existing;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot connect to Ably without a signed-in user.');
    }

    final realtime = _realtimeFactory(
      ably.ClientOptions(
        autoConnect: false,
        clientId: user.id,
        useTokenAuth: true,
        authCallback: _fetchToken,
      ),
    );
    _realtime = realtime;
    await realtime.connect();
    return realtime;
  }

  Future<void> disconnect() async {
    final realtime = _realtime;
    _realtime = null;
    await realtime?.close();
  }

  ably.RealtimeChannel channel(String name) {
    final realtime = _realtime;
    if (realtime == null) {
      throw StateError('Ably is not connected.');
    }

    return realtime.channels.get(name);
  }

  Future<Object> _fetchToken(ably.TokenParams params) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Cannot request an Ably token without a Supabase JWT.');
    }

    final response = await _supabase.functions.invoke(
      _tokenFunctionName,
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'client_id': _supabase.auth.currentUser?.id},
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Ably token function returned invalid data.');
    }

    final json = Map<String, dynamic>.from(data.cast<String, dynamic>());
    if (json['token'] != null) {
      return ably.TokenDetails.fromMap(json);
    }

    return ably.TokenRequest.fromMap(json);
  }
}
