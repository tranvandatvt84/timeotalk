import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:timeotalk/features/auth/models/auth_user_model.dart';
import 'package:timeotalk/features/auth/repositories/auth_repository.dart';

class AuthViewState {
  const AuthViewState({this.user, this.isLoading = false, this.errorMessage});

  final AuthUserModel? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isSignedIn => user != null;

  AuthViewState copyWith({
    AuthUserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthViewState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository,
      _state = AuthViewState(user: authRepository.currentUser());

  final AuthRepository _authRepository;
  AuthViewState _state;
  StreamSubscription<AuthUserModel?>? _authStateSubscription;

  AuthViewState get state => _state;

  void startListening() {
    _authStateSubscription ??= _authRepository.authStateChanges().listen((
      user,
    ) {
      _setState(AuthViewState(user: user));
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));

    try {
      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );
      _setState(AuthViewState(user: user));
    } catch (error) {
      _setState(AuthViewState(errorMessage: error.toString()));
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));

    try {
      final user = await _authRepository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      _setState(AuthViewState(user: user));
    } catch (error) {
      _setState(AuthViewState(errorMessage: error.toString()));
    }
  }

  Future<void> signInWithGoogle() {
    return _signInWithOAuth(_authRepository.signInWithGoogle);
  }

  Future<void> signInWithApple() {
    return _signInWithOAuth(_authRepository.signInWithApple);
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _setState(const AuthViewState());
  }

  Future<void> _signInWithOAuth(Future<void> Function() startSignIn) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));

    try {
      await startSignIn();
      _setState(AuthViewState(user: _authRepository.currentUser()));
    } catch (error) {
      _setState(AuthViewState(errorMessage: error.toString()));
    }
  }

  void _setState(AuthViewState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
