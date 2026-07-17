import 'package:flutter/foundation.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';
import 'package:timeotalk/features/contacts/models/profile_search_result_model.dart';
import 'package:timeotalk/features/contacts/repositories/contacts_repository.dart';

class ContactsViewState {
  const ContactsViewState({
    this.contacts = const [],
    this.invitations = const [],
    this.searchQuery = '',
    this.searchResults = const [],
    this.isLoading = false,
    this.isSearching = false,
    this.errorMessage,
    this.searchErrorMessage,
  });

  final List<ContactModel> contacts;
  final List<InvitationModel> invitations;
  final String searchQuery;
  final List<ProfileSearchResultModel> searchResults;
  final bool isLoading;
  final bool isSearching;
  final String? errorMessage;
  final String? searchErrorMessage;

  ContactsViewState copyWith({
    List<ContactModel>? contacts,
    List<InvitationModel>? invitations,
    String? searchQuery,
    List<ProfileSearchResultModel>? searchResults,
    bool? isLoading,
    bool? isSearching,
    String? errorMessage,
    String? searchErrorMessage,
    bool clearError = false,
    bool clearSearchError = false,
  }) {
    return ContactsViewState(
      contacts: contacts ?? this.contacts,
      invitations: invitations ?? this.invitations,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      searchErrorMessage: clearSearchError
          ? null
          : searchErrorMessage ?? this.searchErrorMessage,
    );
  }
}

class ContactsViewModel extends ChangeNotifier {
  ContactsViewModel({required ContactsRepository repository})
    : _repository = repository;

  final ContactsRepository _repository;
  ContactsViewState _state = const ContactsViewState();

  ContactsViewState get state => _state;

  Future<void> load() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));

    try {
      final results = await Future.wait<Object>([
        _repository.fetchContacts(),
        _repository.fetchInvitations(),
      ]);
      final contacts = results[0] as List<ContactModel>;
      final invitations = results[1] as List<InvitationModel>;
      _setState(
        ContactsViewState(contacts: contacts, invitations: invitations),
      );
    } catch (error) {
      _setState(
        _state.copyWith(isLoading: false, errorMessage: error.toString()),
      );
    }
  }

  Future<void> sendInvitation({
    required String receiverId,
    String? message,
  }) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));

    try {
      final invitation = await _repository.sendInvitation(
        receiverId: receiverId,
        message: message,
      );
      _setState(
        _state.copyWith(
          invitations: [invitation, ..._state.invitations],
          isLoading: false,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(isLoading: false, errorMessage: error.toString()),
      );
    }
  }

  Future<void> searchProfiles(String query) async {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.length < 2) {
      _setState(
        _state.copyWith(
          searchQuery: normalizedQuery,
          searchResults: const [],
          isSearching: false,
          clearSearchError: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        searchQuery: normalizedQuery,
        isSearching: true,
        clearSearchError: true,
      ),
    );

    try {
      final results = await _repository.searchProfiles(normalizedQuery);
      if (_state.searchQuery != normalizedQuery) {
        return;
      }

      _setState(_state.copyWith(searchResults: results, isSearching: false));
    } catch (error) {
      if (_state.searchQuery != normalizedQuery) {
        return;
      }

      _setState(
        _state.copyWith(
          isSearching: false,
          searchErrorMessage: error.toString(),
        ),
      );
    }
  }

  void clearSearch() {
    _setState(
      _state.copyWith(
        searchQuery: '',
        searchResults: const [],
        isSearching: false,
        clearSearchError: true,
      ),
    );
  }

  Future<void> acceptInvitation(String invitationId) {
    return _respondToInvitation(
      invitationId: invitationId,
      action: InvitationResponseAction.accept,
    );
  }

  Future<void> declineInvitation(String invitationId) {
    return _respondToInvitation(
      invitationId: invitationId,
      action: InvitationResponseAction.decline,
    );
  }

  Future<void> _respondToInvitation({
    required String invitationId,
    required InvitationResponseAction action,
  }) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));

    try {
      final invitation = await _repository.respondInvitation(
        invitationId: invitationId,
        action: action,
      );
      _setState(
        _state.copyWith(
          invitations: _replaceInvitation(invitation),
          isLoading: false,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(isLoading: false, errorMessage: error.toString()),
      );
    }
  }

  List<InvitationModel> _replaceInvitation(InvitationModel invitation) {
    var replaced = false;
    final invitations = _state.invitations
        .map((existing) {
          if (existing.id != invitation.id) {
            return existing;
          }

          replaced = true;
          return invitation;
        })
        .toList(growable: false);

    if (replaced) {
      return invitations;
    }

    return [invitation, ...invitations];
  }

  void _setState(ContactsViewState state) {
    _state = state;
    notifyListeners();
  }
}

String _normalizeSearchQuery(String query) {
  final trimmed = query.trim();
  final withoutPrefix = trimmed.startsWith('@')
      ? trimmed.substring(1)
      : trimmed;
  return withoutPrefix.toLowerCase();
}
