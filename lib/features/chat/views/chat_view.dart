import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/viewmodels/chat_view_model.dart';
import 'package:timeotalk/features/chat/views/widgets/message_bubble.dart';
import 'package:timeotalk/features/chat/views/widgets/message_input.dart';
import 'package:timeotalk/features/chat/views/widgets/typing_indicator.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.conversationId,
    required ChatViewModel viewModel,
    this.autoOpen = true,
  }) : _viewModel = viewModel;

  final String conversationId;
  final bool autoOpen;
  final ChatViewModel _viewModel;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  ChatViewModel get _viewModel => widget._viewModel;

  @override
  void initState() {
    super.initState();
    if (!widget.autoOpen) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_viewModel.openConversation(widget.conversationId));
    });
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoOpen && oldWidget.conversationId != widget.conversationId) {
      unawaited(_viewModel.openConversation(widget.conversationId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        key: const Key('chat-view'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFEAF2F4)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, _) {
            final state = _viewModel.state;

            return Column(
              children: [
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: state.messages.isEmpty
                        ? const _EmptyChat()
                        : ListView.separated(
                            key: const Key('chat-message-list'),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                            itemBuilder: (context, index) {
                              final message = state.messages[index];
                              _markMessageVisible(message);
                              return MessageBubble(
                                message: message,
                                isOwnMessage:
                                    message.senderId ==
                                    _viewModel.currentUserId,
                              );
                            },
                            separatorBuilder: (context, _) =>
                                const SizedBox(height: 10),
                            itemCount: state.messages.length,
                          ),
                  ),
                ),
                TypingIndicator(isVisible: state.isPeerTyping),
                MessageInput(
                  isSending: state.isSending,
                  onChanged: _viewModel.updateComposerText,
                  onSend: (text) =>
                      _viewModel.sendTextMessage(widget.conversationId, text),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _markMessageVisible(ChatMessageModel message) {
    if (message.senderId == _viewModel.currentUserId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_viewModel.markMessageVisible(message));
    });
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
      children: const [
        SizedBox(
          height: 280,
          child: Center(child: Icon(Icons.chat_bubble_outline, size: 42)),
        ),
      ],
    );
  }
}
