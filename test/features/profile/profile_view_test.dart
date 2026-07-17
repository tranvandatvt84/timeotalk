import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/profile/models/profile_model.dart';
import 'package:timeotalk/features/profile/repositories/profile_repository.dart';
import 'package:timeotalk/features/profile/viewmodels/profile_view_model.dart';
import 'package:timeotalk/features/profile/views/profile_view.dart';

void main() {
  testWidgets('profile view loads and renders current profile', (tester) async {
    final viewModel = ProfileViewModel(
      repository: _FakeProfileRepository(
        profile: const ProfileModel(
          id: 'user_1',
          displayName: 'Dat Tran',
          handle: 'dat',
          status: 'Building TimeoTalk',
        ),
      ),
    );

    await tester.pumpWidget(_harness(ProfileView(viewModel: viewModel)));
    await tester.pump();

    expect(find.byKey(const Key('profile-view')), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Dat Tran'), findsWidgets);
    expect(find.text('@dat'), findsOneWidget);
    expect(find.text('Building TimeoTalk'), findsWidgets);
    expect(find.text('user_1'), findsOneWidget);
    expect(find.text('DT'), findsOneWidget);
  });

  testWidgets('profile view saves edits', (tester) async {
    final repository = _FakeProfileRepository(
      profile: const ProfileModel(id: 'user_1', displayName: 'Dat Tran'),
      updatedProfile: const ProfileModel(
        id: 'user_1',
        displayName: 'Dat T.',
        handle: 'dat_t',
        status: 'Online',
      ),
    );
    final viewModel = ProfileViewModel(repository: repository);

    await tester.pumpWidget(_harness(ProfileView(viewModel: viewModel)));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('profile-display-name')),
      'Dat T.',
    );
    await tester.enterText(find.byKey(const Key('profile-handle')), '@Dat_T');
    await tester.enterText(find.byKey(const Key('profile-status')), 'Online');
    await tester.tap(find.text('Save Profile'));
    await tester.pump();
    await tester.pump();

    expect(repository.lastDisplayName, 'Dat T.');
    expect(repository.lastHandle, 'dat_t');
    expect(repository.lastStatus, 'Online');
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('profile view refresh reloads the current profile', (
    tester,
  ) async {
    final repository = _FakeProfileRepository(
      profile: const ProfileModel(
        id: 'user_1',
        displayName: 'Dat Tran',
        handle: 'dat',
        status: 'Before refresh',
      ),
    );
    final viewModel = ProfileViewModel(repository: repository);

    await tester.pumpWidget(_harness(ProfileView(viewModel: viewModel)));
    await tester.pump();

    expect(repository.fetchCount, 1);
    expect(find.text('Before refresh'), findsWidgets);

    repository.profile = const ProfileModel(
      id: 'user_1',
      displayName: 'Dat Tran',
      handle: 'dat',
      status: 'After refresh',
    );

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();
    await tester.pump();

    expect(repository.fetchCount, 2);
    expect(find.text('After refresh'), findsWidgets);
  });

  testWidgets('profile view shows loading and error states', (tester) async {
    final viewModel = ProfileViewModel(
      repository: _FakeProfileRepository(
        loadError: StateError('profile unavailable'),
      ),
    );

    await tester.pumpWidget(_harness(ProfileView(viewModel: viewModel)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump();

    expect(find.textContaining('profile unavailable'), findsOneWidget);
    expect(find.text('No profile found'), findsOneWidget);
  });
}

Widget _harness(Widget child) {
  return MaterialApp(home: child);
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({
    ProfileModel? profile,
    ProfileModel? updatedProfile,
    this.loadError,
  }) : profile =
           profile ?? const ProfileModel(id: 'user_1', displayName: 'Dat'),
       updatedProfile =
           updatedProfile ??
           profile ??
           const ProfileModel(id: 'user_1', displayName: 'Dat');

  ProfileModel profile;
  final ProfileModel updatedProfile;
  final Object? loadError;

  int fetchCount = 0;
  String? lastDisplayName;
  String? lastHandle;
  String? lastStatus;

  @override
  Future<ProfileModel> fetchCurrentUserProfile() async {
    fetchCount += 1;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return profile;
  }

  @override
  Future<ProfileModel> upsertCurrentUserProfile({
    required String displayName,
    String? handle,
    String? avatarUrl,
    String? status,
  }) async {
    lastDisplayName = displayName;
    lastHandle = handle;
    lastStatus = status;
    return updatedProfile;
  }
}
