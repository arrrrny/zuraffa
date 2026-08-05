// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

abstract class Params {
  const Params();

  Map<String, dynamic>? get params;
}

extension ParamsPropertyHelpers on Params {
  Map<String, dynamic> get paramsRequired {
    return params ?? (throw StateError('params is required but was null'));
  }

  bool get hasParams {
    return params?.isNotEmpty ?? false;
  }

  bool get noParams {
    return params?.isEmpty ?? true;
  }
}

/// Field descriptors for [Params] query construction
abstract final class ParamsFields {
  static const params = Field<Params, Map<String, dynamic>?>(
    'params',
    _$params,
  );

  static Map<String, dynamic>? _$params(Params e) {
    return e.params;
  }
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
