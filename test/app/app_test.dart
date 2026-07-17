import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/app/app.dart';
import 'package:timeotalk/core/config/app_config.dart';

void main() {
  testWidgets('TimeoTalkApp renders the login view for signed-out users', (
    tester,
  ) async {
    const config = AppConfig(
      supabaseUrl: '',
      supabaseAnonKey: '',
      ablyTokenFunctionName: 'ably-token',
    );

    await tester.pumpWidget(const TimeoTalkApp(config: config));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });
}
