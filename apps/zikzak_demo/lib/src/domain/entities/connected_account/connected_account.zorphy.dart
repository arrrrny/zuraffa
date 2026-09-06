// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'connected_account.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ConnectedAccount {
  ConnectedAccount({
    required String this.id,
    required String this.retailerId,
    required String this.displayName,
    required String this.status,
    required String this.lastSyncedAt,
    required String this.createdAt,
  });

  factory ConnectedAccount.fromJson(Map<String, dynamic> json) =>
      _$ConnectedAccountFromJson(json);

  final String id;

  final String retailerId;

  final String displayName;

  final String status;

  final String lastSyncedAt;

  final String createdAt;

  ConnectedAccount copyWith({
    String? id,
    String? retailerId,
    String? displayName,
    String? status,
    String? lastSyncedAt,
    String? createdAt,
  }) {
    return ConnectedAccount(
      id: id ?? this.id,
      retailerId: retailerId ?? this.retailerId,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ConnectedAccount copyWithField<T>(Field<ConnectedAccount, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'retailerId':
        return copyWith(retailerId: value as String);
      case 'displayName':
        return copyWith(displayName: value as String);
      case 'status':
        return copyWith(status: value as String);
      case 'lastSyncedAt':
        return copyWith(lastSyncedAt: value as String);
      case 'createdAt':
        return copyWith(createdAt: value as String);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ConnectedAccount has no settable field with this name',
        );
    }
  }

  ConnectedAccount copyWithConnectedAccount({
    String? id,
    String? retailerId,
    String? displayName,
    String? status,
    String? lastSyncedAt,
    String? createdAt,
  }) {
    return copyWith(
      id: id,
      retailerId: retailerId,
      displayName: displayName,
      status: status,
      lastSyncedAt: lastSyncedAt,
      createdAt: createdAt,
    );
  }

  ConnectedAccount patchWithConnectedAccount([
    ConnectedAccountPatch? patchInput,
  ]) {
    final _patcher = patchInput ?? ConnectedAccountPatch();
    final _patchMap = _patcher.patchMap;
    return ConnectedAccount(
      id: _patchMap.containsKey(ConnectedAccount$.id)
          ? ((_patchMap[ConnectedAccount$.id] is Function)
                    ? _patchMap[ConnectedAccount$.id](this.id)
                    : (_patchMap[ConnectedAccount$.id] is Patch)
                    ? _patchMap[ConnectedAccount$.id].applyTo(this.id)
                    : _patchMap[ConnectedAccount$.id])
                as String
          : this.id,
      retailerId: _patchMap.containsKey(ConnectedAccount$.retailerId)
          ? ((_patchMap[ConnectedAccount$.retailerId] is Function)
                    ? _patchMap[ConnectedAccount$.retailerId](this.retailerId)
                    : (_patchMap[ConnectedAccount$.retailerId] is Patch)
                    ? _patchMap[ConnectedAccount$.retailerId].applyTo(
                        this.retailerId,
                      )
                    : _patchMap[ConnectedAccount$.retailerId])
                as String
          : this.retailerId,
      displayName: _patchMap.containsKey(ConnectedAccount$.displayName)
          ? ((_patchMap[ConnectedAccount$.displayName] is Function)
                    ? _patchMap[ConnectedAccount$.displayName](this.displayName)
                    : (_patchMap[ConnectedAccount$.displayName] is Patch)
                    ? _patchMap[ConnectedAccount$.displayName].applyTo(
                        this.displayName,
                      )
                    : _patchMap[ConnectedAccount$.displayName])
                as String
          : this.displayName,
      status: _patchMap.containsKey(ConnectedAccount$.status)
          ? ((_patchMap[ConnectedAccount$.status] is Function)
                    ? _patchMap[ConnectedAccount$.status](this.status)
                    : (_patchMap[ConnectedAccount$.status] is Patch)
                    ? _patchMap[ConnectedAccount$.status].applyTo(this.status)
                    : _patchMap[ConnectedAccount$.status])
                as String
          : this.status,
      lastSyncedAt: _patchMap.containsKey(ConnectedAccount$.lastSyncedAt)
          ? ((_patchMap[ConnectedAccount$.lastSyncedAt] is Function)
                    ? _patchMap[ConnectedAccount$.lastSyncedAt](
                        this.lastSyncedAt,
                      )
                    : (_patchMap[ConnectedAccount$.lastSyncedAt] is Patch)
                    ? _patchMap[ConnectedAccount$.lastSyncedAt].applyTo(
                        this.lastSyncedAt,
                      )
                    : _patchMap[ConnectedAccount$.lastSyncedAt])
                as String
          : this.lastSyncedAt,
      createdAt: _patchMap.containsKey(ConnectedAccount$.createdAt)
          ? ((_patchMap[ConnectedAccount$.createdAt] is Function)
                    ? _patchMap[ConnectedAccount$.createdAt](this.createdAt)
                    : (_patchMap[ConnectedAccount$.createdAt] is Patch)
                    ? _patchMap[ConnectedAccount$.createdAt].applyTo(
                        this.createdAt,
                      )
                    : _patchMap[ConnectedAccount$.createdAt])
                as String
          : this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectedAccount &&
        id == other.id &&
        retailerId == other.retailerId &&
        displayName == other.displayName &&
        status == other.status &&
        lastSyncedAt == other.lastSyncedAt &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.retailerId,
      this.displayName,
      this.status,
      this.lastSyncedAt,
      this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ConnectedAccount(' +
        'id: ${id}' +
        ', ' +
        'retailerId: ${retailerId}' +
        ', ' +
        'displayName: ${displayName}' +
        ', ' +
        'status: ${status}' +
        ', ' +
        'lastSyncedAt: ${lastSyncedAt}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ConnectedAccountToJson(this);
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

extension ConnectedAccountPropertyHelpers on ConnectedAccount {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasRetailerId {
    return this.retailerId.isNotEmpty;
  }

  bool get noRetailerId {
    return this.retailerId.isEmpty;
  }

  bool get hasDisplayName {
    return this.displayName.isNotEmpty;
  }

  bool get noDisplayName {
    return this.displayName.isEmpty;
  }

  bool get hasStatus {
    return this.status.isNotEmpty;
  }

  bool get noStatus {
    return this.status.isEmpty;
  }

  bool get hasLastSyncedAt {
    return this.lastSyncedAt.isNotEmpty;
  }

  bool get noLastSyncedAt {
    return this.lastSyncedAt.isEmpty;
  }

  bool get hasCreatedAt {
    return this.createdAt.isNotEmpty;
  }

  bool get noCreatedAt {
    return this.createdAt.isEmpty;
  }
}

extension ConnectedAccountSerialization on ConnectedAccount {
  Map<String, dynamic> toJson() {
    return _$ConnectedAccountToJson(this);
  }
}

enum ConnectedAccount$ {
  id,
  retailerId,
  displayName,
  status,
  lastSyncedAt,
  createdAt,
}

class ConnectedAccountPatch
    extends PatchBase<ConnectedAccount, ConnectedAccount$> {
  ConnectedAccount applyTo(ConnectedAccount entity) {
    return entity.patchWithConnectedAccount(this);
  }

  ConnectedAccountPatch withId(String? value) {
    patchMap[ConnectedAccount$.id] = value;
    return this;
  }

  ConnectedAccountPatch withRetailerId(String? value) {
    patchMap[ConnectedAccount$.retailerId] = value;
    return this;
  }

  ConnectedAccountPatch withDisplayName(String? value) {
    patchMap[ConnectedAccount$.displayName] = value;
    return this;
  }

  ConnectedAccountPatch withStatus(String? value) {
    patchMap[ConnectedAccount$.status] = value;
    return this;
  }

  ConnectedAccountPatch withLastSyncedAt(String? value) {
    patchMap[ConnectedAccount$.lastSyncedAt] = value;
    return this;
  }

  ConnectedAccountPatch withCreatedAt(String? value) {
    patchMap[ConnectedAccount$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [ConnectedAccount] query construction
abstract final class ConnectedAccountFields {
  static const id = Field<ConnectedAccount, String>('id', _$id);

  static const retailerId = Field<ConnectedAccount, String>(
    'retailerId',
    _$retailerId,
  );

  static const displayName = Field<ConnectedAccount, String>(
    'displayName',
    _$displayName,
  );

  static const status = Field<ConnectedAccount, String>('status', _$status);

  static const lastSyncedAt = Field<ConnectedAccount, String>(
    'lastSyncedAt',
    _$lastSyncedAt,
  );

  static const createdAt = Field<ConnectedAccount, String>(
    'createdAt',
    _$createdAt,
  );

  static String _$id(ConnectedAccount e) {
    return e.id;
  }

  static String _$retailerId(ConnectedAccount e) {
    return e.retailerId;
  }

  static String _$displayName(ConnectedAccount e) {
    return e.displayName;
  }

  static String _$status(ConnectedAccount e) {
    return e.status;
  }

  static String _$lastSyncedAt(ConnectedAccount e) {
    return e.lastSyncedAt;
  }

  static String _$createdAt(ConnectedAccount e) {
    return e.createdAt;
  }
}

extension ConnectedAccountCompareE on ConnectedAccount {
  Map<String, dynamic> compareToConnectedAccount(ConnectedAccount other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (retailerId != other.retailerId) {
      diff['retailerId'] = () => other.retailerId;
    }

    if (displayName != other.displayName) {
      diff['displayName'] = () => other.displayName;
    }

    if (status != other.status) {
      diff['status'] = () => other.status;
    }

    if (lastSyncedAt != other.lastSyncedAt) {
      diff['lastSyncedAt'] = () => other.lastSyncedAt;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
