import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/core/config/app_config.dart';

void main() {
  test('fromEnvironment uses the default Ably token function name', () {
    final config = AppConfig.fromEnvironment();

    expect(config.ablyTokenFunctionName, 'ably-token');
  });

  test('fromEnvironment provides Supabase credentials for click-run', () {
    final config = AppConfig.fromEnvironment();

    expect(config.hasSupabaseCredentials, isTrue);
    expect(config.supabaseUrl, startsWith('https://'));
    expect(config.supabaseAnonKey, isNotEmpty);
  });
}
