// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'zik_zak_score.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ZikZakScore {
  ZikZakScore({
    String? this.id,
    String? this.barcode,
    String? this.url,
    String? this.title,
    required int this.totalScore,
    required int this.authenticityScore,
    required int this.brandScore,
    required int this.performanceScore,
    required int this.valueScore,
    required int this.competitionScore,
    required DateTime this.calculatedAt,
    required bool this.isCached,
    required List<MetricDetail> this.metrics,
  });

  factory ZikZakScore.fromJson(Map<String, dynamic> json) =>
      _$ZikZakScoreFromJson(json);

  final String? id;

  final String? barcode;

  final String? url;

  final String? title;

  final int totalScore;

  final int authenticityScore;

  final int brandScore;

  final int performanceScore;

  final int valueScore;

  final int competitionScore;

  final DateTime calculatedAt;

  final bool isCached;

  final List<MetricDetail> metrics;

  ZikZakScore copyWith({
    String? id,
    String? barcode,
    String? url,
    String? title,
    int? totalScore,
    int? authenticityScore,
    int? brandScore,
    int? performanceScore,
    int? valueScore,
    int? competitionScore,
    DateTime? calculatedAt,
    bool? isCached,
    List<MetricDetail>? metrics,
  }) {
    return ZikZakScore(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      url: url ?? this.url,
      title: title ?? this.title,
      totalScore: totalScore ?? this.totalScore,
      authenticityScore: authenticityScore ?? this.authenticityScore,
      brandScore: brandScore ?? this.brandScore,
      performanceScore: performanceScore ?? this.performanceScore,
      valueScore: valueScore ?? this.valueScore,
      competitionScore: competitionScore ?? this.competitionScore,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      isCached: isCached ?? this.isCached,
      metrics: metrics ?? this.metrics,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ZikZakScore copyWithField<T>(Field<ZikZakScore, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String?);
      case 'barcode':
        return copyWith(barcode: value as String?);
      case 'url':
        return copyWith(url: value as String?);
      case 'title':
        return copyWith(title: value as String?);
      case 'totalScore':
        return copyWith(totalScore: value as int);
      case 'authenticityScore':
        return copyWith(authenticityScore: value as int);
      case 'brandScore':
        return copyWith(brandScore: value as int);
      case 'performanceScore':
        return copyWith(performanceScore: value as int);
      case 'valueScore':
        return copyWith(valueScore: value as int);
      case 'competitionScore':
        return copyWith(competitionScore: value as int);
      case 'calculatedAt':
        return copyWith(calculatedAt: value as DateTime);
      case 'isCached':
        return copyWith(isCached: value as bool);
      case 'metrics':
        return copyWith(metrics: value as List<MetricDetail>);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ZikZakScore has no settable field with this name',
        );
    }
  }

  ZikZakScore copyWithZikZakScore({
    String? id,
    String? barcode,
    String? url,
    String? title,
    int? totalScore,
    int? authenticityScore,
    int? brandScore,
    int? performanceScore,
    int? valueScore,
    int? competitionScore,
    DateTime? calculatedAt,
    bool? isCached,
    List<MetricDetail>? metrics,
  }) {
    return copyWith(
      id: id,
      barcode: barcode,
      url: url,
      title: title,
      totalScore: totalScore,
      authenticityScore: authenticityScore,
      brandScore: brandScore,
      performanceScore: performanceScore,
      valueScore: valueScore,
      competitionScore: competitionScore,
      calculatedAt: calculatedAt,
      isCached: isCached,
      metrics: metrics,
    );
  }

  ZikZakScore patchWithZikZakScore([ZikZakScorePatch? patchInput]) {
    final _patcher = patchInput ?? ZikZakScorePatch();
    final _patchMap = _patcher.patchMap;
    return ZikZakScore(
      id: _patchMap.containsKey(ZikZakScore$.id)
          ? ((_patchMap[ZikZakScore$.id] is Function)
                    ? _patchMap[ZikZakScore$.id](this.id)
                    : (_patchMap[ZikZakScore$.id] is Patch)
                    ? _patchMap[ZikZakScore$.id].applyTo(this.id)
                    : _patchMap[ZikZakScore$.id])
                as String?
          : this.id,
      barcode: _patchMap.containsKey(ZikZakScore$.barcode)
          ? ((_patchMap[ZikZakScore$.barcode] is Function)
                    ? _patchMap[ZikZakScore$.barcode](this.barcode)
                    : (_patchMap[ZikZakScore$.barcode] is Patch)
                    ? _patchMap[ZikZakScore$.barcode].applyTo(this.barcode)
                    : _patchMap[ZikZakScore$.barcode])
                as String?
          : this.barcode,
      url: _patchMap.containsKey(ZikZakScore$.url)
          ? ((_patchMap[ZikZakScore$.url] is Function)
                    ? _patchMap[ZikZakScore$.url](this.url)
                    : (_patchMap[ZikZakScore$.url] is Patch)
                    ? _patchMap[ZikZakScore$.url].applyTo(this.url)
                    : _patchMap[ZikZakScore$.url])
                as String?
          : this.url,
      title: _patchMap.containsKey(ZikZakScore$.title)
          ? ((_patchMap[ZikZakScore$.title] is Function)
                    ? _patchMap[ZikZakScore$.title](this.title)
                    : (_patchMap[ZikZakScore$.title] is Patch)
                    ? _patchMap[ZikZakScore$.title].applyTo(this.title)
                    : _patchMap[ZikZakScore$.title])
                as String?
          : this.title,
      totalScore: _patchMap.containsKey(ZikZakScore$.totalScore)
          ? ((_patchMap[ZikZakScore$.totalScore] is Function)
                    ? _patchMap[ZikZakScore$.totalScore](this.totalScore)
                    : (_patchMap[ZikZakScore$.totalScore] is Patch)
                    ? _patchMap[ZikZakScore$.totalScore].applyTo(
                        this.totalScore,
                      )
                    : _patchMap[ZikZakScore$.totalScore])
                as int
          : this.totalScore,
      authenticityScore: _patchMap.containsKey(ZikZakScore$.authenticityScore)
          ? ((_patchMap[ZikZakScore$.authenticityScore] is Function)
                    ? _patchMap[ZikZakScore$.authenticityScore](
                        this.authenticityScore,
                      )
                    : (_patchMap[ZikZakScore$.authenticityScore] is Patch)
                    ? _patchMap[ZikZakScore$.authenticityScore].applyTo(
                        this.authenticityScore,
                      )
                    : _patchMap[ZikZakScore$.authenticityScore])
                as int
          : this.authenticityScore,
      brandScore: _patchMap.containsKey(ZikZakScore$.brandScore)
          ? ((_patchMap[ZikZakScore$.brandScore] is Function)
                    ? _patchMap[ZikZakScore$.brandScore](this.brandScore)
                    : (_patchMap[ZikZakScore$.brandScore] is Patch)
                    ? _patchMap[ZikZakScore$.brandScore].applyTo(
                        this.brandScore,
                      )
                    : _patchMap[ZikZakScore$.brandScore])
                as int
          : this.brandScore,
      performanceScore: _patchMap.containsKey(ZikZakScore$.performanceScore)
          ? ((_patchMap[ZikZakScore$.performanceScore] is Function)
                    ? _patchMap[ZikZakScore$.performanceScore](
                        this.performanceScore,
                      )
                    : (_patchMap[ZikZakScore$.performanceScore] is Patch)
                    ? _patchMap[ZikZakScore$.performanceScore].applyTo(
                        this.performanceScore,
                      )
                    : _patchMap[ZikZakScore$.performanceScore])
                as int
          : this.performanceScore,
      valueScore: _patchMap.containsKey(ZikZakScore$.valueScore)
          ? ((_patchMap[ZikZakScore$.valueScore] is Function)
                    ? _patchMap[ZikZakScore$.valueScore](this.valueScore)
                    : (_patchMap[ZikZakScore$.valueScore] is Patch)
                    ? _patchMap[ZikZakScore$.valueScore].applyTo(
                        this.valueScore,
                      )
                    : _patchMap[ZikZakScore$.valueScore])
                as int
          : this.valueScore,
      competitionScore: _patchMap.containsKey(ZikZakScore$.competitionScore)
          ? ((_patchMap[ZikZakScore$.competitionScore] is Function)
                    ? _patchMap[ZikZakScore$.competitionScore](
                        this.competitionScore,
                      )
                    : (_patchMap[ZikZakScore$.competitionScore] is Patch)
                    ? _patchMap[ZikZakScore$.competitionScore].applyTo(
                        this.competitionScore,
                      )
                    : _patchMap[ZikZakScore$.competitionScore])
                as int
          : this.competitionScore,
      calculatedAt: _patchMap.containsKey(ZikZakScore$.calculatedAt)
          ? ((_patchMap[ZikZakScore$.calculatedAt] is Function)
                    ? _patchMap[ZikZakScore$.calculatedAt](this.calculatedAt)
                    : (_patchMap[ZikZakScore$.calculatedAt] is Patch)
                    ? _patchMap[ZikZakScore$.calculatedAt].applyTo(
                        this.calculatedAt,
                      )
                    : _patchMap[ZikZakScore$.calculatedAt])
                as DateTime
          : this.calculatedAt,
      isCached: _patchMap.containsKey(ZikZakScore$.isCached)
          ? ((_patchMap[ZikZakScore$.isCached] is Function)
                    ? _patchMap[ZikZakScore$.isCached](this.isCached)
                    : (_patchMap[ZikZakScore$.isCached] is Patch)
                    ? _patchMap[ZikZakScore$.isCached].applyTo(this.isCached)
                    : _patchMap[ZikZakScore$.isCached])
                as bool
          : this.isCached,
      metrics: _patchMap.containsKey(ZikZakScore$.metrics)
          ? ((_patchMap[ZikZakScore$.metrics] is Function)
                    ? _patchMap[ZikZakScore$.metrics](this.metrics)
                    : (_patchMap[ZikZakScore$.metrics] is Patch)
                    ? _patchMap[ZikZakScore$.metrics].applyTo(this.metrics)
                    : _patchMap[ZikZakScore$.metrics])
                as List<MetricDetail>
          : this.metrics,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZikZakScore &&
        id == other.id &&
        barcode == other.barcode &&
        url == other.url &&
        title == other.title &&
        totalScore == other.totalScore &&
        authenticityScore == other.authenticityScore &&
        brandScore == other.brandScore &&
        performanceScore == other.performanceScore &&
        valueScore == other.valueScore &&
        competitionScore == other.competitionScore &&
        calculatedAt == other.calculatedAt &&
        isCached == other.isCached &&
        metrics == other.metrics;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.barcode,
      this.url,
      this.title,
      this.totalScore,
      this.authenticityScore,
      this.brandScore,
      this.performanceScore,
      this.valueScore,
      this.competitionScore,
      this.calculatedAt,
      this.isCached,
      this.metrics,
    );
  }

  @override
  String toString() {
    return 'ZikZakScore(' +
        'id: ${id}' +
        ', ' +
        'barcode: ${barcode}' +
        ', ' +
        'url: ${url}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'totalScore: ${totalScore}' +
        ', ' +
        'authenticityScore: ${authenticityScore}' +
        ', ' +
        'brandScore: ${brandScore}' +
        ', ' +
        'performanceScore: ${performanceScore}' +
        ', ' +
        'valueScore: ${valueScore}' +
        ', ' +
        'competitionScore: ${competitionScore}' +
        ', ' +
        'calculatedAt: ${calculatedAt}' +
        ', ' +
        'isCached: ${isCached}' +
        ', ' +
        'metrics: ${metrics})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ZikZakScoreToJson(this);
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

extension ZikZakScorePropertyHelpers on ZikZakScore {
  bool get hasId {
    return this.id?.isNotEmpty == true;
  }

  bool get noId {
    return this.id?.isEmpty ?? true;
  }

  String get idRequired {
    return this.id ?? (throw StateError('id is required but was null'));
  }

  bool get hasBarcode {
    return this.barcode?.isNotEmpty == true;
  }

  bool get noBarcode {
    return this.barcode?.isEmpty ?? true;
  }

  String get barcodeRequired {
    return this.barcode ??
        (throw StateError('barcode is required but was null'));
  }

  bool get hasUrl {
    return this.url?.isNotEmpty == true;
  }

  bool get noUrl {
    return this.url?.isEmpty ?? true;
  }

  String get urlRequired {
    return this.url ?? (throw StateError('url is required but was null'));
  }

  bool get hasTitle {
    return this.title?.isNotEmpty == true;
  }

  bool get noTitle {
    return this.title?.isEmpty ?? true;
  }

  String get titleRequired {
    return this.title ?? (throw StateError('title is required but was null'));
  }

  bool get hasMetrics {
    return this.metrics.isNotEmpty;
  }

  bool get noMetrics {
    return this.metrics.isEmpty;
  }
}

extension ZikZakScoreSerialization on ZikZakScore {
  Map<String, dynamic> toJson() {
    return _$ZikZakScoreToJson(this);
  }
}

enum ZikZakScore$ {
  id,
  barcode,
  url,
  title,
  totalScore,
  authenticityScore,
  brandScore,
  performanceScore,
  valueScore,
  competitionScore,
  calculatedAt,
  isCached,
  metrics,
}

class ZikZakScorePatch extends PatchBase<ZikZakScore, ZikZakScore$> {
  ZikZakScore applyTo(ZikZakScore entity) {
    return entity.patchWithZikZakScore(this);
  }

  ZikZakScorePatch withId(String? value) {
    patchMap[ZikZakScore$.id] = value;
    return this;
  }

  ZikZakScorePatch withBarcode(String? value) {
    patchMap[ZikZakScore$.barcode] = value;
    return this;
  }

  ZikZakScorePatch withUrl(String? value) {
    patchMap[ZikZakScore$.url] = value;
    return this;
  }

  ZikZakScorePatch withTitle(String? value) {
    patchMap[ZikZakScore$.title] = value;
    return this;
  }

  ZikZakScorePatch withTotalScore(int? value) {
    patchMap[ZikZakScore$.totalScore] = value;
    return this;
  }

  ZikZakScorePatch withAuthenticityScore(int? value) {
    patchMap[ZikZakScore$.authenticityScore] = value;
    return this;
  }

  ZikZakScorePatch withBrandScore(int? value) {
    patchMap[ZikZakScore$.brandScore] = value;
    return this;
  }

  ZikZakScorePatch withPerformanceScore(int? value) {
    patchMap[ZikZakScore$.performanceScore] = value;
    return this;
  }

  ZikZakScorePatch withValueScore(int? value) {
    patchMap[ZikZakScore$.valueScore] = value;
    return this;
  }

  ZikZakScorePatch withCompetitionScore(int? value) {
    patchMap[ZikZakScore$.competitionScore] = value;
    return this;
  }

  ZikZakScorePatch withCalculatedAt(DateTime? value) {
    patchMap[ZikZakScore$.calculatedAt] = value;
    return this;
  }

  ZikZakScorePatch withIsCached(bool? value) {
    patchMap[ZikZakScore$.isCached] = value;
    return this;
  }

  ZikZakScorePatch withMetrics(List<MetricDetail>? value) {
    patchMap[ZikZakScore$.metrics] = value;
    return this;
  }

  ZikZakScorePatch updateMetricsAt(
    int index,
    MetricDetailPatch Function(MetricDetailPatch) patch,
  ) {
    patchMap[ZikZakScore$.metrics] = (List<dynamic> list) {
      var updatedList = List<MetricDetail>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          MetricDetailPatch(),
        ).applyTo(updatedList[index] as MetricDetail);
      }
      return updatedList;
    };
    return this;
  }
}

/// Field descriptors for [ZikZakScore] query construction
abstract final class ZikZakScoreFields {
  static const id = Field<ZikZakScore, String?>('id', _$id);

  static const barcode = Field<ZikZakScore, String?>('barcode', _$barcode);

  static const url = Field<ZikZakScore, String?>('url', _$url);

  static const title = Field<ZikZakScore, String?>('title', _$title);

  static const totalScore = Field<ZikZakScore, int>('totalScore', _$totalScore);

  static const authenticityScore = Field<ZikZakScore, int>(
    'authenticityScore',
    _$authenticityScore,
  );

  static const brandScore = Field<ZikZakScore, int>('brandScore', _$brandScore);

  static const performanceScore = Field<ZikZakScore, int>(
    'performanceScore',
    _$performanceScore,
  );

  static const valueScore = Field<ZikZakScore, int>('valueScore', _$valueScore);

  static const competitionScore = Field<ZikZakScore, int>(
    'competitionScore',
    _$competitionScore,
  );

  static const calculatedAt = Field<ZikZakScore, DateTime>(
    'calculatedAt',
    _$calculatedAt,
  );

  static const isCached = Field<ZikZakScore, bool>('isCached', _$isCached);

  static const metrics = Field<ZikZakScore, List<MetricDetail>>(
    'metrics',
    _$metrics,
  );

  static String? _$id(ZikZakScore e) {
    return e.id;
  }

  static String? _$barcode(ZikZakScore e) {
    return e.barcode;
  }

  static String? _$url(ZikZakScore e) {
    return e.url;
  }

  static String? _$title(ZikZakScore e) {
    return e.title;
  }

  static int _$totalScore(ZikZakScore e) {
    return e.totalScore;
  }

  static int _$authenticityScore(ZikZakScore e) {
    return e.authenticityScore;
  }

  static int _$brandScore(ZikZakScore e) {
    return e.brandScore;
  }

  static int _$performanceScore(ZikZakScore e) {
    return e.performanceScore;
  }

  static int _$valueScore(ZikZakScore e) {
    return e.valueScore;
  }

  static int _$competitionScore(ZikZakScore e) {
    return e.competitionScore;
  }

  static DateTime _$calculatedAt(ZikZakScore e) {
    return e.calculatedAt;
  }

  static bool _$isCached(ZikZakScore e) {
    return e.isCached;
  }

  static List<MetricDetail> _$metrics(ZikZakScore e) {
    return e.metrics;
  }
}

extension ZikZakScoreCompareE on ZikZakScore {
  Map<String, dynamic> compareToZikZakScore(ZikZakScore other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (barcode != other.barcode) {
      diff['barcode'] = () => other.barcode;
    }

    if (url != other.url) {
      diff['url'] = () => other.url;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (totalScore != other.totalScore) {
      diff['totalScore'] = () => other.totalScore;
    }

    if (authenticityScore != other.authenticityScore) {
      diff['authenticityScore'] = () => other.authenticityScore;
    }

    if (brandScore != other.brandScore) {
      diff['brandScore'] = () => other.brandScore;
    }

    if (performanceScore != other.performanceScore) {
      diff['performanceScore'] = () => other.performanceScore;
    }

    if (valueScore != other.valueScore) {
      diff['valueScore'] = () => other.valueScore;
    }

    if (competitionScore != other.competitionScore) {
      diff['competitionScore'] = () => other.competitionScore;
    }

    if (calculatedAt != other.calculatedAt) {
      diff['calculatedAt'] = () => other.calculatedAt;
    }

    if (isCached != other.isCached) {
      diff['isCached'] = () => other.isCached;
    }

    if (metrics != other.metrics) {
      diff['metrics'] = () => other.metrics;
    }
    return diff;
  }
}
