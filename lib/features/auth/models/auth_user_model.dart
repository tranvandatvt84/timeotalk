import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUserModel {
  const AuthUserModel({required this.id, this.email, this.displayName});

  final String id;
  final String? email;
  final String? displayName;

  factory AuthUserModel.fromSupabaseUser(User user) {
    return AuthUserModel(
      id: user.id,
      email: user.email,
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }

  factory AuthUserModel.fromJson(Map<String, Object?> json) {
    return AuthUserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
    };
  }

  AuthUserModel copyWith({String? id, String? email, String? displayName}) {
    return AuthUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }
}
