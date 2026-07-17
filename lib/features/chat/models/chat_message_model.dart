import 'dart:convert';

import 'package:timeotalk/features/chat/models/chat_attachment_model.dart';

class ChatMessageModel {
  const ChatMessageModel({
    required this.clientMessageId,
    required this.conversationId,
    required this.type,
    required this.body,
    required this.attachments,
    required this.persistenceStatus,
    this.serverMessageId,
    this.senderId,
    this.senderDeviceId,
    this.replyToMessageId,
    this.localStatus,
    this.deliveryStatus,
    this.clientCreatedAt,
    this.serverCreatedAt,
    this.updatedAt,
  });

  final String clientMessageId;
  final String? serverMessageId;
  final String conversationId;
  final String? senderId;
  final String? senderDeviceId;
  final String type;
  final Map<String, Object?> body;
  final List<ChatAttachmentModel> attachments;
  final String? replyToMessageId;
  final String? localStatus;
  final String? deliveryStatus;
  final String persistenceStatus;
  final DateTime? clientCreatedAt;
  final DateTime? serverCreatedAt;
  final DateTime? updatedAt;

  factory ChatMessageModel.fromJson(Map<String, Object?> json) {
    final event = json['event'] as String?;
    final isPersistedEvent = event == 'message.persisted';

    return ChatMessageModel(
      clientMessageId: json['client_message_id'] as String,
      serverMessageId: json['server_message_id'] as String?,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String?,
      senderDeviceId: json['sender_device_id'] as String?,
      type: json['type'] as String? ?? 'status',
      body: _bodyFromJson(json['body']),
      attachments: _attachmentsFromJson(json['attachments']),
      replyToMessageId:
          json['reply_to_message_id'] as String? ?? json['reply_to'] as String?,
      localStatus: json['local_status'] as String?,
      deliveryStatus: json['delivery_status'] as String?,
      persistenceStatus:
          json['persistence_status'] as String? ??
          (isPersistedEvent ? 'persisted' : 'pending'),
      clientCreatedAt: _dateTime(json['client_created_at']),
      serverCreatedAt: _dateTime(json['server_created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  factory ChatMessageModel.fromLocalRow(Map<String, Object?> row) {
    return ChatMessageModel(
      clientMessageId: row['client_message_id'] as String,
      serverMessageId: row['server_message_id'] as String?,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String?,
      senderDeviceId: row['sender_device_id'] as String?,
      type: row['type'] as String,
      body: _bodyFromJson(_decodeJson(row['body_json'] as String?)),
      attachments: _attachmentsFromJson(
        _decodeJson(row['attachments_json'] as String?),
      ),
      localStatus: row['local_status'] as String?,
      deliveryStatus: row['delivery_status'] as String?,
      persistenceStatus: row['persistence_status'] as String? ?? 'pending',
      clientCreatedAt: _dateTime(row['client_created_at']),
      serverCreatedAt: _dateTime(row['server_created_at']),
      updatedAt: _dateTime(row['updated_at']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'client_message_id': clientMessageId,
      if (serverMessageId != null) 'server_message_id': serverMessageId,
      'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (senderDeviceId != null) 'sender_device_id': senderDeviceId,
      'type': type,
      'body': body,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (localStatus != null) 'local_status': localStatus,
      if (deliveryStatus != null) 'delivery_status': deliveryStatus,
      'persistence_status': persistenceStatus,
      if (clientCreatedAt != null)
        'client_created_at': clientCreatedAt!.toIso8601String(),
      if (serverCreatedAt != null)
        'server_created_at': serverCreatedAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Map<String, Object?> toLocalRow() {
    return {
      'client_message_id': clientMessageId,
      'server_message_id': serverMessageId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_device_id': senderDeviceId,
      'type': type,
      'body_json': jsonEncode(body),
      'attachments_json': jsonEncode(
        attachments.map((attachment) => attachment.toJson()).toList(),
      ),
      'local_status': localStatus,
      'delivery_status': deliveryStatus,
      'persistence_status': persistenceStatus,
      'client_created_at': clientCreatedAt?.toIso8601String(),
      'server_created_at': serverCreatedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ChatMessageModel copyWith({
    String? clientMessageId,
    String? serverMessageId,
    String? conversationId,
    String? senderId,
    String? senderDeviceId,
    String? type,
    Map<String, Object?>? body,
    List<ChatAttachmentModel>? attachments,
    String? replyToMessageId,
    String? localStatus,
    String? deliveryStatus,
    String? persistenceStatus,
    DateTime? clientCreatedAt,
    DateTime? serverCreatedAt,
    DateTime? updatedAt,
  }) {
    return ChatMessageModel(
      clientMessageId: clientMessageId ?? this.clientMessageId,
      serverMessageId: serverMessageId ?? this.serverMessageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      type: type ?? this.type,
      body: body ?? this.body,
      attachments: attachments ?? this.attachments,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      localStatus: localStatus ?? this.localStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      persistenceStatus: persistenceStatus ?? this.persistenceStatus,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

Object? _decodeJson(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return jsonDecode(value);
}

Map<String, Object?> _bodyFromJson(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return const {};
}

List<ChatAttachmentModel> _attachmentsFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map(
        (attachment) => ChatAttachmentModel.fromJson(
          attachment.map((key, entry) => MapEntry(key.toString(), entry)),
        ),
      )
      .toList();
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
