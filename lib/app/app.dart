import 'package:flutter/material.dart';
import 'package:timeotalk/app/router.dart';
import 'package:timeotalk/app/theme.dart';
import 'package:timeotalk/core/config/app_config.dart';
import 'package:timeotalk/features/auth/models/auth_user_model.dart';
import 'package:timeotalk/features/auth/providers/auth_provider.dart';
import 'package:timeotalk/features/auth/repositories/auth_repository.dart';
import 'package:timeotalk/features/auth/viewmodels/auth_view_model.dart';
import 'package:timeotalk/features/auth/views/auth_gate.dart';

class TimeoTalkApp extends StatefulWidget {
  const TimeoTalkApp({required this.config, this.authViewModel, super.key});

  final AppConfig config;
  final AuthViewModel? authViewModel;

  @override
  State<TimeoTalkApp> createState() => _TimeoTalkAppState();
}

class _TimeoTalkAppState extends State<TimeoTalkApp> {
  late final AuthViewModel _authViewModel;
  late final bool _ownsAuthViewModel;

  @override
  void initState() {
    super.initState();
    _ownsAuthViewModel = widget.authViewModel == null;
    _authViewModel =
        widget.authViewModel ??
        AuthViewModel(authRepository: _createAuthRepository());
    _authViewModel.startListening();
  }

  @override
  void dispose() {
    if (_ownsAuthViewModel) {
      _authViewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthProvider(
      viewModel: _authViewModel,
      child: MaterialApp(
        title: 'TimeoTalk',
        theme: TimeoTalkTheme.light,
        home: const AuthGate(),
        routes: AppRouter.routes,
      ),
    );
  }

  AuthRepository _createAuthRepository() {
    if (widget.config.hasSupabaseCredentials) {
      return SupabaseAuthRepository();
    }

    return const _UnavailableAuthRepository();
  }
}

class _UnavailableAuthRepository implements AuthRepository {
  const _UnavailableAuthRepository();

  @override
  AuthUserModel? currentUser() => null;

  @override
  Stream<AuthUserModel?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) {
    throw StateError('Supabase credentials are not configured.');
  }

  @override
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    throw StateError('Supabase credentials are not configured.');
  }

  @override
  Future<void> signInWithGoogle() {
    throw StateError('Supabase credentials are not configured.');
  }

  @override
  Future<void> signInWithApple() {
    throw StateError('Supabase credentials are not configured.');
  }

  @override
  Future<void> signOut() async {}
}
