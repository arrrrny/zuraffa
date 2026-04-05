// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'concert.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class Concert {
  final String id;
  final String artist;

  Concert({required this.id, required this.artist});

  Concert copyWith({String? id, String? artist}) {
    return Concert(id: id ?? this.id, artist: artist ?? this.artist);
  }

  Concert copyWithConcert({String? id, String? artist}) {
    return copyWith(id: id, artist: artist);
  }

  Concert patchWithConcert({ConcertPatch? patchInput}) {
    final _patcher = patchInput ?? ConcertPatch();
    final _patchMap = _patcher.toPatch();
    return Concert(
      id: _patchMap.containsKey(Concert$.id)
          ? (_patchMap[Concert$.id] is Function)
                ? _patchMap[Concert$.id](this.id)
                : (_patchMap[Concert$.id] is Patch)
                ? _patchMap[Concert$.id].applyTo(this.id)
                : _patchMap[Concert$.id]
          : this.id,
      artist: _patchMap.containsKey(Concert$.artist)
          ? (_patchMap[Concert$.artist] is Function)
                ? _patchMap[Concert$.artist](this.artist)
                : (_patchMap[Concert$.artist] is Patch)
                ? _patchMap[Concert$.artist].applyTo(this.artist)
                : _patchMap[Concert$.artist]
          : this.artist,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Concert && id == other.id && artist == other.artist;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.artist);
  }

  @override
  String toString() {
    return 'Concert(' + 'id: ${id}' + ', ' + 'artist: ${artist})';
  }

  /// Creates a [Concert] instance from JSON
  factory Concert.fromJson(Map<String, dynamic> json) =>
      _$ConcertFromJson(json);

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ConcertToJson(this);
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

extension ConcertPropertyHelpers on Concert {}

extension ConcertSerialization on Concert {
  Map<String, dynamic> toJson() => _$ConcertToJson(this);
  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ConcertToJson(this);
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

enum Concert$ { id, artist }

class ConcertPatch implements Patch<Concert> {
  final Map<Concert$, dynamic> _patch = {};

  static ConcertPatch create([Map<String, dynamic>? diff]) {
    final patch = ConcertPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = Concert$.values.firstWhere((e) => e.name == key);
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

  static ConcertPatch fromPatch(Map<Concert$, dynamic> patch) {
    final _patch = ConcertPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<Concert$, dynamic> toPatch() => Map.from(_patch);

  Concert applyTo(Concert entity) {
    return entity.patchWithConcert(patchInput: this);
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

  static ConcertPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  ConcertPatch withId(String? value) {
    _patch[Concert$.id] = value;
    return this;
  }

  ConcertPatch withArtist(String? value) {
    _patch[Concert$.artist] = value;
    return this;
  }
}

/// Field descriptors for [Concert] query construction
abstract final class ConcertFields {
  static String _$getid(Concert e) => e.id;
  static const id = Field<Concert, String>('id', _$getid);
  static String _$getartist(Concert e) => e.artist;
  static const artist = Field<Concert, String>('artist', _$getartist);
}

extension ConcertCompareE on Concert {
  Map<String, dynamic> compareToConcert(Concert other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }
    if (artist != other.artist) {
      diff['artist'] = () => other.artist;
    }
    return diff;
  }
}
