import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/inbox/models/conversation_model.dart';
import 'package:timeotalk/features/inbox/repositories/inbox_repository.dart';
import 'package:timeotalk/features/inbox/viewmodels/inbox_view_model.dart';
import 'package:timeotalk/features/inbox/views/inbox_view.dart';

void main() {
  testWidgets('inbox view renders synced conversations', (tester) async {
    final repository = _FakeInboxRepository(
      conversations: [
        ConversationModel(
          id: 'conversation_1',
          type: 'direct',
          title: 'Alex Rivera',
          lastMessagePreview: 'See you soon',
          unreadCount: 2,
          updatedAt: DateTime.utc(2026, 1, 1, 12),
        ),
      ],
    );
    addTearDown(repository.dispose);
    final viewModel = InboxViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(MaterialApp(home: InboxView(viewModel: viewModel)));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('inbox-view')), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('See you soon'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}

class _FakeInboxRepository implements InboxRepository {
  _FakeInboxRepository({required this.conversations});

  final List<ConversationModel> conversations;
  final _controller = StreamController<List<ConversationModel>>.broadcast();

  @override
  Stream<List<ConversationModel>> watchLocalConversations() {
    scheduleMicrotask(() => _controller.add(conversations));
    return _controller.stream;
  }

  @override
  Future<List<ConversationModel>> fetchRemoteConversations() async {
    return conversations;
  }

  @override
  Future<void> syncConversations() async {
    _controller.add(conversations);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
