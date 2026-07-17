import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/inbox/models/conversation_model.dart';
import 'package:timeotalk/features/inbox/repositories/inbox_repository.dart';
import 'package:timeotalk/features/inbox/viewmodels/inbox_view_model.dart';

void main() {
  test(
    'load shows local conversations first before remote sync refreshes them',
    () async {
      final cachedConversation = ConversationModel(
        id: 'conversation_cached',
        type: 'direct',
        title: 'Cached chat',
        lastMessagePreview: 'Stored locally',
        updatedAt: DateTime.utc(2026, 1, 1, 12),
      );
      final refreshedConversation = ConversationModel(
        id: 'conversation_remote',
        type: 'direct',
        title: 'Remote chat',
        lastMessagePreview: 'Fresh from Supabase',
        updatedAt: DateTime.utc(2026, 1, 1, 13),
      );
      final repository = _FakeInboxRepository(
        initialConversations: [cachedConversation],
        syncedConversations: [refreshedConversation],
      );
      addTearDown(repository.dispose);

      final viewModel = InboxViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      final loadFuture = viewModel.load();
      await Future<void>.delayed(Duration.zero);

      expect(repository.syncStarted, isTrue);
      expect(viewModel.state.conversations.single.id, 'conversation_cached');
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.isSyncing, isTrue);

      repository.completeSync();
      await loadFuture;
      await Future<void>.delayed(Duration.zero);

      expect(repository.syncCount, 1);
      expect(viewModel.state.conversations.single.id, 'conversation_remote');
      expect(viewModel.state.isSyncing, isFalse);
      expect(viewModel.state.errorMessage, isNull);
    },
  );
}

class _FakeInboxRepository implements InboxRepository {
  _FakeInboxRepository({
    required this.initialConversations,
    required this.syncedConversations,
  });

  final List<ConversationModel> initialConversations;
  final List<ConversationModel> syncedConversations;
  final _controller = StreamController<List<ConversationModel>>.broadcast();
  final _syncCompleter = Completer<void>();

  var syncCount = 0;
  var syncStarted = false;

  @override
  Stream<List<ConversationModel>> watchLocalConversations() {
    scheduleMicrotask(() => _controller.add(initialConversations));
    return _controller.stream;
  }

  @override
  Future<List<ConversationModel>> fetchRemoteConversations() async {
    return syncedConversations;
  }

  @override
  Future<void> syncConversations() async {
    syncCount += 1;
    syncStarted = true;
    await _syncCompleter.future;
    _controller.add(syncedConversations);
  }

  void completeSync() {
    if (!_syncCompleter.isCompleted) {
      _syncCompleter.complete();
    }
  }

  Future<void> dispose() {
    completeSync();
    return _controller.close();
  }
}
