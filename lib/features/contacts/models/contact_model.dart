class ContactModel {
  const ContactModel({
    this.id,
    required this.ownerId,
    required this.contactUserId,
    this.createdFromInvitationId,
    this.displayName,
    this.avatarUrl,
    this.nickname,
    this.favoriteAt,
    this.blockedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String ownerId;
  final String contactUserId;
  final String? createdFromInvitationId;
  final String? displayName;
  final String? avatarUrl;
  final String? nickname;
  final DateTime? favoriteAt;
  final DateTime? blockedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ContactModel.fromJson(Map<String, Object?> json) {
    return ContactModel(
      id: json['id'] as String?,
      ownerId: json['owner_id'] as String,
      contactUserId: json['contact_user_id'] as String,
      createdFromInvitationId: json['created_from_invitation_id'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      nickname: json['nickname'] as String?,
      favoriteAt: _dateTime(json['favorite_at']),
      blockedAt: _dateTime(json['blocked_at']),
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (id != null) 'id': id,
      'owner_id': ownerId,
      'contact_user_id': contactUserId,
      if (createdFromInvitationId != null)
        'created_from_invitation_id': createdFromInvitationId,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (nickname != null) 'nickname': nickname,
      if (favoriteAt != null) 'favorite_at': favoriteAt!.toIso8601String(),
      if (blockedAt != null) 'blocked_at': blockedAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  ContactModel copyWith({
    String? id,
    String? ownerId,
    String? contactUserId,
    String? createdFromInvitationId,
    String? displayName,
    String? avatarUrl,
    String? nickname,
    DateTime? favoriteAt,
    DateTime? blockedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      contactUserId: contactUserId ?? this.contactUserId,
      createdFromInvitationId:
          createdFromInvitationId ?? this.createdFromInvitationId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      nickname: nickname ?? this.nickname,
      favoriteAt: favoriteAt ?? this.favoriteAt,
      blockedAt: blockedAt ?? this.blockedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
