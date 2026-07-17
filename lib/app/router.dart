import 'package:flutter/material.dart';
import 'package:timeotalk/app/main_shell.dart';
import 'package:timeotalk/features/auth/views/login_view.dart';
import 'package:timeotalk/features/auth/views/signup_view.dart';
import 'package:timeotalk/features/contacts/views/invitations_view.dart';

class AppRouter {
  const AppRouter._();

  static const login = '/login';
  static const signup = '/signup';
  static const inbox = '/inbox';
  static const contacts = '/contacts';
  static const profile = '/profile';
  static const invitations = '/invitations';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (_) => const LoginView(),
      signup: (_) => const SignupView(),
      inbox: (_) => const MainShell(),
      contacts: (_) => const MainShell(initialIndex: 1),
      profile: (_) => const MainShell(initialIndex: 2),
      invitations: (_) => const InvitationsView(),
    };
  }
}
