// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatSession _$ChatSessionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ChatSession', json, ($checkedConvert) {
      final val = ChatSession(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String?),
        messages: $checkedConvert(
          'messages',
          (v) => (v as List<dynamic>)
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        listing: $checkedConvert(
          'listing',
          (v) => v == null ? null : Listing.fromJson(v as Map<String, dynamic>),
        ),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => DateTime.parse(v as String),
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ChatSessionToJson(ChatSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': ?instance.title,
      'messages': instance.messages.map((e) => e.toJson()).toList(),
      'listing': ?instance.listing?.toJson(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': ?instance.updatedAt?.toIso8601String(),
    };
