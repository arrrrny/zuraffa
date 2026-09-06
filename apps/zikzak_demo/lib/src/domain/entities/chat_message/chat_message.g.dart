// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ChatMessage', json, ($checkedConvert) {
      final val = ChatMessage(
        id: $checkedConvert('id', (v) => v as String?),
        role: $checkedConvert(
          'role',
          (v) => $enumDecode(_$ChatMessageRoleEnumMap, v),
        ),
        content: $checkedConvert('content', (v) => v as String),
        timestamp: $checkedConvert(
          'timestamp',
          (v) => DateTime.parse(v as String),
        ),
        products: $checkedConvert(
          'products',
          (v) => (v as List<dynamic>?)
              ?.map((e) => Listing.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$ChatMessageRoleEnumMap[instance.role]!,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'products': ?instance.products?.map((e) => e.toJson()).toList(),
    };

const _$ChatMessageRoleEnumMap = {
  ChatMessageRole.user: 'user',
  ChatMessageRole.assistant: 'assistant',
  ChatMessageRole.system: 'system',
};
