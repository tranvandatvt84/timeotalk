import 'package:flutter/material.dart';
import 'package:timeotalk/app/main_shell.dart';
import 'package:timeotalk/features/auth/providers/auth_provider.dart';
import 'package:timeotalk/features/auth/views/login_view.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = AuthProvider.of(context);
    final state = viewModel.state;

    if (!state.isSignedIn) {
      return const LoginView();
    }

    return const MainShell();
  }
}
