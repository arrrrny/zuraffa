// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/ai_conversation/ai_conversation.dart';

class AiConversationState {
  const AiConversationState({
    this.error,
    this.aiConversation,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single AiConversation entity
  final AiConversation? aiConversation;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  AiConversationState copyWith({
    AppFailure? error,
    AiConversation? aiConversation,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => AiConversationState(
    error: error ?? this.error,
    aiConversation: aiConversation ?? this.aiConversation,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiConversationState &&
          other.error == error &&
          other.aiConversation == aiConversation &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      aiConversation.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'AiConversationState(error: $error, aiConversation: $aiConversation)';
}

// END GENERATED
