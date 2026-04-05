// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'credentials.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class Credentials extends Params {
  const Credentials({Map<String, dynamic>? params}) : super(params: params);

  Credentials copyWith({Map<String, dynamic>? params}) {
    return Credentials(params: params ?? this.params);
  }

  Credentials copyWithCredentials({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  Credentials copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  Credentials patchWithCredentials({CredentialsPatch? patchInput}) {
    final _patcher = patchInput ?? CredentialsPatch();
    final _patchMap = _patcher.patchMap;
    return Credentials(
      params: _patchMap.containsKey(Credentials$.params)
          ? (_patchMap[Credentials$.params] is Function)
                ? _patchMap[Credentials$.params](this.params)
                : (_patchMap[Credentials$.params] is Patch)
                ? _patchMap[Credentials$.params].applyTo(this.params)
                : _patchMap[Credentials$.params]
          : this.params,
    );
  }

  Credentials patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.patchMap;
    return Credentials(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : (_patchMap[Params$.params] is Patch)
                ? _patchMap[Params$.params].applyTo(this.params)
                : _patchMap[Params$.params]
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

  /// Creates a [Credentials] instance from JSON
  factory Credentials.fromJson(Map<String, dynamic> json) =>
      _$CredentialsFromJson(json);

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$CredentialsToJson(this);
    return _sanitizeJson(data);
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
  Map<String, dynamic> toJson() => _$CredentialsToJson(this);
  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$CredentialsToJson(this);
    return _sanitizeJson(data);
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

enum Credentials$ { params }

class CredentialsPatch extends PatchBase<Credentials, Credentials$> {
  Credentials applyTo(Credentials entity) {
    return entity.patchWithCredentials(patchInput: this);
  }

  CredentialsPatch withParams(Map<String, dynamic>? value) {
    patchMap[Credentials$.params] = value;
    return this;
  }
}

/// Field descriptors for [Credentials] query construction
abstract final class CredentialsFields {
  static Map<String, dynamic>? _$getparams(Credentials e) => e.params;
  static const params = Field<Credentials, Map<String, dynamic>?>(
    'params',
    _$getparams,
  );
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
