import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/features/profile/repositories/profile_repository.dart';

void main() {
  group('profileDisplayNameForUser', () {
    test('uses profile metadata before email fallback', () {
      final user = _user(
        email: 'dat@example.com',
        metadata: {'display_name': 'Dat Tran'},
      );

      expect(profileDisplayNameForUser(user), 'Dat Tran');
    });

    test('uses OAuth full name when display name is missing', () {
      final user = _user(
        email: 'dat@example.com',
        metadata: {'full_name': 'Dat OAuth'},
      );

      expect(profileDisplayNameForUser(user), 'Dat OAuth');
    });

    test('uses email prefix when OAuth metadata is missing', () {
      final user = _user(email: 'dat@example.com');

      expect(profileDisplayNameForUser(user), 'dat');
    });
  });
}

User _user({String? email, Map<String, dynamic>? metadata}) {
  return User(
    id: 'user_1',
    appMetadata: const {},
    userMetadata: metadata,
    aud: 'authenticated',
    email: email,
    createdAt: DateTime.utc(2026).toIso8601String(),
  );
}
