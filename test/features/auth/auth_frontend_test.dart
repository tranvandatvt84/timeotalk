import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/auth/models/auth_user_model.dart';
import 'package:timeotalk/features/auth/providers/auth_provider.dart';
import 'package:timeotalk/features/auth/repositories/auth_repository.dart';
import 'package:timeotalk/features/auth/viewmodels/auth_view_model.dart';
import 'package:timeotalk/features/auth/views/auth_gate.dart';
import 'package:timeotalk/features/auth/views/login_view.dart';
import 'package:timeotalk/features/auth/views/signup_view.dart';

void main() {
  group('auth frontend', () {
    testWidgets('login form submits email and password', (tester) async {
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(_authHarness(repository, const LoginView()));

      await tester.enterText(find.byType(TextField).at(0), 'dat@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(repository.lastSignInEmail, 'dat@example.com');
      expect(repository.lastSignInPassword, 'password123');
    });

    testWidgets('login social buttons start OAuth', (tester) async {
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(_authHarness(repository, const LoginView()));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();

      expect(repository.googleSignInCount, 1);
      expect(repository.appleSignInCount, 1);
    });

    testWidgets('signup form submits account details', (tester) async {
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(_authHarness(repository, const SignupView()));

      await tester.enterText(find.byType(TextField).at(0), 'Dat Tran');
      await tester.enterText(find.byType(TextField).at(1), 'dat@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Sign up'));
      await tester.pump();

      expect(repository.lastSignUpDisplayName, 'Dat Tran');
      expect(repository.lastSignUpEmail, 'dat@example.com');
      expect(repository.lastSignUpPassword, 'password123');
    });

    testWidgets('auth gate shows inbox after auth state signs in', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      final viewModel = AuthViewModel(authRepository: repository)
        ..startListening();

      await tester.pumpWidget(
        MaterialApp(
          home: AuthProvider(viewModel: viewModel, child: const AuthGate()),
        ),
      );

      expect(find.text('Welcome back'), findsOneWidget);

      repository.emitAuthUser(
        const AuthUserModel(id: 'user_1', email: 'dat@example.com'),
      );
      await tester.pump();

      expect(find.byKey(const Key('tab-screen-inbox')), findsOneWidget);
    });

    testWidgets('signup screen shows inbox after auth state signs in', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      final viewModel = AuthViewModel(authRepository: repository)
        ..startListening();

      await tester.pumpWidget(
        MaterialApp(
          home: AuthProvider(viewModel: viewModel, child: const SignupView()),
        ),
      );

      expect(find.text('Create account'), findsOneWidget);

      repository.emitAuthUser(
        const AuthUserModel(id: 'user_1', email: 'dat@example.com'),
      );
      await tester.pump();

      expect(find.byKey(const Key('tab-screen-inbox')), findsOneWidget);
    });
  });
}

Widget _authHarness(_FakeAuthRepository repository, Widget child) {
  final viewModel = AuthViewModel(authRepository: repository);
  return MaterialApp(
    home: AuthProvider(viewModel: viewModel, child: child),
  );
}

class _FakeAuthRepository implements AuthRepository {
  final _authStateController = StreamController<AuthUserModel?>.broadcast();

  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastSignUpEmail;
  String? lastSignUpPassword;
  String? lastSignUpDisplayName;
  int googleSignInCount = 0;
  int appleSignInCount = 0;
  AuthUserModel? _currentUser;

  void emitAuthUser(AuthUserModel? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  @override
  AuthUserModel? currentUser() => _currentUser;

  @override
  Stream<AuthUserModel?> authStateChanges() => _authStateController.stream;

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    _currentUser = AuthUserModel(id: 'signed_in', email: email);
    return _currentUser!;
  }

  @override
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    lastSignUpEmail = email;
    lastSignUpPassword = password;
    lastSignUpDisplayName = displayName;
    _currentUser = AuthUserModel(
      id: 'signed_up',
      email: email,
      displayName: displayName,
    );
    return _currentUser!;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCount += 1;
  }

  @override
  Future<void> signInWithApple() async {
    appleSignInCount += 1;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}
