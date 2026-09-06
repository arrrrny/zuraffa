// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'chat_session.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ChatSession {
  ChatSession({
    required String this.id,
    String? this.title,
    required List<ChatMessage> this.messages,
    Listing? this.listing,
    required DateTime this.createdAt,
    DateTime? this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);

  final String id;

  final String? title;

  final List<ChatMessage> messages;

  final Listing? listing;

  final DateTime createdAt;

  final DateTime? updatedAt;

  ChatSession copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    Listing? listing,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      listing: listing ?? this.listing,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ChatSession copyWithField<T>(Field<ChatSession, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'title':
        return copyWith(title: value as String?);
      case 'messages':
        return copyWith(messages: value as List<ChatMessage>);
      case 'listing':
        return copyWith(listing: value as Listing?);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      case 'updatedAt':
        return copyWith(updatedAt: value as DateTime?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ChatSession has no settable field with this name',
        );
    }
  }

  ChatSession copyWithChatSession({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    Listing? listing,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return copyWith(
      id: id,
      title: title,
      messages: messages,
      listing: listing,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  ChatSession patchWithChatSession([ChatSessionPatch? patchInput]) {
    final _patcher = patchInput ?? ChatSessionPatch();
    final _patchMap = _patcher.patchMap;
    return ChatSession(
      id: _patchMap.containsKey(ChatSession$.id)
          ? ((_patchMap[ChatSession$.id] is Function)
                    ? _patchMap[ChatSession$.id](this.id)
                    : (_patchMap[ChatSession$.id] is Patch)
                    ? _patchMap[ChatSession$.id].applyTo(this.id)
                    : _patchMap[ChatSession$.id])
                as String
          : this.id,
      title: _patchMap.containsKey(ChatSession$.title)
          ? ((_patchMap[ChatSession$.title] is Function)
                    ? _patchMap[ChatSession$.title](this.title)
                    : (_patchMap[ChatSession$.title] is Patch)
                    ? _patchMap[ChatSession$.title].applyTo(this.title)
                    : _patchMap[ChatSession$.title])
                as String?
          : this.title,
      messages: _patchMap.containsKey(ChatSession$.messages)
          ? ((_patchMap[ChatSession$.messages] is Function)
                    ? _patchMap[ChatSession$.messages](this.messages)
                    : (_patchMap[ChatSession$.messages] is Patch)
                    ? _patchMap[ChatSession$.messages].applyTo(this.messages)
                    : _patchMap[ChatSession$.messages])
                as List<ChatMessage>
          : this.messages,
      listing: _patchMap.containsKey(ChatSession$.listing)
          ? ((_patchMap[ChatSession$.listing] is Function)
                    ? _patchMap[ChatSession$.listing](this.listing)
                    : (_patchMap[ChatSession$.listing] is Patch)
                    ? _patchMap[ChatSession$.listing].applyTo(this.listing)
                    : _patchMap[ChatSession$.listing])
                as Listing?
          : this.listing,
      createdAt: _patchMap.containsKey(ChatSession$.createdAt)
          ? ((_patchMap[ChatSession$.createdAt] is Function)
                    ? _patchMap[ChatSession$.createdAt](this.createdAt)
                    : (_patchMap[ChatSession$.createdAt] is Patch)
                    ? _patchMap[ChatSession$.createdAt].applyTo(this.createdAt)
                    : _patchMap[ChatSession$.createdAt])
                as DateTime
          : this.createdAt,
      updatedAt: _patchMap.containsKey(ChatSession$.updatedAt)
          ? ((_patchMap[ChatSession$.updatedAt] is Function)
                    ? _patchMap[ChatSession$.updatedAt](this.updatedAt)
                    : (_patchMap[ChatSession$.updatedAt] is Patch)
                    ? _patchMap[ChatSession$.updatedAt].applyTo(this.updatedAt)
                    : _patchMap[ChatSession$.updatedAt])
                as DateTime?
          : this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatSession &&
        id == other.id &&
        title == other.title &&
        messages == other.messages &&
        listing == other.listing &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.title,
      this.messages,
      this.listing,
      this.createdAt,
      this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ChatSession(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'messages: ${messages}' +
        ', ' +
        'listing: ${listing}' +
        ', ' +
        'createdAt: ${createdAt}' +
        ', ' +
        'updatedAt: ${updatedAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ChatSessionToJson(this);
    _sanitizeJson(data);
    return data;
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('__typename');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension ChatSessionPropertyHelpers on ChatSession {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasTitle {
    return this.title?.isNotEmpty == true;
  }

  bool get noTitle {
    return this.title?.isEmpty ?? true;
  }

  String get titleRequired {
    return this.title ?? (throw StateError('title is required but was null'));
  }

  bool get hasMessages {
    return this.messages.isNotEmpty;
  }

  bool get noMessages {
    return this.messages.isEmpty;
  }

  bool get hasListing {
    return this.listing != null;
  }

  bool get noListing {
    return this.listing == null;
  }

  Listing get listingRequired {
    return this.listing ??
        (throw StateError('listing is required but was null'));
  }

  bool get hasUpdatedAt {
    return this.updatedAt != null;
  }

  bool get noUpdatedAt {
    return this.updatedAt == null;
  }

  DateTime get updatedAtRequired {
    return this.updatedAt ??
        (throw StateError('updatedAt is required but was null'));
  }
}

extension ChatSessionSerialization on ChatSession {
  Map<String, dynamic> toJson() {
    return _$ChatSessionToJson(this);
  }
}

enum ChatSession$ { id, title, messages, listing, createdAt, updatedAt }

class ChatSessionPatch extends PatchBase<ChatSession, ChatSession$> {
  ChatSession applyTo(ChatSession entity) {
    return entity.patchWithChatSession(this);
  }

  ChatSessionPatch withId(String? value) {
    patchMap[ChatSession$.id] = value;
    return this;
  }

  ChatSessionPatch withTitle(String? value) {
    patchMap[ChatSession$.title] = value;
    return this;
  }

  ChatSessionPatch withMessages(List<ChatMessage>? value) {
    patchMap[ChatSession$.messages] = value;
    return this;
  }

  ChatSessionPatch updateMessagesAt(
    int index,
    ChatMessagePatch Function(ChatMessagePatch) patch,
  ) {
    patchMap[ChatSession$.messages] = (List<dynamic> list) {
      var updatedList = List<ChatMessage>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          ChatMessagePatch(),
        ).applyTo(updatedList[index] as ChatMessage);
      }
      return updatedList;
    };
    return this;
  }

  ChatSessionPatch withListing(Listing? value) {
    patchMap[ChatSession$.listing] = value;
    return this;
  }

  ChatSessionPatch withListingPatch(ListingPatch patch) {
    patchMap[ChatSession$.listing] = patch;
    return this;
  }

  ChatSessionPatch withListingPatchFunc(
    ListingPatch Function(ListingPatch) patch,
  ) {
    patchMap[ChatSession$.listing] = (dynamic current) {
      var currentPatch = ListingPatch();
      return patch(currentPatch).applyTo(current as Listing);
    };
    return this;
  }

  ChatSessionPatch withCreatedAt(DateTime? value) {
    patchMap[ChatSession$.createdAt] = value;
    return this;
  }

  ChatSessionPatch withUpdatedAt(DateTime? value) {
    patchMap[ChatSession$.updatedAt] = value;
    return this;
  }
}

/// Field descriptors for [ChatSession] query construction
abstract final class ChatSessionFields {
  static const id = Field<ChatSession, String>('id', _$id);

  static const title = Field<ChatSession, String?>('title', _$title);

  static const messages = Field<ChatSession, List<ChatMessage>>(
    'messages',
    _$messages,
  );

  static const listing = Field<ChatSession, Listing?>('listing', _$listing);

  static const createdAt = Field<ChatSession, DateTime>(
    'createdAt',
    _$createdAt,
  );

  static const updatedAt = Field<ChatSession, DateTime?>(
    'updatedAt',
    _$updatedAt,
  );

  static String _$id(ChatSession e) {
    return e.id;
  }

  static String? _$title(ChatSession e) {
    return e.title;
  }

  static List<ChatMessage> _$messages(ChatSession e) {
    return e.messages;
  }

  static Listing? _$listing(ChatSession e) {
    return e.listing;
  }

  static DateTime _$createdAt(ChatSession e) {
    return e.createdAt;
  }

  static DateTime? _$updatedAt(ChatSession e) {
    return e.updatedAt;
  }
}

extension ChatSessionCompareE on ChatSession {
  Map<String, dynamic> compareToChatSession(ChatSession other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (messages != other.messages) {
      diff['messages'] = () => other.messages;
    }

    if (listing != other.listing) {
      diff['listing'] = () => other.listing;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }

    if (updatedAt != other.updatedAt) {
      diff['updatedAt'] = () => other.updatedAt;
    }
    return diff;
  }
}
