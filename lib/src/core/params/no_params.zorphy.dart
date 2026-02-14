// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'no_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

class NoParams {
  const NoParams();

  NoParams copyWith() {
    return NoParams();
  }

  NoParams copyWithNoParams() {
    return copyWith();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoParams;
  }

  @override
  int get hashCode {
    return 0;
  }

  @override
  String toString() {
    return 'NoParams()';
  }
}

extension NoParamsCompareE on NoParams {
  Map<String, dynamic> compareToNoParams(NoParams other) {
    final Map<String, dynamic> diff = {};

    return diff;
  }
}
