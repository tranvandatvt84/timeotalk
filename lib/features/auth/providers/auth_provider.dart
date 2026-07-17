import 'package:flutter/widgets.dart';
import 'package:timeotalk/features/auth/viewmodels/auth_view_model.dart';

class AuthProvider extends InheritedNotifier<AuthViewModel> {
  const AuthProvider({
    required AuthViewModel viewModel,
    required super.child,
    super.key,
  }) : super(notifier: viewModel);

  static AuthViewModel of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AuthProvider>();
    if (provider == null || provider.notifier == null) {
      throw StateError('AuthProvider was not found in the widget tree.');
    }

    return provider.notifier!;
  }
}
