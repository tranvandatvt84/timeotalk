import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/app/main_shell.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';
import 'package:timeotalk/features/contacts/repositories/contacts_repository.dart';
import 'package:timeotalk/features/contacts/viewmodels/contacts_view_model.dart';
import 'package:timeotalk/features/contacts/views/contacts_view.dart';
import 'package:timeotalk/features/profile/models/profile_model.dart';
import 'package:timeotalk/features/profile/repositories/profile_repository.dart';
import 'package:timeotalk/features/profile/viewmodels/profile_view_model.dart';
import 'package:timeotalk/features/profile/views/profile_view.dart';

void main() {
  testWidgets('main shell starts on inbox with liquid glass navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));

    expect(find.byKey(const Key('tab-screen-inbox')), findsOneWidget);
    expect(find.byType(LiquidGlassNavBar), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Contacts'), findsNothing);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('main shell switches between real contacts and profile tabs', (
    tester,
  ) async {
    final contactsRepository = _FakeContactsRepository(
      contacts: [
        const ContactModel(
          ownerId: 'user_1',
          contactUserId: 'friend_1',
          displayName: 'Alex Rivera',
        ),
      ],
    );
    final contactsViewModel = ContactsViewModel(repository: contactsRepository);
    final profileRepository = _FakeProfileRepository(
      profile: const ProfileModel(id: 'user_1', displayName: 'Dat Tran'),
    );
    final profileViewModel = ProfileViewModel(repository: profileRepository);
    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          contactsViewModel: contactsViewModel,
          profileViewModel: profileViewModel,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tab-screen-contacts')), findsOneWidget);
    expect(find.byType(ContactsView), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('Inbox'), findsNothing);
    expect(find.text('Profile'), findsNothing);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tab-screen-profile')), findsOneWidget);
    expect(find.byType(ProfileView), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Dat Tran'), findsWidgets);
    expect(find.text('Inbox'), findsNothing);
    expect(find.text('Contacts'), findsNothing);
  });

  testWidgets('main shell keeps visited tabs alive', (tester) async {
    final repository = _FakeProfileRepository(
      profile: const ProfileModel(
        id: 'user_1',
        displayName: 'Dat Tran',
        status: 'Ready',
      ),
    );
    final profileViewModel = ProfileViewModel(repository: repository);

    await tester.pumpWidget(
      MaterialApp(home: MainShell(profileViewModel: profileViewModel)),
    );

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 1);

    await tester.enterText(
      find.byKey(const Key('profile-status')),
      'Still here',
    );

    await tester.tap(_navIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tab-screen-inbox')), findsOneWidget);
    expect(find.text('Still here'), findsNothing);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 1);
    expect(find.byKey(const Key('tab-screen-profile')), findsOneWidget);
    expect(find.text('Still here'), findsOneWidget);
  });

  testWidgets('main shell uses native Swift navbar on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(const MaterialApp(home: MainShell()));

    expect(find.byType(NativeIosLiquidGlassNavBar), findsOneWidget);
    expect(find.byType(LiquidGlassNavBar), findsNothing);

    debugDefaultTargetPlatformOverride = null;
  });
}

Finder _navIcon(IconData icon) {
  return find.descendant(
    of: find.byType(LiquidGlassNavBar),
    matching: find.byIcon(icon),
  );
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({required this.profile});

  ProfileModel profile;
  int fetchCount = 0;

  @override
  Future<ProfileModel> fetchCurrentUserProfile() async {
    fetchCount += 1;
    return profile;
  }

  @override
  Future<ProfileModel> upsertCurrentUserProfile({
    required String displayName,
    String? avatarUrl,
    String? status,
  }) async {
    return profile.copyWith(displayName: displayName, status: status);
  }
}

class _FakeContactsRepository implements ContactsRepository {
  _FakeContactsRepository({this.contacts = const []});

  final List<ContactModel> contacts;

  @override
  Future<List<ContactModel>> fetchContacts() async => contacts;

  @override
  Future<List<InvitationModel>> fetchInvitations() async => const [];

  @override
  Future<InvitationModel> sendInvitation({
    required String receiverId,
    String? message,
  }) async {
    return InvitationModel(
      id: 'sent_invitation',
      senderId: 'user_1',
      receiverId: receiverId,
      status: 'pending',
      message: message,
    );
  }

  @override
  Future<InvitationModel> respondInvitation({
    required String invitationId,
    required InvitationResponseAction action,
  }) async {
    return InvitationModel(
      id: invitationId,
      senderId: 'sender_1',
      receiverId: 'user_1',
      status: action.status,
    );
  }
}
