// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/chat_message/chat_message.dart';

class ChatMessageState {
  const ChatMessageState({
    this.error,
    this.chatMessage,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ChatMessage entity
  final ChatMessage? chatMessage;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ChatMessageState copyWith({
    AppFailure? error,
    ChatMessage? chatMessage,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ChatMessageState(
    error: error ?? this.error,
    chatMessage: chatMessage ?? this.chatMessage,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageState &&
          other.error == error &&
          other.chatMessage == chatMessage &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      chatMessage.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'ChatMessageState(error: $error, chatMessage: $chatMessage)';
}

// END GENERATED
