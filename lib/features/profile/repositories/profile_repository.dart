import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/core/network/supabase_client_provider.dart';
import 'package:timeotalk/features/profile/models/profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel> fetchCurrentUserProfile();

  Future<ProfileModel> upsertCurrentUserProfile({
    required String displayName,
    String? avatarUrl,
    String? status,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({SupabaseClient? client})
    : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  @override
  Future<ProfileModel> fetchCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot fetch a profile without a signed-in user.');
    }

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      return upsertCurrentUserProfile(
        displayName: profileDisplayNameForUser(user),
        avatarUrl: _profileAvatarUrlForUser(user),
      );
    }

    return ProfileModel.fromJson(Map<String, Object?>.from(row));
  }

  @override
  Future<ProfileModel> upsertCurrentUserProfile({
    required String displayName,
    String? avatarUrl,
    String? status,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot upsert a profile without a signed-in user.');
    }

    final payload = <String, Object?>{
      'id': user.id,
      'display_name': displayName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (avatarUrl != null) {
      payload['avatar_url'] = avatarUrl;
    }
    if (status != null) {
      payload['status'] = status;
    }

    final row = await _client
        .from('profiles')
        .upsert(payload)
        .select()
        .single();

    return ProfileModel.fromJson(row);
  }
}

String profileDisplayNameForUser(User user) {
  final metadata = user.userMetadata ?? const <String, dynamic>{};
  final metadataName = _firstNonEmptyString([
    metadata['display_name'],
    metadata['full_name'],
    metadata['name'],
  ]);
  if (metadataName != null) {
    return metadataName;
  }

  final email = user.email?.trim();
  if (email != null && email.isNotEmpty) {
    final localPart = email.split('@').first.trim();
    if (localPart.isNotEmpty) {
      return localPart;
    }
  }

  return user.id;
}

String? _profileAvatarUrlForUser(User user) {
  final metadata = user.userMetadata ?? const <String, dynamic>{};
  return _firstNonEmptyString([metadata['avatar_url'], metadata['picture']]);
}

String? _firstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    if (value is! String) {
      continue;
    }

    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }

  return null;
}
