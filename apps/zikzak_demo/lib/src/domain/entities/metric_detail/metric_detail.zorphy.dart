// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'metric_detail.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class MetricDetail {
  MetricDetail({
    required String this.name,
    required int this.score,
    String? this.label,
  });

  factory MetricDetail.fromJson(Map<String, dynamic> json) =>
      _$MetricDetailFromJson(json);

  final String name;

  final int score;

  final String? label;

  MetricDetail copyWith({String? name, int? score, String? label}) {
    return MetricDetail(
      name: name ?? this.name,
      score: score ?? this.score,
      label: label ?? this.label,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  MetricDetail copyWithField<T>(Field<MetricDetail, T> field, T value) {
    switch (field.name) {
      case 'name':
        return copyWith(name: value as String);
      case 'score':
        return copyWith(score: value as int);
      case 'label':
        return copyWith(label: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'MetricDetail has no settable field with this name',
        );
    }
  }

  MetricDetail copyWithMetricDetail({String? name, int? score, String? label}) {
    return copyWith(name: name, score: score, label: label);
  }

  MetricDetail patchWithMetricDetail([MetricDetailPatch? patchInput]) {
    final _patcher = patchInput ?? MetricDetailPatch();
    final _patchMap = _patcher.patchMap;
    return MetricDetail(
      name: _patchMap.containsKey(MetricDetail$.name_)
          ? ((_patchMap[MetricDetail$.name_] is Function)
                    ? _patchMap[MetricDetail$.name_](this.name)
                    : (_patchMap[MetricDetail$.name_] is Patch)
                    ? _patchMap[MetricDetail$.name_].applyTo(this.name)
                    : _patchMap[MetricDetail$.name_])
                as String
          : this.name,
      score: _patchMap.containsKey(MetricDetail$.score)
          ? ((_patchMap[MetricDetail$.score] is Function)
                    ? _patchMap[MetricDetail$.score](this.score)
                    : (_patchMap[MetricDetail$.score] is Patch)
                    ? _patchMap[MetricDetail$.score].applyTo(this.score)
                    : _patchMap[MetricDetail$.score])
                as int
          : this.score,
      label: _patchMap.containsKey(MetricDetail$.label)
          ? ((_patchMap[MetricDetail$.label] is Function)
                    ? _patchMap[MetricDetail$.label](this.label)
                    : (_patchMap[MetricDetail$.label] is Patch)
                    ? _patchMap[MetricDetail$.label].applyTo(this.label)
                    : _patchMap[MetricDetail$.label])
                as String?
          : this.label,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MetricDetail &&
        name == other.name &&
        score == other.score &&
        label == other.label;
  }

  @override
  int get hashCode {
    return Object.hash(this.name, this.score, this.label);
  }

  @override
  String toString() {
    return 'MetricDetail(' +
        'name: ${name}' +
        ', ' +
        'score: ${score}' +
        ', ' +
        'label: ${label})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$MetricDetailToJson(this);
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

extension MetricDetailPropertyHelpers on MetricDetail {
  bool get hasName {
    return this.name.isNotEmpty;
  }

  bool get noName {
    return this.name.isEmpty;
  }

  bool get hasLabel {
    return this.label?.isNotEmpty == true;
  }

  bool get noLabel {
    return this.label?.isEmpty ?? true;
  }

  String get labelRequired {
    return this.label ?? (throw StateError('label is required but was null'));
  }
}

extension MetricDetailSerialization on MetricDetail {
  Map<String, dynamic> toJson() {
    return _$MetricDetailToJson(this);
  }
}

enum MetricDetail$ { name_, score, label }

class MetricDetailPatch extends PatchBase<MetricDetail, MetricDetail$> {
  MetricDetail applyTo(MetricDetail entity) {
    return entity.patchWithMetricDetail(this);
  }

  MetricDetailPatch withName(String? value) {
    patchMap[MetricDetail$.name_] = value;
    return this;
  }

  MetricDetailPatch withScore(int? value) {
    patchMap[MetricDetail$.score] = value;
    return this;
  }

  MetricDetailPatch withLabel(String? value) {
    patchMap[MetricDetail$.label] = value;
    return this;
  }
}

/// Field descriptors for [MetricDetail] query construction
abstract final class MetricDetailFields {
  static const name = Field<MetricDetail, String>('name', _$name);

  static const score = Field<MetricDetail, int>('score', _$score);

  static const label = Field<MetricDetail, String?>('label', _$label);

  static String _$name(MetricDetail e) {
    return e.name;
  }

  static int _$score(MetricDetail e) {
    return e.score;
  }

  static String? _$label(MetricDetail e) {
    return e.label;
  }
}

extension MetricDetailCompareE on MetricDetail {
  Map<String, dynamic> compareToMetricDetail(MetricDetail other) {
    final Map<String, dynamic> diff = {};

    if (name != other.name) {
      diff['name'] = () => other.name;
    }

    if (score != other.score) {
      diff['score'] = () => other.score;
    }

    if (label != other.label) {
      diff['label'] = () => other.label;
    }
    return diff;
  }
}
