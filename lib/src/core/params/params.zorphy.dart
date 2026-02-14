// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class Params {
  final Map<String, dynamic>? params;

  const Params({this.params});

  Params copyWith({Map<String, dynamic>? params}) {
    return Params(params: params ?? this.params);
  }

  Params copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  Params patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.toPatch();
    return Params(
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
    return other is Params && params == other.params;
  }

  @override
  int get hashCode {
    return Object.hash(params, 0);
  }

  @override
  String toString() {
    return 'Params(' + 'params: ${params})';
  }

  /// Creates a [Params] instance from JSON
  factory Params.fromJson(Map<String, dynamic> json) => _$ParamsFromJson(json);

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ParamsToJson(this);
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

extension ParamsPropertyHelpers on Params {
  Map<String, dynamic> get paramsRequired =>
      params ?? (throw StateError('params is required but was null'));
  bool get hasParams => params?.isNotEmpty ?? false;
  bool get noParams => params?.isEmpty ?? true;
}

extension ParamsSerialization on Params {
  Map<String, dynamic> toJson() => _$ParamsToJson(this);
  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ParamsToJson(this);
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

enum Params$ { params }

class ParamsPatch implements Patch<Params> {
  final Map<Params$, dynamic> _patch = {};

  static ParamsPatch create([Map<String, dynamic>? diff]) {
    final patch = ParamsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = Params$.values.firstWhere((e) => e.name == key);
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

  static ParamsPatch fromPatch(Map<Params$, dynamic> patch) {
    final _patch = ParamsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<Params$, dynamic> toPatch() => Map.from(_patch);

  Params applyTo(Params entity) {
    return entity.patchWithParams(patchInput: this);
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

  static ParamsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  ParamsPatch withParams(Map<String, dynamic>? value) {
    _patch[Params$.params] = value;
    return this;
  }
}

/// Field descriptors for [Params] query construction
abstract final class ParamsFields {
  static Map<String, dynamic>? _$getparams(Params e) => e.params;
  static const params = Field<Params, Map<String, dynamic>?>(
    'params',
    _$getparams,
  );
}

extension ParamsCompareE on Params {
  Map<String, dynamic> compareToParams(Params other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    return diff;
  }
}
