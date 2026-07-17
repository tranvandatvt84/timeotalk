import 'package:flutter/material.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';

class ReceiptIndicator extends StatelessWidget {
  const ReceiptIndicator({super.key, required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final status = receiptStatusFor(message);
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      MessageReceiptStatus.read => colorScheme.primary,
      MessageReceiptStatus.delivered ||
      MessageReceiptStatus.persisted ||
      MessageReceiptStatus.sent => colorScheme.onSurfaceVariant,
      MessageReceiptStatus.failed ||
      MessageReceiptStatus.rejected => colorScheme.error,
      MessageReceiptStatus.pending => colorScheme.onSurfaceVariant,
    };

    return Row(
      key: Key('receipt-${message.clientMessageId}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          status.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

enum MessageReceiptStatus {
  pending('Pending', Icons.schedule_outlined),
  sent('Sent', Icons.check),
  delivered('Delivered', Icons.done_all),
  read('Read', Icons.done_all),
  failed('Failed', Icons.error_outline),
  rejected('Rejected', Icons.block),
  persisted('Persisted', Icons.cloud_done_outlined);

  const MessageReceiptStatus(this.label, this.icon);

  final String label;
  final IconData icon;
}

MessageReceiptStatus receiptStatusFor(ChatMessageModel message) {
  if (message.deliveryStatus == 'read') {
    return MessageReceiptStatus.read;
  }
  if (message.deliveryStatus == 'delivered') {
    return MessageReceiptStatus.delivered;
  }
  if (message.persistenceStatus == 'rejected' ||
      message.localStatus == 'rejected') {
    return MessageReceiptStatus.rejected;
  }
  if (message.localStatus == 'failed_realtime') {
    return MessageReceiptStatus.failed;
  }
  if (message.persistenceStatus == 'persisted') {
    return MessageReceiptStatus.persisted;
  }
  if (message.localStatus == 'sent_realtime') {
    return MessageReceiptStatus.sent;
  }

  return MessageReceiptStatus.pending;
}
