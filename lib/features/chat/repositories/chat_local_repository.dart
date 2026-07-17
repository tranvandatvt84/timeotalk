import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:timeotalk/core/database/app_database.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/models/chat_receipt_model.dart';
import 'package:timeotalk/features/chat/repositories/chat_realtime_repository.dart';

class ChatLocalRepository {
  ChatLocalRepository({required AppDatabase database}) : _database = database;

  final AppDatabase _database;
  final _messageUpdates = StreamController<String>.broadcast();

  Stream<List<ChatMessageModel>> watchMessages(
    String conversationId, {
    bool includeInitial = true,
  }) async* {
    if (includeInitial) {
      yield await fetchMessages(conversationId);
    }
    yield* _messageUpdates.stream
        .where(
          (updatedConversationId) => updatedConversationId == conversationId,
        )
        .asyncMap((_) => fetchMessages(conversationId));
  }

  Future<List<ChatMessageModel>> fetchMessages(String conversationId) async {
    final rows = await _database.transaction((transaction) {
      return transaction.query(
        'local_messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'coalesce(server_created_at, client_created_at) asc',
      );
    });

    return rows
        .map(
          (row) =>
              ChatMessageModel.fromLocalRow(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  Future<ChatMessageModel> insertOutgoingMessage(
    ChatMessageModel message,
  ) async {
    await _database.transaction((transaction) {
      return transaction.insert(
        'local_messages',
        message.toLocalRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    _notifyConversation(message.conversationId);
    return message;
  }

  Future<ReceivedMessageResult> insertReceivedMessage(
    ChatMessageModel message,
  ) async {
    final existing = await fetchMessageByClientId(message.clientMessageId);
    if (existing != null) {
      return ReceivedMessageResult(message: existing, isNew: false);
    }

    final now = DateTime.now().toUtc();
    final received = ChatMessageModel(
      clientMessageId: message.clientMessageId,
      serverMessageId: message.serverMessageId,
      conversationId: message.conversationId,
      senderId: message.senderId ?? 'unknown',
      senderDeviceId: message.senderDeviceId,
      type: message.type,
      body: message.body,
      attachments: message.attachments,
      replyToMessageId: message.replyToMessageId,
      localStatus: message.localStatus ?? 'received',
      deliveryStatus: message.deliveryStatus,
      persistenceStatus: message.persistenceStatus,
      clientCreatedAt: message.clientCreatedAt ?? now,
      serverCreatedAt: message.serverCreatedAt,
      updatedAt: message.updatedAt ?? now,
    );

    await insertOutgoingMessage(received);
    return ReceivedMessageResult(message: received, isNew: true);
  }

  Future<void> markMessageSentRealtime(String clientMessageId) {
    return _updateLocalStatus(clientMessageId, 'sent_realtime');
  }

  Future<void> markMessageQueued(String clientMessageId) {
    return _updateLocalStatus(clientMessageId, 'queued_realtime');
  }

  Future<ChatMessageModel> mergePersistedMessage(
    ChatMessageModel message,
  ) async {
    final existing = await fetchMessageByClientId(message.clientMessageId);
    final merged = (existing ?? message).copyWith(
      serverMessageId: message.serverMessageId,
      senderId: message.senderId,
      senderDeviceId: message.senderDeviceId,
      type: message.type,
      body: message.body.isEmpty ? existing?.body : message.body,
      attachments: message.attachments.isEmpty
          ? existing?.attachments
          : message.attachments,
      deliveryStatus: message.deliveryStatus,
      persistenceStatus: 'persisted',
      serverCreatedAt: message.serverCreatedAt,
      updatedAt: message.updatedAt ?? DateTime.now().toUtc(),
    );

    await insertOutgoingMessage(merged);
    return merged;
  }

  Future<ChatMessageModel> mergeRejectedMessage(
    ChatMessageModel message, {
    String? errorMessage,
  }) async {
    final existing = await fetchMessageByClientId(message.clientMessageId);
    final merged = (existing ?? message).copyWith(
      localStatus: 'rejected',
      persistenceStatus: 'rejected',
      updatedAt: message.updatedAt ?? DateTime.now().toUtc(),
    );

    await insertOutgoingMessage(merged);
    return merged;
  }

  Future<ChatMessageModel?> fetchMessageByClientId(
    String clientMessageId,
  ) async {
    final rows = await _database.transaction((transaction) {
      return transaction.query(
        'local_messages',
        where: 'client_message_id = ?',
        whereArgs: [clientMessageId],
        limit: 1,
      );
    });

    if (rows.isEmpty) {
      return null;
    }

    return ChatMessageModel.fromLocalRow(
      Map<String, Object?>.from(rows.single),
    );
  }

  Future<ChatMessageModel?> fetchMessageByServerId(
    String serverMessageId,
  ) async {
    final rows = await _database.transaction((transaction) {
      return transaction.query(
        'local_messages',
        where: 'server_message_id = ?',
        whereArgs: [serverMessageId],
        limit: 1,
      );
    });

    if (rows.isEmpty) {
      return null;
    }

    return ChatMessageModel.fromLocalRow(
      Map<String, Object?>.from(rows.single),
    );
  }

  Future<ChatMessageModel?> applyReceipt(ChatReceiptModel receipt) async {
    final message = receipt.clientMessageId != null
        ? await fetchMessageByClientId(receipt.clientMessageId!)
        : receipt.messageId != null
        ? await fetchMessageByServerId(receipt.messageId!)
        : null;
    if (message == null) {
      return null;
    }

    final updated = message.copyWith(
      deliveryStatus: _strongerDeliveryStatus(
        message.deliveryStatus,
        receipt.status,
      ),
      updatedAt: receipt.createdAt ?? DateTime.now().toUtc(),
    );
    await insertOutgoingMessage(updated);
    return updated;
  }

  Future<void> enqueueOutgoingMessage(
    ChatMessageModel message, {
    String? lastError,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((transaction) {
      return transaction.insert('outgoing_queue', {
        'id': message.clientMessageId,
        'client_message_id': message.clientMessageId,
        'conversation_id': message.conversationId,
        'payload_json': jsonEncode(messageCreatedPayload(message)),
        'attempt_count': 0,
        'next_attempt_at': null,
        'last_error': lastError,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<OutgoingQueueEntry>> fetchOutgoingQueue() async {
    final rows = await _database.transaction((transaction) {
      return transaction.query('outgoing_queue', orderBy: 'created_at asc');
    });

    return rows
        .map(
          (row) =>
              OutgoingQueueEntry.fromLocalRow(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> deleteOutgoingQueueEntry(String id) {
    return _database.transaction((transaction) {
      return transaction.delete(
        'outgoing_queue',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> recordOutgoingQueueFailure({
    required String id,
    required Object error,
  }) {
    return _database.transaction((transaction) {
      return transaction.rawUpdate(
        '''
update outgoing_queue
set attempt_count = attempt_count + 1,
    last_error = ?
where id = ?
''',
        [error.toString(), id],
      );
    });
  }

  Future<void> _updateLocalStatus(
    String clientMessageId,
    String localStatus,
  ) async {
    await _database.transaction((transaction) {
      return transaction.update(
        'local_messages',
        {
          'local_status': localStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'client_message_id = ?',
        whereArgs: [clientMessageId],
      );
    });

    final message = await fetchMessageByClientId(clientMessageId);
    if (message != null) {
      _notifyConversation(message.conversationId);
    }
  }

  void _notifyConversation(String conversationId) {
    if (!_messageUpdates.isClosed) {
      _messageUpdates.add(conversationId);
    }
  }
}

class ReceivedMessageResult {
  const ReceivedMessageResult({required this.message, required this.isNew});

  final ChatMessageModel message;
  final bool isNew;
}

class OutgoingQueue {
  OutgoingQueue({
    required ChatLocalRepository localRepository,
    required ChatRealtimeRepository realtimeRepository,
  }) : _localRepository = localRepository,
       _realtimeRepository = realtimeRepository;

  final ChatLocalRepository _localRepository;
  final ChatRealtimeRepository _realtimeRepository;

  Future<void> flush() async {
    final entries = await _localRepository.fetchOutgoingQueue();

    for (final entry in entries) {
      try {
        final message = ChatMessageModel.fromJson(entry.payload);
        await _realtimeRepository.publishMessageCreated(message);
        await _localRepository.markMessageSentRealtime(message.clientMessageId);
        await _localRepository.deleteOutgoingQueueEntry(entry.id);
      } catch (error) {
        await _localRepository.recordOutgoingQueueFailure(
          id: entry.id,
          error: error,
        );
      }
    }
  }
}

class OutgoingQueueEntry {
  const OutgoingQueueEntry({
    required this.id,
    required this.clientMessageId,
    required this.conversationId,
    required this.payload,
    required this.attemptCount,
    this.lastError,
    this.createdAt,
  });

  final String id;
  final String clientMessageId;
  final String conversationId;
  final Map<String, Object?> payload;
  final int attemptCount;
  final String? lastError;
  final DateTime? createdAt;

  factory OutgoingQueueEntry.fromLocalRow(Map<String, Object?> row) {
    return OutgoingQueueEntry(
      id: row['id'] as String,
      clientMessageId: row['client_message_id'] as String,
      conversationId: row['conversation_id'] as String,
      payload: Map<String, Object?>.from(
        (jsonDecode(row['payload_json'] as String) as Map)
            .cast<String, Object?>(),
      ),
      attemptCount: _asInt(row['attempt_count']) ?? 0,
      lastError: row['last_error'] as String?,
      createdAt: _dateTime(row['created_at']),
    );
  }
}

int? _asInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.parse(value.toString());
}

DateTime? _dateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.parse(value.toString());
}

String _strongerDeliveryStatus(String? current, String next) {
  const priority = {'delivered': 1, 'read': 2};
  final currentPriority = priority[current] ?? 0;
  final nextPriority = priority[next] ?? 0;
  return nextPriority >= currentPriority ? next : current ?? next;
}
