import 'package:flutter/material.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/views/widgets/receipt_indicator.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
  });

  final ChatMessageModel message;
  final bool isOwnMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isOwnMessage
        ? colorScheme.primaryContainer
        : colorScheme.surface;
    final textColor = isOwnMessage
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Align(
      key: Key('message-bubble-${message.clientMessageId}'),
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isOwnMessage ? 18 : 6),
              bottomRight: Radius.circular(isOwnMessage ? 6 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              crossAxisAlignment: isOwnMessage
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _messageText(message),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                ReceiptIndicator(message: message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _messageText(ChatMessageModel message) {
  final text = message.body['text'];
  if (text == null) {
    return '';
  }

  return text.toString();
}
