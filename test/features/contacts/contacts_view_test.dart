import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';
import 'package:timeotalk/features/contacts/models/profile_search_result_model.dart';
import 'package:timeotalk/features/contacts/repositories/contacts_repository.dart';
import 'package:timeotalk/features/contacts/viewmodels/contacts_view_model.dart';
import 'package:timeotalk/features/contacts/views/contacts_view.dart';
import 'package:timeotalk/features/contacts/views/invitations_view.dart';

void main() {
  testWidgets('contacts view shows loading state', (tester) async {
    final repository = _FakeContactsRepository(
      contactsCompleter: Completer<List<ContactModel>>(),
    );
    final viewModel = ContactsViewModel(repository: repository);

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pump();

    expect(find.byKey(const Key('contacts-view')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('contacts view shows empty state without nested app bar', (
    tester,
  ) async {
    final viewModel = ContactsViewModel(repository: _FakeContactsRepository());

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('No contacts yet'), findsOneWidget);
    expect(find.byKey(const Key('contacts-search-users')), findsOneWidget);
  });

  testWidgets('contacts view renders populated contacts', (tester) async {
    final viewModel = ContactsViewModel(
      repository: _FakeContactsRepository(
        contacts: [
          const ContactModel(
            ownerId: 'user_1',
            contactUserId: 'friend_1',
            displayName: 'Alex Rivera',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('friend_1'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
  });

  testWidgets('contacts view searches users and sends invitation from result', (
    tester,
  ) async {
    final repository = _FakeContactsRepository(
      searchResults: [
        const ProfileSearchResultModel(
          id: 'friend_2',
          displayName: 'Mia Chen',
          handle: 'mia',
        ),
      ],
      sentInvitation: _invitation(id: 'sent_1', receiverId: 'friend_2'),
    );
    final viewModel = ContactsViewModel(repository: repository);

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('contacts-search-users')),
      '@mia',
    );
    await tester.enterText(
      find.byKey(const Key('contacts-invite-message')),
      'Let us chat',
    );
    await tester.pumpAndSettle();

    expect(repository.lastSearchQuery, 'mia');
    expect(find.text('Mia Chen'), findsOneWidget);
    expect(find.text('@mia'), findsWidgets);

    await tester.tap(find.byKey(const Key('contacts-add-profile-friend_2')));
    await tester.pumpAndSettle();

    expect(repository.lastReceiverId, 'friend_2');
    expect(repository.lastMessage, 'Let us chat');
    expect(find.text('@mia'), findsNothing);
    expect(find.text('Let us chat'), findsNothing);
    expect(find.text('Pending invitations: 1'), findsOneWidget);
  });

  testWidgets('contacts view shows searchable users without handles', (
    tester,
  ) async {
    final repository = _FakeContactsRepository(
      searchResults: [
        ProfileSearchResultModel.fromJson(const {
          'id': 'friend_3',
          'display_name': 'No Handle User',
          'handle': null,
          'avatar_url': null,
        }),
      ],
    );
    final viewModel = ContactsViewModel(repository: repository);

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('contacts-search-users')),
      'no handle',
    );
    await tester.pumpAndSettle();

    expect(find.text('No Handle User'), findsOneWidget);
    expect(find.text('No handle yet'), findsOneWidget);
    expect(
      find.byKey(const Key('contacts-add-profile-friend_3')),
      findsOneWidget,
    );
    expect(find.text('No users found'), findsNothing);
  });

  testWidgets('contacts view shows no results for an unmatched search', (
    tester,
  ) async {
    final viewModel = ContactsViewModel(repository: _FakeContactsRepository());

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('contacts-search-users')),
      'nobody',
    );
    await tester.pumpAndSettle();

    expect(find.text('No users found'), findsOneWidget);
  });

  testWidgets('contacts view shows search error state', (tester) async {
    final viewModel = ContactsViewModel(
      repository: _FakeContactsRepository(
        searchError: StateError('search unavailable'),
      ),
    );

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('contacts-search-users')),
      'alex',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('search unavailable'), findsOneWidget);
  });

  testWidgets('contacts view opens invitations with shared view model', (
    tester,
  ) async {
    final repository = _FakeContactsRepository(
      invitations: [_invitation(id: 'inv_1', senderId: 'sender_1')],
      responseInvitation: _invitation(
        id: 'inv_1',
        senderId: 'sender_1',
        status: 'accepted',
      ),
    );
    final viewModel = ContactsViewModel(repository: repository);

    await tester.pumpWidget(
      _harness(ContactsView(viewModel: viewModel, currentUserId: 'receiver_1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contacts-invitations-button')));
    await tester.pumpAndSettle();

    expect(find.byType(InvitationsView), findsOneWidget);
    expect(find.text('sender_1'), findsOneWidget);

    await tester.tap(find.byTooltip('Accept'));
    await tester.pumpAndSettle();

    expect(repository.lastInvitationId, 'inv_1');
    expect(repository.lastAction, InvitationResponseAction.accept);
    expect(find.text('accepted'), findsOneWidget);
  });

  testWidgets('invitations view hides response actions for sent invitations', (
    tester,
  ) async {
    final repository = _FakeContactsRepository(
      invitations: [
        _invitation(
          id: 'sent_inv_1',
          senderId: 'user_1',
          receiverId: 'friend_1',
        ),
      ],
    );
    final viewModel = ContactsViewModel(repository: repository);

    await tester.pumpWidget(
      _harness(ContactsView(viewModel: viewModel, currentUserId: 'user_1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contacts-invitations-button')));
    await tester.pumpAndSettle();

    expect(find.byType(InvitationsView), findsOneWidget);
    expect(find.text('user_1'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
    expect(find.byTooltip('Accept'), findsNothing);
    expect(find.byTooltip('Decline'), findsNothing);
  });

  testWidgets('contacts view shows repository error state', (tester) async {
    final viewModel = ContactsViewModel(
      repository: _FakeContactsRepository(
        loadError: StateError('contacts unavailable'),
      ),
    );

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    expect(find.textContaining('contacts unavailable'), findsOneWidget);
    expect(find.text('No contacts yet'), findsOneWidget);
  });
}

Widget _harness(Widget child) {
  return MaterialApp(home: child);
}

InvitationModel _invitation({
  required String id,
  String senderId = 'sender_1',
  String receiverId = 'receiver_1',
  String status = 'pending',
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
    this.loadError,
    this.contactsCompleter,
    this.searchResults = const [],
    this.searchError,
    InvitationModel? sentInvitation,
    InvitationModel? responseInvitation,
  }) : sentInvitation =
           sentInvitation ??
           _invitation(id: 'sent_invitation', status: 'pending'),
       responseInvitation =
           responseInvitation ??
           _invitation(id: 'response_invitation', status: 'accepted');

  final List<ContactModel> contacts;
  final List<InvitationModel> invitations;
  final Object? loadError;
  final Completer<List<ContactModel>>? contactsCompleter;
  final List<ProfileSearchResultModel> searchResults;
  final Object? searchError;
  final InvitationModel sentInvitation;
  final InvitationModel responseInvitation;

  String? lastReceiverId;
  String? lastMessage;
  String? lastInvitationId;
  String? lastSearchQuery;
  InvitationResponseAction? lastAction;

  @override
  Future<List<ContactModel>> fetchContacts() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }

    final completer = contactsCompleter;
    if (completer != null) {
      return completer.future;
    }

    return contacts;
  }

  @override
  Future<List<InvitationModel>> fetchInvitations() async {
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
