import 'package:flutter/foundation.dart';
import 'package:timeotalk/features/profile/models/profile_model.dart';
import 'package:timeotalk/features/profile/repositories/profile_repository.dart';

class ProfileViewState {
  const ProfileViewState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.didSave = false,
  });

  final ProfileModel? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final bool didSave;

  ProfileViewState copyWith({
    ProfileModel? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool? didSave,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return ProfileViewState(
      profile: clearProfile ? null : profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      didSave: didSave ?? this.didSave,
    );
  }
}

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required ProfileRepository repository})
    : _repository = repository;

  final ProfileRepository _repository;
  ProfileViewState _state = const ProfileViewState();

  ProfileViewState get state => _state;

  Future<void> loadProfile() async {
    _setState(
      _state.copyWith(isLoading: true, clearError: true, didSave: false),
    );

    try {
      final profile = await _repository.fetchCurrentUserProfile();
      _setState(ProfileViewState(profile: profile));
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
          didSave: false,
        ),
      );
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String handle,
    String? status,
  }) async {
    final normalizedDisplayName = displayName.trim();
    final normalizedHandle = normalizeProfileHandle(handle);
    final normalizedStatus = status?.trim();

    if (!isValidProfileHandle(normalizedHandle)) {
      _setState(
        _state.copyWith(
          isSaving: false,
          errorMessage:
              'Handle must be 3-24 lowercase letters, numbers, or underscores.',
          didSave: false,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(isSaving: true, clearError: true, didSave: false),
    );

    try {
      final profile = await _repository.upsertCurrentUserProfile(
        displayName: normalizedDisplayName,
        handle: normalizedHandle,
        status: normalizedStatus == null || normalizedStatus.isEmpty
            ? null
            : normalizedStatus,
      );
      _setState(
        _state.copyWith(profile: profile, isSaving: false, didSave: true),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSaving: false,
          errorMessage: error.toString(),
          didSave: false,
        ),
      );
    }
  }

  void _setState(ProfileViewState state) {
    _state = state;
    notifyListeners();
  }
}
