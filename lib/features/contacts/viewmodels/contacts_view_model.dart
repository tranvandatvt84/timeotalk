import 'package:flutter/foundation.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';
import 'package:timeotalk/features/contacts/repositories/contacts_repository.dart';

class ContactsViewState {
  const ContactsViewState({
    this.contacts = const [],
    this.invitations = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<ContactModel> contacts;
  final List<InvitationModel> invitations;
  final bool isLoading;
  final String? errorMessage;

  ContactsViewState copyWith({
    List<ContactModel>? contacts,
    List<InvitationModel>? invitations,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ContactsViewState(
      contacts: contacts ?? this.contacts,
      invitations: invitations ?? this.invitations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
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
