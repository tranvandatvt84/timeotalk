class ChatReceiptModel {
  const ChatReceiptModel({
    this.messageId,
    this.clientMessageId,
    required this.userId,
    required this.status,
    this.createdAt,
  });

  final String? messageId;
  final String? clientMessageId;
  final String userId;
  final String status;
  final DateTime? createdAt;

  factory ChatReceiptModel.fromJson(Map<String, Object?> json) {
    return ChatReceiptModel(
      messageId: json['message_id'] as String?,
      clientMessageId: json['client_message_id'] as String?,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      createdAt: _dateTime(json['created_at']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (messageId != null) 'message_id': messageId,
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      'user_id': userId,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ChatReceiptModel copyWith({
    String? messageId,
    String? clientMessageId,
    String? userId,
    String? status,
    DateTime? createdAt,
  }) {
    return ChatReceiptModel(
      messageId: messageId ?? this.messageId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
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
