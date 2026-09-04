// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'credentials.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Credentials extends Params {
  const Credentials({Map<String, dynamic>? this.params}) : super();

  factory Credentials.fromJson(Map<String, dynamic> json) =>
      _$CredentialsFromJson(json);

  @override
  final Map<String, dynamic>? params;

  Credentials copyWith({Map<String, dynamic>? params}) {
    return Credentials(params: params ?? this.params);
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Credentials copyWithField<T>(Field<Credentials, T> field, T value) {
    switch (field.name) {
      case 'params':
        return copyWith(params: value as Map<String, dynamic>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Credentials has no settable field with this name',
        );
    }
  }

  Credentials copyWithCredentials({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  Credentials patchWithCredentials([CredentialsPatch? patchInput]) {
    final _patcher = patchInput ?? CredentialsPatch();
    final _patchMap = _patcher.patchMap;
    return Credentials(
      params: _patchMap.containsKey(Credentials$.params)
          ? ((_patchMap[Credentials$.params] is Function)
                    ? _patchMap[Credentials$.params](this.params)
                    : (_patchMap[Credentials$.params] is Patch)
                    ? _patchMap[Credentials$.params].applyTo(this.params)
                    : _patchMap[Credentials$.params])
                as Map<String, dynamic>?
          : this.params,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Credentials && params == other.params;
  }

  @override
  int get hashCode {
    return Object.hash(params, 0);
  }

  @override
  String toString() {
    return 'Credentials(' + 'params: ${params})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$CredentialsToJson(this);
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

extension CredentialsSerialization on Credentials {
  Map<String, dynamic> toJson() {
    return _$CredentialsToJson(this);
  }
}

enum Credentials$ { params }

class CredentialsPatch extends PatchBase<Credentials, Credentials$> {
  Credentials applyTo(Credentials entity) {
    return entity.patchWithCredentials(this);
  }

  CredentialsPatch withParams(Map<String, dynamic>? value) {
    patchMap[Credentials$.params] = value;
    return this;
  }
}

/// Field descriptors for [Credentials] query construction
abstract final class CredentialsFields {
  static const params = Field<Credentials, Map<String, dynamic>?>(
    'params',
    _$params,
  );

  static Map<String, dynamic>? _$params(Credentials e) {
    return e.params;
  }
}

extension CredentialsCompareE on Credentials {
  Map<String, dynamic> compareToCredentials(Credentials other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    return diff;
  }
}
