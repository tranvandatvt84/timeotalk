import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timeotalk/features/inbox/models/conversation_model.dart';
import 'package:timeotalk/features/inbox/repositories/inbox_repository.dart';
import 'package:timeotalk/features/inbox/viewmodels/inbox_view_model.dart';

class InboxView extends StatefulWidget {
  const InboxView({super.key, InboxViewModel? viewModel})
    : _viewModel = viewModel;

  final InboxViewModel? _viewModel;

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  late final InboxViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget._viewModel == null;
    _viewModel =
        widget._viewModel ??
        InboxViewModel(repository: SupabaseInboxRepository());
    Future.microtask(_viewModel.load);
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        key: const Key('inbox-view'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FAFB), Color(0xFFEFF4F7)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _viewModel,
            builder: (context, _) {
              final state = _viewModel.state;

              if (state.isLoading && state.conversations.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _viewModel.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    children: const [
                      SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _viewModel.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  children: [
                    _InboxHeader(conversationCount: state.conversations.length),
                    if (state.isSyncing && state.conversations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (state.conversations.isEmpty)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.chat_bubble_outline),
                        title: Text('No conversations yet'),
                      )
                    else
                      for (final conversation in state.conversations)
                        _ConversationTile(conversation: conversation),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({required this.conversationCount});

  final int conversationCount;

  @override
  Widget build(BuildContext context) {
    final countLabel = conversationCount == 1
        ? '1 conversation'
        : '$conversationCount conversations';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inbox',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          countLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final ConversationModel conversation;

  @override
  Widget build(BuildContext context) {
    final title = conversation.title?.trim().isNotEmpty == true
        ? conversation.title!.trim()
        : _fallbackTitle(conversation);
    final subtitle = conversation.lastMessagePreview?.trim().isNotEmpty == true
        ? conversation.lastMessagePreview!.trim()
        : 'No messages yet';

    return ListTile(
      key: Key('inbox-conversation-${conversation.id}'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(_initials(title))),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: conversation.unreadCount > 0
          ? _UnreadBadge(count: conversation.unreadCount)
          : IconButton(
              tooltip: 'Open chat',
              onPressed: () {},
              icon: const Icon(Icons.chevron_right),
            ),
    );
  }

  String _fallbackTitle(ConversationModel conversation) {
    if (conversation.type == 'direct') {
      return 'Direct conversation';
    }

    return 'Group conversation';
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.isEmpty) {
      return '?';
    }

    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
