import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeotalk/core/database/app_database.dart';
import 'package:timeotalk/core/network/supabase_client_provider.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';

enum InvitationResponseAction {
  accept('accepted'),
  decline('declined');

  const InvitationResponseAction(this.status);

  final String status;
}

abstract class ContactsRepository {
  Future<List<ContactModel>> fetchContacts();

  Future<List<InvitationModel>> fetchInvitations();

  Future<InvitationModel> sendInvitation({
    required String receiverId,
    String? message,
  });

  Future<InvitationModel> respondInvitation({
    required String invitationId,
    required InvitationResponseAction action,
  });
}

class SupabaseContactsRepository implements ContactsRepository {
  SupabaseContactsRepository({SupabaseClient? client, AppDatabase? database})
    : _client = client ?? SupabaseClientProvider.client,
      _database = database;

  final SupabaseClient _client;
  final AppDatabase? _database;

  @override
  Future<List<ContactModel>> fetchContacts() async {
    final rows = await _client
        .from('contacts')
        .select()
        .order('updated_at', ascending: false);
    final contacts = rows.map(_contactFromRow).toList(growable: false);

    await _syncContacts(contacts);
    return contacts;
  }

  @override
  Future<List<InvitationModel>> fetchInvitations() async {
    final rows = await _client
        .from('invitations')
        .select()
        .order('created_at', ascending: false);
    final invitations = rows.map(_invitationFromRow).toList(growable: false);

    await _syncInvitations(invitations);
    return invitations;
  }

  @override
  Future<InvitationModel> sendInvitation({
    required String receiverId,
    String? message,
  }) async {
    final response = await _client.functions.invoke(
      'send-invitation',
      body: {
        'receiver_id': receiverId,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );

    final invitation = _invitationFromFunctionResponse(response);
    await _syncInvitations([invitation]);
    return invitation;
  }

  @override
  Future<InvitationModel> respondInvitation({
    required String invitationId,
    required InvitationResponseAction action,
  }) async {
    final response = await _client.functions.invoke(
      'respond-invitation',
      body: {'invitation_id': invitationId, 'action': action.status},
    );

    final invitation = _invitationFromFunctionResponse(response);
    await _syncInvitations([invitation]);
    return invitation;
  }

  ContactModel _contactFromRow(Map<String, dynamic> row) {
    return ContactModel.fromJson(Map<String, Object?>.from(row));
  }

  InvitationModel _invitationFromRow(Map<String, dynamic> row) {
    return InvitationModel.fromJson(Map<String, Object?>.from(row));
  }

  InvitationModel _invitationFromFunctionResponse(FunctionResponse response) {
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Invitation function failed with ${response.status}.');
    }

    final data = response.data;
    final invitationData = data is Map && data['invitation'] is Map
        ? data['invitation']
        : data;

    if (invitationData is! Map) {
      throw const FormatException('Invitation function did not return a row.');
    }

    return InvitationModel.fromJson(
      Map<String, Object?>.from(invitationData.cast<String, Object?>()),
    );
  }

  Future<void> _syncContacts(List<ContactModel> contacts) async {
    final database = _database;
    if (database == null || contacts.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      for (final contact in contacts) {
        await transaction.insert('local_contacts', {
          'owner_id': contact.ownerId,
          'contact_user_id': contact.contactUserId,
          'display_name':
              contact.displayName ?? contact.nickname ?? contact.contactUserId,
          'avatar_url': contact.avatarUrl,
          'nickname': contact.nickname,
          'favorite_at': contact.favoriteAt?.toIso8601String(),
          'blocked_at': contact.blockedAt?.toIso8601String(),
          'last_synced_at': now,
          'updated_at': (contact.updatedAt ?? DateTime.now().toUtc())
              .toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> _syncInvitations(List<InvitationModel> invitations) async {
    final database = _database;
    if (database == null || invitations.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      for (final invitation in invitations) {
        await transaction.insert('local_invitations', {
          'id': invitation.id,
          'sender_id': invitation.senderId,
          'receiver_id': invitation.receiverId,
          'status': invitation.status,
          'message': invitation.message,
          'created_at': (invitation.createdAt ?? DateTime.now().toUtc())
              .toIso8601String(),
          'responded_at': invitation.respondedAt?.toIso8601String(),
          'expires_at': invitation.expiresAt?.toIso8601String(),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
