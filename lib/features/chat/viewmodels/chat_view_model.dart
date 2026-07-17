import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:timeotalk/core/realtime/realtime_event.dart';
import 'package:timeotalk/features/chat/models/chat_message_model.dart';
import 'package:timeotalk/features/chat/models/chat_receipt_model.dart';
import 'package:timeotalk/features/chat/repositories/chat_local_repository.dart';
import 'package:timeotalk/features/chat/repositories/chat_realtime_repository.dart';
import 'package:timeotalk/features/chat/repositories/chat_remote_repository.dart';

typedef ClientMessageIdGenerator = String Function();
typedef ChatClock = DateTime Function();

class ChatViewState {
  const ChatViewState({
    this.messages = const [],
    this.isSending = false,
    this.isPeerTyping = false,
    this.errorMessage,
  });

  final List<ChatMessageModel> messages;
  final bool isSending;
  final bool isPeerTyping;
  final String? errorMessage;

  ChatViewState copyWith({
    List<ChatMessageModel>? messages,
    bool? isSending,
    bool? isPeerTyping,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatViewState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
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
    Duration typingStopDelay = const Duration(milliseconds: 1200),
  }) : _currentUserId = currentUserId,
       _senderDeviceId = senderDeviceId,
       _localRepository = localRepository,
       _realtimeRepository = realtimeRepository,
       _remoteRepository = remoteRepository,
       _clientMessageIdGenerator =
           clientMessageIdGenerator ?? _generateClientMessageId,
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _typingStopDelay = typingStopDelay;

  final String _currentUserId;
  final String? _senderDeviceId;
  final ChatLocalRepository _localRepository;
  final ChatRealtimeRepository _realtimeRepository;
  final ChatRemoteRepository? _remoteRepository;
  final ClientMessageIdGenerator _clientMessageIdGenerator;
  final ChatClock _clock;
  final Duration _typingStopDelay;

  StreamSubscription<List<ChatMessageModel>>? _messageSubscription;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _typingStopTimer;
  String? _openConversationId;
  bool _isConversationVisible = false;
  bool _isTyping = false;
  final _deliveredReceiptClientIds = <String>{};
  final _readReceiptClientIds = <String>{};
  final _deliveredReceiptInFlightClientIds = <String>{};
  final _readReceiptInFlightClientIds = <String>{};

  ChatViewState _state = const ChatViewState();

  ChatViewState get state => _state;
  String get currentUserId => _currentUserId;

  Future<void> openConversation(String conversationId) async {
    final previousConversationId = _openConversationId;
    if (previousConversationId != null &&
        previousConversationId != conversationId) {
      _stopTypingNow(previousConversationId);
    }

    _openConversationId = conversationId;
    _isConversationVisible = true;

    await _messageSubscription?.cancel();
    await _realtimeSubscription?.cancel();

    final messages = await _localRepository.fetchMessages(conversationId);
    _setState(
      _state.copyWith(
        messages: messages,
        isPeerTyping: false,
        clearError: true,
      ),
    );

    _messageSubscription = _localRepository
        .watchMessages(conversationId, includeInitial: false)
        .listen((messages) {
          _setState(_state.copyWith(messages: messages));
        });
    _realtimeSubscription = _realtimeRepository
        .subscribeToConversation(conversationId)
        .listen((event) => unawaited(handleRealtimeEvent(event)));
  }

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
    switch (event.type) {
      case RealtimeEventType.messagePersisted:
        final message = event.message;
        if (message == null) {
          return;
        }
        final merged = await _localRepository.mergePersistedMessage(message);
        _replaceMessage(merged);
      case RealtimeEventType.messageRejected:
        final message = event.message;
        if (message == null) {
          return;
        }
        final merged = await _localRepository.mergeRejectedMessage(
          message,
          errorMessage: event.errorMessage,
        );
        _replaceMessage(merged);
        _setState(_state.copyWith(errorMessage: event.errorMessage));
      case RealtimeEventType.messageCreated:
        final message = event.message;
        if (message == null) {
          return;
        }
        await _handleMessageCreated(message);
      case RealtimeEventType.receiptDelivered:
      case RealtimeEventType.receiptRead:
        final receipt = event.receipt;
        if (receipt == null || receipt.userId == _currentUserId) {
          return;
        }
        final merged = await _localRepository.applyReceipt(receipt);
        if (merged != null) {
          _replaceMessage(merged);
        }
      case RealtimeEventType.typingStarted:
        _setPeerTyping(event.payload['user_id'] as String?, true);
      case RealtimeEventType.typingStopped:
        _setPeerTyping(event.payload['user_id'] as String?, false);
    }
  }

  Future<void> markMessageVisible(ChatMessageModel message) async {
    if (!_isConversationVisible ||
        _openConversationId != message.conversationId ||
        message.senderId == _currentUserId) {
      return;
    }

    await _publishReadReceipt(message);
  }

  void updateComposerText(String text) {
    final conversationId = _openConversationId;
    if (conversationId == null) {
      return;
    }

    if (text.trim().isEmpty) {
      _stopTypingNow(conversationId);
      return;
    }

    if (!_isTyping) {
      _isTyping = true;
      unawaited(
        _realtimeRepository.publishTypingStarted(
          conversationId: conversationId,
          userId: _currentUserId,
        ),
      );
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(_typingStopDelay, () {
      _stopTypingNow(conversationId);
    });
  }

  Future<void> _handleMessageCreated(ChatMessageModel message) async {
    final result = await _localRepository.insertReceivedMessage(message);
    _replaceMessage(result.message);

    if (result.message.senderId == _currentUserId) {
      return;
    }

    await _publishDeliveredReceipt(result.message);
    if (_isConversationVisible &&
        _openConversationId == result.message.conversationId) {
      await _publishReadReceipt(result.message);
    }
  }

  Future<void> _publishDeliveredReceipt(ChatMessageModel message) async {
    if (_deliveredReceiptClientIds.contains(message.clientMessageId) ||
        _deliveredReceiptInFlightClientIds.contains(message.clientMessageId)) {
      return;
    }

    _deliveredReceiptInFlightClientIds.add(message.clientMessageId);
    try {
      await _realtimeRepository.publishReceiptDelivered(
        conversationId: message.conversationId,
        receipt: _receiptFor(message, 'delivered'),
      );
      _deliveredReceiptClientIds.add(message.clientMessageId);
    } catch (_) {
      return;
    } finally {
      _deliveredReceiptInFlightClientIds.remove(message.clientMessageId);
    }
  }

  Future<void> _publishReadReceipt(ChatMessageModel message) async {
    if (message.deliveryStatus == 'read' ||
        _readReceiptClientIds.contains(message.clientMessageId) ||
        _readReceiptInFlightClientIds.contains(message.clientMessageId)) {
      return;
    }

    final receipt = _receiptFor(message, 'read');
    _readReceiptInFlightClientIds.add(message.clientMessageId);
    try {
      await _realtimeRepository.publishReceiptRead(
        conversationId: message.conversationId,
        receipt: receipt,
      );
      final merged = await _localRepository.applyReceipt(receipt);
      _readReceiptClientIds.add(message.clientMessageId);
      if (merged != null) {
        _replaceMessage(merged);
      }
    } catch (_) {
      return;
    } finally {
      _readReceiptInFlightClientIds.remove(message.clientMessageId);
    }
  }

  ChatReceiptModel _receiptFor(ChatMessageModel message, String status) {
    return ChatReceiptModel(
      messageId: message.serverMessageId,
      clientMessageId: message.clientMessageId,
      userId: _currentUserId,
      status: status,
      createdAt: _clock().toUtc(),
    );
  }

  void _setPeerTyping(String? userId, bool isTyping) {
    if (userId == null || userId == _currentUserId) {
      return;
    }

    _setState(_state.copyWith(isPeerTyping: isTyping));
  }

  void _stopTypingNow(String conversationId) {
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    if (!_isTyping) {
      return;
    }

    _isTyping = false;
    unawaited(
      _realtimeRepository.publishTypingStopped(
        conversationId: conversationId,
        userId: _currentUserId,
      ),
    );
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

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    unawaited(_messageSubscription?.cancel());
    unawaited(_realtimeSubscription?.cancel());
    super.dispose();
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
