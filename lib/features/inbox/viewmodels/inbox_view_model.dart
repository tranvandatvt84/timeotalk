import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:timeotalk/features/inbox/models/conversation_model.dart';
import 'package:timeotalk/features/inbox/repositories/inbox_repository.dart';

class InboxViewState {
  const InboxViewState({
    this.conversations = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.errorMessage,
  });

  final List<ConversationModel> conversations;
  final bool isLoading;
  final bool isSyncing;
  final String? errorMessage;

  InboxViewState copyWith({
    List<ConversationModel>? conversations,
    bool? isLoading,
    bool? isSyncing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InboxViewState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class InboxViewModel extends ChangeNotifier {
  InboxViewModel({required InboxRepository repository})
    : _repository = repository;

  final InboxRepository _repository;
  InboxViewState _state = const InboxViewState();
  StreamSubscription<List<ConversationModel>>? _localSubscription;

  InboxViewState get state => _state;

  Future<void> load() async {
    _startLocalWatch();
    await refresh();
  }

  Future<void> refresh() async {
    _setState(_state.copyWith(isSyncing: true, clearError: true));

    try {
      await _repository.syncConversations();
      _setState(_state.copyWith(isLoading: false, isSyncing: false));
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          isSyncing: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void _startLocalWatch() {
    if (_localSubscription != null) {
      return;
    }

    _setState(
      _state.copyWith(
        isLoading: _state.conversations.isEmpty,
        clearError: true,
      ),
    );

    _localSubscription = _repository.watchLocalConversations().listen(
      (conversations) {
        _setState(
          _state.copyWith(conversations: conversations, isLoading: false),
        );
      },
      onError: (Object error) {
        _setState(
          _state.copyWith(
            isLoading: false,
            isSyncing: false,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  void _setState(InboxViewState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_localSubscription?.cancel());
    super.dispose();
  }
}
