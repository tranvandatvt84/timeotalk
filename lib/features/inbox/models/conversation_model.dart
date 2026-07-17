class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.type,
    this.title,
    this.createdBy,
    this.lastMessagePreview,
    this.lastServerMessageId,
    this.lastServerCreatedAt,
    this.lastSyncedAt,
    this.unreadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String? title;
  final String? createdBy;
  final String? lastMessagePreview;
  final String? lastServerMessageId;
  final DateTime? lastServerCreatedAt;
  final DateTime? lastSyncedAt;
  final int unreadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConversationModel.fromJson(Map<String, Object?> json) {
    return ConversationModel(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      createdBy: json['created_by'] as String?,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastServerMessageId: json['last_server_message_id'] as String?,
      lastServerCreatedAt: _dateTime(json['last_server_created_at']),
      lastSyncedAt: _dateTime(json['last_synced_at']),
      unreadCount: _asInt(json['unread_count']) ?? 0,
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type,
      if (title != null) 'title': title,
      if (createdBy != null) 'created_by': createdBy,
      if (lastMessagePreview != null)
        'last_message_preview': lastMessagePreview,
      if (lastServerMessageId != null)
        'last_server_message_id': lastServerMessageId,
      if (lastServerCreatedAt != null)
        'last_server_created_at': lastServerCreatedAt!.toIso8601String(),
      if (lastSyncedAt != null)
        'last_synced_at': lastSyncedAt!.toIso8601String(),
      'unread_count': unreadCount,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  ConversationModel copyWith({
    String? id,
    String? type,
    String? title,
    String? createdBy,
    String? lastMessagePreview,
    String? lastServerMessageId,
    DateTime? lastServerCreatedAt,
    DateTime? lastSyncedAt,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      createdBy: createdBy ?? this.createdBy,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastServerMessageId: lastServerMessageId ?? this.lastServerMessageId,
      lastServerCreatedAt: lastServerCreatedAt ?? this.lastServerCreatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
