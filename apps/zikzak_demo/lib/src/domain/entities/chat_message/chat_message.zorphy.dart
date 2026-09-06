// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'chat_message.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ChatMessage {
  ChatMessage({
    String? id,
    required ChatMessageRole this.role,
    required String this.content,
    required DateTime this.timestamp,
    List<Listing>? this.products,
  }) : this.id = id ?? const Uuid().v4();

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  final String id;

  final ChatMessageRole role;

  final String content;

  final DateTime timestamp;

  final List<Listing>? products;

  ChatMessage copyWith({
    String? id,
    ChatMessageRole? role,
    String? content,
    DateTime? timestamp,
    List<Listing>? products,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      products: products ?? this.products,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ChatMessage copyWithField<T>(Field<ChatMessage, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'role':
        return copyWith(role: value as ChatMessageRole);
      case 'content':
        return copyWith(content: value as String);
      case 'timestamp':
        return copyWith(timestamp: value as DateTime);
      case 'products':
        return copyWith(products: value as List<Listing>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ChatMessage has no settable field with this name',
        );
    }
  }

  ChatMessage copyWithChatMessage({
    String? id,
    ChatMessageRole? role,
    String? content,
    DateTime? timestamp,
    List<Listing>? products,
  }) {
    return copyWith(
      id: id,
      role: role,
      content: content,
      timestamp: timestamp,
      products: products,
    );
  }

  ChatMessage patchWithChatMessage([ChatMessagePatch? patchInput]) {
    final _patcher = patchInput ?? ChatMessagePatch();
    final _patchMap = _patcher.patchMap;
    return ChatMessage(
      id: _patchMap.containsKey(ChatMessage$.id)
          ? ((_patchMap[ChatMessage$.id] is Function)
                    ? _patchMap[ChatMessage$.id](this.id)
                    : (_patchMap[ChatMessage$.id] is Patch)
                    ? _patchMap[ChatMessage$.id].applyTo(this.id)
                    : _patchMap[ChatMessage$.id])
                as String
          : this.id,
      role: _patchMap.containsKey(ChatMessage$.role)
          ? ((_patchMap[ChatMessage$.role] is Function)
                    ? _patchMap[ChatMessage$.role](this.role)
                    : (_patchMap[ChatMessage$.role] is Patch)
                    ? _patchMap[ChatMessage$.role].applyTo(this.role)
                    : _patchMap[ChatMessage$.role])
                as ChatMessageRole
          : this.role,
      content: _patchMap.containsKey(ChatMessage$.content)
          ? ((_patchMap[ChatMessage$.content] is Function)
                    ? _patchMap[ChatMessage$.content](this.content)
                    : (_patchMap[ChatMessage$.content] is Patch)
                    ? _patchMap[ChatMessage$.content].applyTo(this.content)
                    : _patchMap[ChatMessage$.content])
                as String
          : this.content,
      timestamp: _patchMap.containsKey(ChatMessage$.timestamp)
          ? ((_patchMap[ChatMessage$.timestamp] is Function)
                    ? _patchMap[ChatMessage$.timestamp](this.timestamp)
                    : (_patchMap[ChatMessage$.timestamp] is Patch)
                    ? _patchMap[ChatMessage$.timestamp].applyTo(this.timestamp)
                    : _patchMap[ChatMessage$.timestamp])
                as DateTime
          : this.timestamp,
      products: _patchMap.containsKey(ChatMessage$.products)
          ? ((_patchMap[ChatMessage$.products] is Function)
                    ? _patchMap[ChatMessage$.products](this.products)
                    : (_patchMap[ChatMessage$.products] is Patch)
                    ? _patchMap[ChatMessage$.products].applyTo(this.products)
                    : _patchMap[ChatMessage$.products])
                as List<Listing>?
          : this.products,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        id == other.id &&
        role == other.role &&
        content == other.content &&
        timestamp == other.timestamp &&
        products == other.products;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.role,
      this.content,
      this.timestamp,
      this.products,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(' +
        'id: ${id}' +
        ', ' +
        'role: ${role}' +
        ', ' +
        'content: ${content}' +
        ', ' +
        'timestamp: ${timestamp}' +
        ', ' +
        'products: ${products})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        role == other.role &&
        content == other.content &&
        timestamp == other.timestamp &&
        products == other.products;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$ChatMessageToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ChatMessageToJson(this);
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

extension ChatMessagePropertyHelpers on ChatMessage {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get isRoleUser {
    return this.role == ChatMessageRole.user;
  }

  bool get isRoleAssistant {
    return this.role == ChatMessageRole.assistant;
  }

  bool get isRoleSystem {
    return this.role == ChatMessageRole.system;
  }

  bool get hasContent {
    return this.content.isNotEmpty;
  }

  bool get noContent {
    return this.content.isEmpty;
  }

  List<Listing> get productsRequired {
    return this.products ??
        (throw StateError('products is required but was null'));
  }

  bool get hasProducts {
    return this.products?.isNotEmpty ?? false;
  }

  bool get noProducts {
    return this.products?.isEmpty ?? true;
  }
}

extension ChatMessageSerialization on ChatMessage {
  Map<String, dynamic> toJson() {
    return _$ChatMessageToJson(this);
  }
}

enum ChatMessage$ { id, role, content, timestamp, products }

class ChatMessagePatch extends PatchBase<ChatMessage, ChatMessage$> {
  ChatMessage applyTo(ChatMessage entity) {
    return entity.patchWithChatMessage(this);
  }

  ChatMessagePatch withId(String? value) {
    patchMap[ChatMessage$.id] = value;
    return this;
  }

  ChatMessagePatch withRole(ChatMessageRole? value) {
    patchMap[ChatMessage$.role] = value;
    return this;
  }

  ChatMessagePatch withContent(String? value) {
    patchMap[ChatMessage$.content] = value;
    return this;
  }

  ChatMessagePatch withTimestamp(DateTime? value) {
    patchMap[ChatMessage$.timestamp] = value;
    return this;
  }

  ChatMessagePatch withProducts(List<Listing>? value) {
    patchMap[ChatMessage$.products] = value;
    return this;
  }

  ChatMessagePatch updateProductsAt(
    int index,
    ListingPatch Function(ListingPatch) patch,
  ) {
    patchMap[ChatMessage$.products] = (List<dynamic> list) {
      var updatedList = List<Listing>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          ListingPatch(),
        ).applyTo(updatedList[index] as Listing);
      }
      return updatedList;
    };
    return this;
  }
}

/// Field descriptors for [ChatMessage] query construction
abstract final class ChatMessageFields {
  static const id = Field<ChatMessage, String>('id', _$id);

  static const role = Field<ChatMessage, ChatMessageRole>('role', _$role);

  static const content = Field<ChatMessage, String>('content', _$content);

  static const timestamp = Field<ChatMessage, DateTime>(
    'timestamp',
    _$timestamp,
  );

  static const products = Field<ChatMessage, List<Listing>?>(
    'products',
    _$products,
  );

  static String _$id(ChatMessage e) {
    return e.id;
  }

  static ChatMessageRole _$role(ChatMessage e) {
    return e.role;
  }

  static String _$content(ChatMessage e) {
    return e.content;
  }

  static DateTime _$timestamp(ChatMessage e) {
    return e.timestamp;
  }

  static List<Listing>? _$products(ChatMessage e) {
    return e.products;
  }
}

extension ChatMessageCompareE on ChatMessage {
  Map<String, dynamic> compareToChatMessage(ChatMessage other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (role != other.role) {
      diff['role'] = () => other.role;
    }

    if (content != other.content) {
      diff['content'] = () => other.content;
    }

    if (timestamp != other.timestamp) {
      diff['timestamp'] = () => other.timestamp;
    }

    if (products != other.products) {
      diff['products'] = () => other.products;
    }
    return diff;
  }
}
