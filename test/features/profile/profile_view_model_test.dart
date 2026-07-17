import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/profile/models/profile_model.dart';
import 'package:timeotalk/features/profile/repositories/profile_repository.dart';
import 'package:timeotalk/features/profile/viewmodels/profile_view_model.dart';

void main() {
  group('ProfileViewModel', () {
    test('loadProfile fetches the current profile', () async {
      final repository = _FakeProfileRepository(
        profile: const ProfileModel(
          id: 'user_1',
          displayName: 'Dat Tran',
          handle: 'dat',
          status: 'Building TimeoTalk',
        ),
      );
      final viewModel = ProfileViewModel(repository: repository);

      await viewModel.loadProfile();

      expect(repository.fetchCount, 1);
      expect(viewModel.state.profile?.displayName, 'Dat Tran');
      expect(viewModel.state.profile?.handle, 'dat');
      expect(viewModel.state.profile?.status, 'Building TimeoTalk');
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, isNull);
    });

    test('updateProfile saves display name and status', () async {
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

      await viewModel.updateProfile(
        displayName: ' Dat T. ',
        handle: ' @Dat_T ',
        status: ' Online ',
      );

      expect(repository.lastDisplayName, 'Dat T.');
      expect(repository.lastHandle, 'dat_t');
      expect(repository.lastStatus, 'Online');
      expect(viewModel.state.profile?.displayName, 'Dat T.');
      expect(viewModel.state.profile?.handle, 'dat_t');
      expect(viewModel.state.profile?.status, 'Online');
      expect(viewModel.state.isSaving, isFalse);
      expect(viewModel.state.errorMessage, isNull);
    });

    test('updateProfile sends null status when status is blank', () async {
      final repository = _FakeProfileRepository(
        updatedProfile: const ProfileModel(id: 'user_1', displayName: 'Dat'),
      );
      final viewModel = ProfileViewModel(repository: repository);

      await viewModel.updateProfile(
        displayName: 'Dat',
        handle: 'dat',
        status: '   ',
      );

      expect(repository.lastStatus, isNull);
    });

    test('updateProfile rejects blank and invalid handles', () async {
      final repository = _FakeProfileRepository();
      final viewModel = ProfileViewModel(repository: repository);

      await viewModel.updateProfile(displayName: 'Dat', handle: '   ');

      expect(repository.upsertCount, 0);
      expect(viewModel.state.errorMessage, contains('Handle'));

      await viewModel.updateProfile(displayName: 'Dat', handle: 'dat-tran');

      expect(repository.upsertCount, 0);
      expect(viewModel.state.errorMessage, contains('Handle'));
    });

    test('loadProfile surfaces repository errors', () async {
      final repository = _FakeProfileRepository(
        loadError: StateError('profile unavailable'),
      );
      final viewModel = ProfileViewModel(repository: repository);

      await viewModel.loadProfile();

      expect(viewModel.state.profile, isNull);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, contains('profile unavailable'));
    });

    test('updateProfile surfaces repository errors', () async {
      final repository = _FakeProfileRepository(
        saveError: StateError('profile save failed'),
      );
      final viewModel = ProfileViewModel(repository: repository);

      await viewModel.updateProfile(
        displayName: 'Dat',
        handle: 'dat',
        status: 'Online',
      );

      expect(viewModel.state.isSaving, isFalse);
      expect(viewModel.state.didSave, isFalse);
      expect(viewModel.state.errorMessage, contains('profile save failed'));
    });
  });
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({
    ProfileModel? profile,
    ProfileModel? updatedProfile,
    this.loadError,
    this.saveError,
  }) : profile =
           profile ?? const ProfileModel(id: 'user_1', displayName: 'Dat'),
       updatedProfile =
           updatedProfile ??
           profile ??
           const ProfileModel(id: 'user_1', displayName: 'Dat');

  final ProfileModel profile;
  final ProfileModel updatedProfile;
  final Object? loadError;
  final Object? saveError;

  int fetchCount = 0;
  int upsertCount = 0;
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
    upsertCount += 1;
    final error = saveError;
    if (error != null) {
      throw error;
    }
    lastDisplayName = displayName;
    lastHandle = handle;
    lastStatus = status;
    return updatedProfile;
  }
}
