import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase migrations', () {
    test('define the required backend tables', () {
      final initialSchema = File(
        'supabase/migrations/0001_initial_chat_schema.sql',
      );
      final contactSchema = File(
        'supabase/migrations/0002_contacts_invitations.sql',
      );

      expect(initialSchema.existsSync(), isTrue);
      expect(contactSchema.existsSync(), isTrue);

      final sql =
          '${initialSchema.readAsStringSync()}\n'
          '${contactSchema.readAsStringSync()}';

      for (final table in [
        'profiles',
        'conversations',
        'conversation_members',
        'messages',
        'attachments',
        'message_receipts',
        'devices',
        'invitations',
        'contacts',
      ]) {
        expect(sql, contains('create table $table'));
      }
    });

    test('define indexes and row level security policies', () {
      final rlsSchema = File('supabase/migrations/0003_rls_policies.sql');

      expect(rlsSchema.existsSync(), isTrue);

      final sql = rlsSchema.readAsStringSync();

      for (final table in [
        'profiles',
        'conversations',
        'conversation_members',
        'messages',
        'attachments',
        'message_receipts',
        'devices',
        'contacts',
        'invitations',
      ]) {
        expect(sql, contains('alter table $table enable row level security'));
      }

      for (final policy in [
        'conversation members can read conversations',
        'conversation members can read messages',
        'users can insert own devices',
        'users can update own devices',
        'users can read own contacts',
        'users can manage sent invitations',
        'users can read received invitations',
      ]) {
        expect(sql, contains(policy));
      }
    });

    test('defines searchable unique profile handles', () {
      final handleSchema = File('supabase/migrations/0004_profile_handles.sql');

      expect(handleSchema.existsSync(), isTrue);

      final sql = handleSchema.readAsStringSync();

      expect(sql, contains('alter table profiles'));
      expect(sql, contains('handle text'));
      expect(sql, contains('profiles_handle_format_check'));
      expect(sql, contains('handle = lower(handle)'));
      expect(sql, contains("handle ~ '^[a-z0-9_]{3,24}\$'"));
      expect(sql, contains('create unique index profiles_handle_unique_idx'));
      expect(sql, contains('where handle is not null'));
    });

    test('defines a safe user search edge function', () {
      final searchFunction = File('supabase/functions/search-users/index.ts');

      expect(searchFunction.existsSync(), isTrue);

      final source = searchFunction.readAsStringSync();

      expect(source, contains('SUPABASE_SERVICE_ROLE_KEY'));
      expect(source, contains('display_name,handle,avatar_url'));
      expect(source, contains('.neq("id", user.id)'));
      expect(source, contains('query.length < 2'));
      expect(source, contains('profiles'));
    });
  });
}
