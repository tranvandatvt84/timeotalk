import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/features/auth/repositories/auth_repository.dart';

void main() {
  group('SupabaseAuthRepository', () {
    test('signInWithGoogle opens the external browser', () async {
      final oauthLauncher = _FakeOAuthSignInLauncher();
      final repository = SupabaseAuthRepository(
        client: SupabaseClient('https://example.supabase.co', 'anon-key'),
        oauthRedirectTo: 'timeotalk://auth/callback',
        oauthLauncher: oauthLauncher,
      );

      await repository.signInWithGoogle();

      expect(oauthLauncher.lastProvider, OAuthProvider.google);
      expect(oauthLauncher.lastRedirectTo, 'timeotalk://auth/callback');
      expect(oauthLauncher.lastLaunchMode, LaunchMode.externalApplication);
    });

    test('signInWithApple opens the external browser', () async {
      final oauthLauncher = _FakeOAuthSignInLauncher();
      final repository = SupabaseAuthRepository(
        client: SupabaseClient('https://example.supabase.co', 'anon-key'),
        oauthLauncher: oauthLauncher,
      );

      await repository.signInWithApple();

      expect(oauthLauncher.lastProvider, OAuthProvider.apple);
      expect(oauthLauncher.lastLaunchMode, LaunchMode.externalApplication);
    });

    test('uses Supabase callback URL by default', () async {
      final oauthLauncher = _FakeOAuthSignInLauncher();
      final repository = SupabaseAuthRepository(
        client: SupabaseClient('https://example.supabase.co', 'anon-key'),
        oauthLauncher: oauthLauncher,
      );

      await repository.signInWithGoogle();

      expect(
        oauthLauncher.lastRedirectTo,
        'io.supabase.timeotalk://login-callback',
      );
    });
  });
}

class _FakeOAuthSignInLauncher implements OAuthSignInLauncher {
  OAuthProvider? lastProvider;
  String? lastRedirectTo;
  LaunchMode? lastLaunchMode;

  @override
  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
    required LaunchMode authScreenLaunchMode,
  }) async {
    lastProvider = provider;
    lastRedirectTo = redirectTo;
    lastLaunchMode = authScreenLaunchMode;
    return true;
  }
}
