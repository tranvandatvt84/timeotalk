import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/core/database/app_database.dart';
import 'package:timeotalk/core/network/supabase_client_provider.dart';
import 'package:timeotalk/features/inbox/models/conversation_model.dart';

abstract class InboxRepository {
  Future<List<ConversationModel>> fetchRemoteConversations();

  Stream<List<ConversationModel>> watchLocalConversations();

  Future<void> syncConversations();
}

class SupabaseInboxRepository implements InboxRepository {
  SupabaseInboxRepository({
    SupabaseClient? client,
    AppDatabase? database,
    Future<AppDatabase> Function()? openDatabase,
    SupabaseClient Function()? clientProvider,
  }) : _client = client,
       _clientProvider =
           clientProvider ?? (() => SupabaseClientProvider.client),
       _database = database,
       _openDatabase = openDatabase ?? AppDatabase.open;

  final SupabaseClient? _client;
  final SupabaseClient Function() _clientProvider;
  final Future<AppDatabase> Function() _openDatabase;
  final _localUpdates = StreamController<List<ConversationModel>>.broadcast();

  AppDatabase? _database;
  Future<AppDatabase>? _openingDatabase;

  @override
  Future<List<ConversationModel>> fetchRemoteConversations() async {
    final client = _client ?? _clientProvider();
    final rows = await client
        .from('conversations')
        .select('id,type,title,created_by,created_at,updated_at')
        .order('updated_at', ascending: false);

    return rows
        .map(
          (row) => ConversationModel.fromJson(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Stream<List<ConversationModel>> watchLocalConversations() async* {
    yield await _readLocalConversations();
    yield* _localUpdates.stream;
  }

  @override
  Future<void> syncConversations() async {
    final conversations = await fetchRemoteConversations();
    await _writeLocalConversations(conversations);
    _localUpdates.add(await _readLocalConversations());
  }

  Future<List<ConversationModel>> _readLocalConversations() async {
    final database = await _localDatabase();
    final rows = await database.transaction((transaction) {
      return transaction.query(
        'local_conversations',
        orderBy: 'updated_at desc',
      );
    });

    return rows
        .map(
          (row) => ConversationModel.fromJson(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> _writeLocalConversations(
    List<ConversationModel> conversations,
  ) async {
    if (conversations.isEmpty) {
      return;
    }

    final database = await _localDatabase();
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      for (final conversation in conversations) {
        final updatedAt = (conversation.updatedAt ?? DateTime.now().toUtc())
            .toIso8601String();
        await transaction.insert('local_conversations', {
          'id': conversation.id,
          'type': conversation.type,
          'title': conversation.title,
          'last_message_preview': conversation.lastMessagePreview,
          'last_server_message_id': conversation.lastServerMessageId,
          'last_server_created_at': conversation.lastServerCreatedAt
              ?.toIso8601String(),
          'last_synced_at': now,
          'unread_count': conversation.unreadCount,
          'updated_at': updatedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await transaction.insert('sync_cursors', {
          'conversation_id': conversation.id,
          'last_server_message_id': conversation.lastServerMessageId,
          'last_server_created_at': conversation.lastServerCreatedAt
              ?.toIso8601String(),
          'last_synced_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<AppDatabase> _localDatabase() async {
    final existingDatabase = _database;
    if (existingDatabase != null) {
      return existingDatabase;
    }

    final openingDatabase = _openingDatabase ??= _openDatabase();
    final database = await openingDatabase;
    _database = database;
    return database;
  }
}
