import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';
import 'package:timeotalk/features/contacts/models/profile_search_result_model.dart';
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

    test('searchProfiles exposes loading state, query, and results', () async {
      final repository = _FakeContactsRepository(
        searchResults: [
          const ProfileSearchResultModel(
            id: 'profile_1',
            displayName: 'Alex Rivera',
            handle: 'alex',
          ),
        ],
      );
      final viewModel = ContactsViewModel(repository: repository);

      final future = viewModel.searchProfiles(' @Alex ');

      expect(viewModel.state.isSearching, isTrue);
      expect(viewModel.state.searchQuery, 'alex');

      await future;

      expect(repository.lastSearchQuery, 'alex');
      expect(viewModel.state.isSearching, isFalse);
      expect(viewModel.state.searchResults.single.handle, 'alex');
      expect(viewModel.state.searchErrorMessage, isNull);
    });

    test('searchProfiles clears results for short queries', () async {
      final repository = _FakeContactsRepository(
        searchResults: [
          const ProfileSearchResultModel(
            id: 'profile_1',
            displayName: 'Alex Rivera',
            handle: 'alex',
          ),
        ],
      );
      final viewModel = ContactsViewModel(repository: repository);

      await viewModel.searchProfiles('alex');
      await viewModel.searchProfiles('a');

      expect(repository.searchCount, 1);
      expect(viewModel.state.searchResults, isEmpty);
      expect(viewModel.state.searchQuery, 'a');
    });

    test('searchProfiles exposes repository errors', () async {
      final repository = _FakeContactsRepository(
        searchError: StateError('search unavailable'),
      );
      final viewModel = ContactsViewModel(repository: repository);

      await viewModel.searchProfiles('alex');

      expect(viewModel.state.isSearching, isFalse);
      expect(
        viewModel.state.searchErrorMessage,
        contains('search unavailable'),
      );
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
    this.searchResults = const [],
    this.searchError,
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
  final List<ProfileSearchResultModel> searchResults;
  final Object? searchError;

  int fetchContactsCount = 0;
  int fetchInvitationsCount = 0;
  int searchCount = 0;
  String? lastReceiverId;
  String? lastMessage;
  String? lastInvitationId;
  String? lastSearchQuery;
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
  Future<List<ProfileSearchResultModel>> searchProfiles(String query) async {
    searchCount += 1;
    lastSearchQuery = query;
    final error = searchError;
    if (error != null) {
      throw error;
    }
    return searchResults;
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
