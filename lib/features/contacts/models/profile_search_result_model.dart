class ProfileSearchResultModel {
  const ProfileSearchResultModel({
    required this.id,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? handle;
  final String? avatarUrl;

  factory ProfileSearchResultModel.fromJson(Map<String, Object?> json) {
    return ProfileSearchResultModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      handle: json['handle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      if (handle != null) 'handle': handle,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}
