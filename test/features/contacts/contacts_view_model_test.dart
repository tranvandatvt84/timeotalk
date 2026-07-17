import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';
import 'package:timeotalk/features/contacts/repositories/contacts_repository.dart';
import 'package:timeotalk/features/contacts/viewmodels/contacts_view_model.dart';

void main() {
  group('ContactsViewModel', () {
    test('load fetches contacts and invitations', () async {
      final repository = _FakeContactsRepository(
        contacts: [
          const ContactModel(
            ownerId: 'user_1',
            contactUserId: 'friend_1',
            displayName: 'Alex',
          ),
        ],
        invitations: [_invitation(id: 'inv_1', status: 'pending')],
      );
      final viewModel = ContactsViewModel(repository: repository);

      await viewModel.load();

      expect(repository.fetchContactsCount, 1);
      expect(repository.fetchInvitationsCount, 1);
      expect(viewModel.state.contacts.single.contactUserId, 'friend_1');
      expect(viewModel.state.invitations.single.id, 'inv_1');
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, isNull);
    });

    test('load exposes repository errors', () async {
      final repository = _FakeContactsRepository(
        loadError: StateError('contacts unavailable'),
      );
      final viewModel = ContactsViewModel(repository: repository);

      await viewModel.load();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, contains('contacts unavailable'));
      expect(viewModel.state.contacts, isEmpty);
      expect(viewModel.state.invitations, isEmpty);
    });

    test('sendInvitation appends the created invitation', () async {
      final repository = _FakeContactsRepository(
        sentInvitation: _invitation(
          id: 'sent_1',
          receiverId: 'friend_2',
          status: 'pending',
        ),
      );
      final viewModel = ContactsViewModel(repository: repository);

      await viewModel.sendInvitation(
        receiverId: 'friend_2',
        message: 'Let us chat',
      );

      expect(repository.lastReceiverId, 'friend_2');
      expect(repository.lastMessage, 'Let us chat');
      expect(viewModel.state.invitations.single.id, 'sent_1');
      expect(viewModel.state.errorMessage, isNull);
    });

    test('acceptInvitation updates invitation status', () async {
      final repository = _FakeContactsRepository(
        invitations: [_invitation(id: 'inv_1', status: 'pending')],
        responseInvitation: _invitation(id: 'inv_1', status: 'accepted'),
      );
      final viewModel = ContactsViewModel(repository: repository);
      await viewModel.load();

      await viewModel.acceptInvitation('inv_1');

      expect(repository.lastInvitationId, 'inv_1');
      expect(repository.lastAction, InvitationResponseAction.accept);
      expect(viewModel.state.invitations.single.status, 'accepted');
      expect(viewModel.state.errorMessage, isNull);
    });

    test('declineInvitation updates invitation status', () async {
      final repository = _FakeContactsRepository(
        invitations: [_invitation(id: 'inv_1', status: 'pending')],
        responseInvitation: _invitation(id: 'inv_1', status: 'declined'),
      );
      final viewModel = ContactsViewModel(repository: repository);
      await viewModel.load();

      await viewModel.declineInvitation('inv_1');

      expect(repository.lastInvitationId, 'inv_1');
      expect(repository.lastAction, InvitationResponseAction.decline);
      expect(viewModel.state.invitations.single.status, 'declined');
      expect(viewModel.state.errorMessage, isNull);
    });
  });
}

InvitationModel _invitation({
  required String id,
  String senderId = 'sender_1',
  String receiverId = 'receiver_1',
  required String status,
}) {
  return InvitationModel(
    id: id,
    senderId: senderId,
    receiverId: receiverId,
    status: status,
    message: 'Hello',
  );
}

class _FakeContactsRepository implements ContactsRepository {
  _FakeContactsRepository({
    this.contacts = const [],
    this.invitations = const [],
    InvitationModel? sentInvitation,
    InvitationModel? responseInvitation,
    this.loadError,
  }) : sentInvitation =
           sentInvitation ??
           _invitation(id: 'sent_invitation', status: 'pending'),
       responseInvitation =
           responseInvitation ??
           _invitation(id: 'response_invitation', status: 'accepted');

  final List<ContactModel> contacts;
  final List<InvitationModel> invitations;
  final InvitationModel sentInvitation;
  final InvitationModel responseInvitation;
  final Object? loadError;

  int fetchContactsCount = 0;
  int fetchInvitationsCount = 0;
  String? lastReceiverId;
  String? lastMessage;
  String? lastInvitationId;
  InvitationResponseAction? lastAction;

  @override
  Future<List<ContactModel>> fetchContacts() async {
    fetchContactsCount += 1;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return contacts;
  }

  @override
  Future<List<InvitationModel>> fetchInvitations() async {
    fetchInvitationsCount += 1;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return invitations;
  }

  @override
  Future<InvitationModel> sendInvitation({
    required String receiverId,
    String? message,
  }) async {
    lastReceiverId = receiverId;
    lastMessage = message;
    return sentInvitation;
  }

  @override
  Future<InvitationModel> respondInvitation({
    required String invitationId,
    required InvitationResponseAction action,
  }) async {
    lastInvitationId = invitationId;
    lastAction = action;
    return responseInvitation;
  }
}
