import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:timeotalk/features/auth/models/auth_user_model.dart';
import 'package:timeotalk/features/auth/repositories/auth_repository.dart';
import 'package:timeotalk/features/auth/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel', () {
    test('starts signed out when repository has no current user', () {
      final viewModel = AuthViewModel(authRepository: _FakeAuthRepository());

      expect(viewModel.state.user, isNull);
      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, isNull);
    });

    test('signIn updates state with authenticated user', () async {
      final repository = _FakeAuthRepository(
        signInUser: const AuthUserModel(
          id: 'user_123',
          email: 'dat@example.com',
          displayName: 'Dat Tran',
        ),
      );
      final viewModel = AuthViewModel(authRepository: repository);

      await viewModel.signIn(email: 'dat@example.com', password: 'password123');

      expect(repository.lastSignInEmail, 'dat@example.com');
      expect(repository.lastSignInPassword, 'password123');
      expect(viewModel.state.user?.id, 'user_123');
      expect(viewModel.state.isSignedIn, isTrue);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, isNull);
    });

    test('signIn failure stores an error and keeps user signed out', () async {
      final viewModel = AuthViewModel(
        authRepository: _FakeAuthRepository(
          signInError: Exception('Invalid login credentials'),
        ),
      );

      await viewModel.signIn(
        email: 'dat@example.com',
        password: 'wrong-password',
      );

      expect(viewModel.state.user, isNull);
      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.isLoading, isFalse);
      expect(
        viewModel.state.errorMessage,
        contains('Invalid login credentials'),
      );
    });

    test('signInWithGoogle starts OAuth and refreshes current user', () async {
      final repository = _FakeAuthRepository(
        oauthUser: const AuthUserModel(
          id: 'google_user',
          email: 'dat@gmail.com',
          displayName: 'Dat Tran',
        ),
      );
      final viewModel = AuthViewModel(authRepository: repository);

      await viewModel.signInWithGoogle();

      expect(repository.googleSignInCount, 1);
      expect(viewModel.state.user?.id, 'google_user');
      expect(viewModel.state.isSignedIn, isTrue);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, isNull);
    });

    test('signInWithApple failure stores an error', () async {
      final viewModel = AuthViewModel(
        authRepository: _FakeAuthRepository(
          appleSignInError: Exception('Apple sign-in cancelled'),
        ),
      );

      await viewModel.signInWithApple();

      expect(viewModel.state.user, isNull);
      expect(viewModel.state.isSignedIn, isFalse);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, contains('Apple sign-in cancelled'));
    });

    test('startListening follows auth state changes', () async {
      final repository = _FakeAuthRepository();
      final viewModel = AuthViewModel(authRepository: repository);

      viewModel.startListening();
      repository.emitAuthUser(
        const AuthUserModel(id: 'oauth_user', email: 'oauth@example.com'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.state.user?.id, 'oauth_user');
      expect(viewModel.state.isSignedIn, isTrue);

      repository.emitAuthUser(null);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.state.user, isNull);
      expect(viewModel.state.isSignedIn, isFalse);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.signInUser,
    this.signInError,
    this.oauthUser,
    this.appleSignInError,
  });

  final AuthUserModel? signInUser;
  final Object? signInError;
  final AuthUserModel? oauthUser;
  final Object? appleSignInError;

  String? lastSignInEmail;
  String? lastSignInPassword;
  int googleSignInCount = 0;
  int appleSignInCount = 0;
  AuthUserModel? _currentUser;
  final _authStateController = StreamController<AuthUserModel?>.broadcast();

  @override
  AuthUserModel? currentUser() => _currentUser;

  void emitAuthUser(AuthUserModel? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;

    final error = signInError;
    if (error != null) {
      throw error;
    }

    _currentUser =
        signInUser ?? AuthUserModel(id: 'fallback_user', email: email);
    return _currentUser!;
  }

  @override
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _currentUser = AuthUserModel(
      id: 'new_user',
      email: email,
      displayName: displayName,
    );
    return _currentUser!;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCount += 1;
    _currentUser = oauthUser;
  }

  @override
  Future<void> signInWithApple() async {
    appleSignInCount += 1;

    final error = appleSignInError;
    if (error != null) {
      throw error;
    }

    _currentUser = oauthUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Stream<AuthUserModel?> authStateChanges() {
    return _authStateController.stream;
  }
}
