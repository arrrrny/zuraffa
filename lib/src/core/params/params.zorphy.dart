// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

abstract class Params {
  Map<String, dynamic>? get params;

  const Params();
}

extension ParamsPropertyHelpers on Params {
  Map<String, dynamic> get paramsRequired =>
      params ?? (throw StateError('params is required but was null'));
  bool get hasParams => params?.isNotEmpty ?? false;
  bool get noParams => params?.isEmpty ?? true;
}

enum Params$ { params }

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
