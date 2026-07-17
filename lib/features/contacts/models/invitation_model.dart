class InvitationModel {
  const InvitationModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    this.message,
    this.createdAt,
    this.respondedAt,
    this.expiresAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final String? message;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? expiresAt;

  factory InvitationModel.fromJson(Map<String, Object?> json) {
    return InvitationModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      createdAt: _dateTime(json['created_at']),
      respondedAt: _dateTime(json['responded_at']),
      expiresAt: _dateTime(json['expires_at']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      if (message != null) 'message': message,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (respondedAt != null) 'responded_at': respondedAt!.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    };
  }

  InvitationModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? status,
    String? message,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? expiresAt,
  }) {
    return InvitationModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt ?? this.expiresAt,
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
