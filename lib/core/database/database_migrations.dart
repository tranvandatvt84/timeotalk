import 'package:sqflite/sqflite.dart';

class DatabaseMigrations {
  const DatabaseMigrations._();

  static const currentVersion = 1;

  static const createStatements = [
    '''
create table local_conversations (
  id text primary key,
  type text not null,
  title text,
  last_message_preview text,
  last_server_message_id text,
  last_server_created_at text,
  last_synced_at text,
  unread_count integer not null default 0,
  updated_at text not null
)
''',
    '''
create table local_messages (
  client_message_id text primary key,
  server_message_id text,
  conversation_id text not null,
  sender_id text not null,
  sender_device_id text,
  type text not null,
  body_json text not null,
  attachments_json text not null default '[]',
  local_status text not null,
  delivery_status text,
  persistence_status text not null,
  client_created_at text not null,
  server_created_at text,
  updated_at text not null
)
''',
    '''
create table local_contacts (
  owner_id text not null,
  contact_user_id text not null,
  display_name text not null,
  avatar_url text,
  nickname text,
  favorite_at text,
  blocked_at text,
  last_synced_at text,
  updated_at text not null,
  primary key (owner_id, contact_user_id)
)
''',
    '''
create table local_invitations (
  id text primary key,
  sender_id text not null,
  receiver_id text not null,
  status text not null,
  message text,
  created_at text not null,
  responded_at text,
  expires_at text,
  updated_at text not null
)
''',
    '''
create table outgoing_queue (
  id text primary key,
  client_message_id text not null,
  conversation_id text not null,
  payload_json text not null,
  attempt_count integer not null default 0,
  next_attempt_at text,
  last_error text,
  created_at text not null
)
''',
    '''
create table sync_cursors (
  conversation_id text primary key,
  last_server_message_id text,
  last_server_created_at text,
  last_synced_at text
)
''',
  ];

  static Future<void> create(Database database) async {
    final batch = database.batch();

    for (final statement in createStatements) {
      batch.execute(statement);
    }

    await batch.commit(noResult: true);
  }
}
