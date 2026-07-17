import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:timeotalk/core/realtime/realtime_event.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/repositories/chat_local_repository.dart';
import 'package:timeotalk/features/chat/repositories/chat_realtime_repository.dart';
import 'package:timeotalk/features/chat/repositories/chat_remote_repository.dart';

typedef ClientMessageIdGenerator = String Function();
typedef ChatClock = DateTime Function();

class ChatViewState {
  const ChatViewState({
    this.messages = const [],
    this.isSending = false,
    this.errorMessage,
  });

  final List<ChatMessageModel> messages;
  final bool isSending;
  final String? errorMessage;

  ChatViewState copyWith({
    List<ChatMessageModel>? messages,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatViewState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required String currentUserId,
    required ChatLocalRepository localRepository,
    required ChatRealtimeRepository realtimeRepository,
    ChatRemoteRepository? remoteRepository,
    String? senderDeviceId,
    ClientMessageIdGenerator? clientMessageIdGenerator,
    ChatClock? clock,
  }) : _currentUserId = currentUserId,
       _senderDeviceId = senderDeviceId,
       _localRepository = localRepository,
       _realtimeRepository = realtimeRepository,
       _remoteRepository = remoteRepository,
       _clientMessageIdGenerator =
           clientMessageIdGenerator ?? _generateClientMessageId,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final String _currentUserId;
  final String? _senderDeviceId;
  final ChatLocalRepository _localRepository;
  final ChatRealtimeRepository _realtimeRepository;
  final ChatRemoteRepository? _remoteRepository;
  final ClientMessageIdGenerator _clientMessageIdGenerator;
  final ChatClock _clock;

  ChatViewState _state = const ChatViewState();

  ChatViewState get state => _state;

  Future<ChatMessageModel> sendTextMessage(
    String conversationId,
    String text,
  ) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Message text cannot be empty.');
    }

    final now = _clock().toUtc();
    final message = ChatMessageModel(
      clientMessageId: _clientMessageIdGenerator(),
      conversationId: conversationId,
      senderId: _currentUserId,
      senderDeviceId: _senderDeviceId,
      type: 'text',
      body: {'text': normalizedText},
      attachments: const [],
      localStatus: 'pending_realtime',
      persistenceStatus: 'pending',
      clientCreatedAt: now,
      updatedAt: now,
    );

    _setState(_state.copyWith(isSending: true, clearError: true));
    await _localRepository.insertOutgoingMessage(message);
    _prependMessage(message);

    try {
      await _realtimeRepository.publishMessageCreated(message);
      await _remoteRepository?.persistMessage(message);
      await _localRepository.markMessageSentRealtime(message.clientMessageId);
      final sentMessage = message.copyWith(
        localStatus: 'sent_realtime',
        updatedAt: _clock().toUtc(),
      );
      _replaceMessage(sentMessage);
      _setState(_state.copyWith(isSending: false));
      return sentMessage;
    } catch (error) {
      await _localRepository.enqueueOutgoingMessage(
        message,
        lastError: error.toString(),
      );
      await _localRepository.markMessageQueued(message.clientMessageId);
      final queuedMessage = message.copyWith(
        localStatus: 'queued_realtime',
        updatedAt: _clock().toUtc(),
      );
      _replaceMessage(queuedMessage);
      _setState(_state.copyWith(isSending: false));
      return queuedMessage;
    }
  }

  Future<void> handleRealtimeEvent(RealtimeEvent event) async {
    final message = event.message;
    if (message == null) {
      return;
    }

    switch (event.type) {
      case RealtimeEventType.messagePersisted:
        final merged = await _localRepository.mergePersistedMessage(message);
        _replaceMessage(merged);
      case RealtimeEventType.messageRejected:
        final merged = await _localRepository.mergeRejectedMessage(
          message,
          errorMessage: event.errorMessage,
        );
        _replaceMessage(merged);
        _setState(_state.copyWith(errorMessage: event.errorMessage));
      case RealtimeEventType.messageCreated:
      case RealtimeEventType.receiptDelivered:
      case RealtimeEventType.receiptRead:
        return;
    }
  }

  void _prependMessage(ChatMessageModel message) {
    _setState(_state.copyWith(messages: [message, ..._state.messages]));
  }

  void _replaceMessage(ChatMessageModel message) {
    final messages = <ChatMessageModel>[];
    var replaced = false;
    for (final existing in _state.messages) {
      if (existing.clientMessageId == message.clientMessageId) {
        messages.add(message);
        replaced = true;
      } else {
        messages.add(existing);
      }
    }

    if (!replaced) {
      messages.insert(0, message);
    }

    _setState(_state.copyWith(messages: messages));
  }

  void _setState(ChatViewState state) {
    _state = state;
    notifyListeners();
  }
}

final _clientMessageRandom = Random.secure();

String _generateClientMessageId() {
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(
    36,
  );
  final suffix = _clientMessageRandom.nextInt(1 << 32).toRadixString(36);
  return 'local_${timestamp}_$suffix';
}
