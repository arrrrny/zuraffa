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
    final _patchMap = _patcher.patchMap;
    return Params(
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

enum Params$ { params }

class ParamsPatch extends PatchBase<Params, Params$> {
  Params applyTo(Params entity) {
    return entity.patchWithParams(patchInput: this);
  }

  ParamsPatch withParams(Map<String, dynamic>? value) {
    patchMap[Params$.params] = value;
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
