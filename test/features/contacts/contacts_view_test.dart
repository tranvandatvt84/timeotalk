import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';
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
    expect(find.text('Send Invite'), findsOneWidget);
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

  testWidgets('contacts view sends invitation and clears the form', (
    tester,
  ) async {
    final repository = _FakeContactsRepository(
      sentInvitation: _invitation(id: 'sent_1', receiverId: 'friend_2'),
    );
    final viewModel = ContactsViewModel(repository: repository);

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('contacts-invite-receiver')),
      'friend_2',
    );
    await tester.enterText(
      find.byKey(const Key('contacts-invite-message')),
      'Let us chat',
    );
    await tester.tap(find.byKey(const Key('contacts-send-invite')));
    await tester.pumpAndSettle();

    expect(repository.lastReceiverId, 'friend_2');
    expect(repository.lastMessage, 'Let us chat');
    expect(find.text('friend_2'), findsNothing);
    expect(find.text('Let us chat'), findsNothing);
    expect(find.text('Pending invitations: 1'), findsOneWidget);
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

    await tester.pumpWidget(_harness(ContactsView(viewModel: viewModel)));
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
  final InvitationModel sentInvitation;
  final InvitationModel responseInvitation;

  String? lastReceiverId;
  String? lastMessage;
  String? lastInvitationId;
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
  Future<InvitationModel> respondInvitation({
    required String invitationId,
    required InvitationResponseAction action,
  }) async {
    lastInvitationId = invitationId;
    lastAction = action;
    return responseInvitation;
  }
}
