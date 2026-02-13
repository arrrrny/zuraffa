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
    final _patchMap = _patcher.toPatch();
    return Credentials(
      params: _patchMap.containsKey(Credentials$.params)
          ? (_patchMap[Credentials$.params] is Function)
                ? _patchMap[Credentials$.params](this.params)
                : _patchMap[Credentials$.params]
          : this.params,
    );
  }

  Credentials patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.toPatch();
    return Credentials(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
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
      json.remove('_className_');
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
    final data = _$CredentialsToJson(this);
    data['params'] = params;
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$CredentialsToJson(this);
    if (params != null) data['params'] = params;
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
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

class CredentialsPatch implements Patch<Credentials> {
  final Map<Credentials$, dynamic> _patch = {};

  static CredentialsPatch create([Map<String, dynamic>? diff]) {
    final patch = CredentialsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = Credentials$.values.firstWhere(
            (e) => e.name == key,
          );
          if (value is Function) {
            patch._patch[enumValue] = value();
          } else {
            patch._patch[enumValue] = value;
          }
        } catch (_) {}
      });
    }
    return patch;
  }

  static CredentialsPatch fromPatch(Map<Credentials$, dynamic> patch) {
    final _patch = CredentialsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<Credentials$, dynamic> toPatch() => Map.from(_patch);

  Credentials applyTo(Credentials entity) {
    return entity.patchWithCredentials(patchInput: this);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    _patch.forEach((key, value) {
      if (value != null) {
        if (value is Function) {
          final result = value();
          json[key.name] = _convertToJson(result);
        } else {
          json[key.name] = _convertToJson(value);
        }
      }
    });
    return json;
  }

  dynamic _convertToJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Enum) return value.toString().split('.').last;
    if (value is List) return value.map((e) => _convertToJson(e)).toList();
    if (value is Map)
      return value.map((k, v) => MapEntry(k.toString(), _convertToJson(v)));
    if (value is num || value is bool || value is String) return value;
    try {
      if (value?.toJsonLean != null) return value.toJsonLean();
    } catch (_) {}
    if (value?.toJson != null) return value.toJson();
    return value.toString();
  }

  static CredentialsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  CredentialsPatch withParams(Map<String, dynamic>? value) {
    _patch[Credentials$.params] = value;
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
