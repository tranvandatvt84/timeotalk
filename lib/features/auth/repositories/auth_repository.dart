import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/core/network/supabase_client_provider.dart';
import 'package:timeotalk/features/auth/models/auth_user_model.dart';
import 'package:timeotalk/features/profile/repositories/profile_repository.dart';

abstract class AuthRepository {
  AuthUserModel? currentUser();

  Stream<AuthUserModel?> authStateChanges();

  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  });

  Future<AuthUserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    SupabaseClient? client,
    ProfileRepository? profileRepository,
    String? oauthRedirectTo,
    OAuthSignInLauncher? oauthLauncher,
  }) : _client = client ?? SupabaseClientProvider.client,
       _profileRepository = profileRepository,
       _oauthRedirectTo =
           oauthRedirectTo ??
           const String.fromEnvironment(
             'AUTH_REDIRECT_URI',
             defaultValue: 'io.supabase.timeotalk://login-callback',
           ),
       _oauthLauncher =
           oauthLauncher ??
           SupabaseOAuthSignInLauncher(client ?? SupabaseClientProvider.client);

  final SupabaseClient _client;
  final ProfileRepository? _profileRepository;
  final String _oauthRedirectTo;
  final OAuthSignInLauncher _oauthLauncher;

  @override
  AuthUserModel? currentUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return AuthUserModel.fromSupabaseUser(user);
  }

  @override
  Stream<AuthUserModel?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((authState) {
      final user = authState.session?.user;
      if (user == null) {
        return null;
      }
      return AuthUserModel.fromSupabaseUser(user);
    });
  }

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw StateError('Supabase sign-in did not return a user.');
    }

    return AuthUserModel.fromSupabaseUser(user);
  }

  @override
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    final user = response.user;
    if (user == null) {
      throw StateError('Supabase sign-up did not return a user.');
    }

    final profileRepository =
        _profileRepository ?? SupabaseProfileRepository(client: _client);
    await profileRepository.upsertCurrentUserProfile(displayName: displayName);

    return AuthUserModel.fromSupabaseUser(
      user,
    ).copyWith(displayName: displayName);
  }

  @override
  Future<void> signInWithGoogle() {
    return _signInWithOAuth(OAuthProvider.google);
  }

  @override
  Future<void> signInWithApple() {
    return _signInWithOAuth(OAuthProvider.apple);
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    final launched = await _oauthLauncher.signInWithOAuth(
      provider,
      redirectTo: _oauthRedirectTo.isEmpty ? null : _oauthRedirectTo,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw StateError('Could not launch ${provider.name} sign-in.');
    }
  }
}

abstract class OAuthSignInLauncher {
  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
    required LaunchMode authScreenLaunchMode,
  });
}

class SupabaseOAuthSignInLauncher implements OAuthSignInLauncher {
  const SupabaseOAuthSignInLauncher(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
    required LaunchMode authScreenLaunchMode,
  }) {
    return _client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
      authScreenLaunchMode: authScreenLaunchMode,
    );
  }
}
