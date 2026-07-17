import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/models/chat_receipt_model.dart';

enum RealtimeEventType {
  messageCreated,
  messagePersisted,
  messageRejected,
  receiptDelivered,
  receiptRead,
}

class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    required this.name,
    required this.payload,
    this.message,
    this.receipt,
    this.errorMessage,
  });

  final RealtimeEventType type;
  final String name;
  final Map<String, Object?> payload;
  final ChatMessageModel? message;
  final ChatReceiptModel? receipt;
  final String? errorMessage;

  factory RealtimeEvent.fromJson(Map<String, Object?> json) {
    final payload = _payloadFromJson(json);
    final name = _eventName(json, payload);
    if (name == null) {
      throw const FormatException('Realtime event is missing an event name.');
    }

    payload['event'] ??= name;

    return switch (name) {
      'message.created' => RealtimeEvent(
        type: RealtimeEventType.messageCreated,
        name: name,
        payload: payload,
        message: ChatMessageModel.fromJson(payload),
      ),
      'message.persisted' => RealtimeEvent(
        type: RealtimeEventType.messagePersisted,
        name: name,
        payload: payload,
        message: ChatMessageModel.fromJson(payload),
      ),
      'message.rejected' => RealtimeEvent(
        type: RealtimeEventType.messageRejected,
        name: name,
        payload: payload,
        message: ChatMessageModel.fromJson({
          ...payload,
          'persistence_status': payload['persistence_status'] ?? 'rejected',
        }),
        errorMessage:
            payload['error'] as String? ?? payload['error_message'] as String?,
      ),
      'receipt.delivered' => RealtimeEvent(
        type: RealtimeEventType.receiptDelivered,
        name: name,
        payload: payload,
        receipt: ChatReceiptModel.fromJson({
          ...payload,
          'status': payload['status'] ?? 'delivered',
        }),
      ),
      'receipt.read' => RealtimeEvent(
        type: RealtimeEventType.receiptRead,
        name: name,
        payload: payload,
        receipt: ChatReceiptModel.fromJson({
          ...payload,
          'status': payload['status'] ?? 'read',
        }),
      ),
      _ => throw FormatException('Unsupported realtime event: $name'),
    };
  }
}

Map<String, Object?> _payloadFromJson(Map<String, Object?> json) {
  final data = json['data'];
  if (data is Map<String, Object?>) {
    return Map<String, Object?>.from(data);
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  return Map<String, Object?>.from(json);
}

String? _eventName(Map<String, Object?> json, Map<String, Object?> payload) {
  return payload['event'] as String? ??
      json['event'] as String? ??
      json['name'] as String?;
}
