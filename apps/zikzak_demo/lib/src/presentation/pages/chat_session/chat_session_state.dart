// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/chat_session/chat_session.dart';

class ChatSessionState {
  const ChatSessionState({
    this.error,
    this.chatSession,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ChatSession entity
  final ChatSession? chatSession;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ChatSessionState copyWith({
    AppFailure? error,
    ChatSession? chatSession,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ChatSessionState(
    error: error ?? this.error,
    chatSession: chatSession ?? this.chatSession,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSessionState &&
          other.error == error &&
          other.chatSession == chatSession &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      chatSession.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'ChatSessionState(error: $error, chatSession: $chatSession)';
}

// END GENERATED
