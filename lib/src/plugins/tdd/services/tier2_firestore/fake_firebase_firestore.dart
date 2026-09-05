/// `FakeFirebaseFirestore` — an in-memory, Firestore-shaped store for the
/// realize-mock differential gate (issue #1009, spec 913 parent #908).
///
/// "Firestore-shaped" means the REST wire shape: a document's fields hold
/// typed field values — `{'stringValue': ...}`, `{'integerValue': '42'}`,
/// `{'doubleValue': ...}`, `{'booleanValue': ...}`, `{'mapValue': ...}`,
/// `{'arrayValue': ...}`, `{'nullValue': null}` — the same shape the
/// skeleton plugin's Firebase data source reads and writes. A Tier-2
/// adapter exercised against this fake therefore observes the type
/// fidelity a real Firestore round-trip enforces: an `int` stays an
/// `integerValue`, a `double` stays a `doubleValue`, and a `null` field
/// is a `nullValue` — type divergence cannot hide in serialization.
///
/// The fake is deliberately minimal: collections, documents, typed
/// values, and deterministic ordering (documents list in document-id
/// order so differential comparisons are stable). No snapshots, no
/// queries beyond collection listing, no auth — the differential gate
/// only needs storage semantics.
library;

/// Encodes one Dart value into the Firestore REST field-value shape.
///
/// Throws [ArgumentError] for types Firestore's REST API cannot express
/// (fail-closed: a value that cannot round-trip must not silently pass).
Map<String, dynamic> encodeFirestoreValue(Object? value) {
  if (value == null) return <String, dynamic>{'nullValue': null};
  if (value is bool) return <String, dynamic>{'booleanValue': value};
  if (value is int) return <String, dynamic>{'integerValue': '$value'};
  if (value is double) return <String, dynamic>{'doubleValue': value};
  if (value is String) return <String, dynamic>{'stringValue': value};
  if (value is List) {
    return <String, dynamic>{
      'arrayValue': <String, dynamic>{
        'values': [for (final item in value) encodeFirestoreValue(item)],
      },
    };
  }
  if (value is Map<String, dynamic>) {
    return <String, dynamic>{
      'mapValue': <String, dynamic>{
        'fields': {
          for (final entry in value.entries)
            entry.key: encodeFirestoreValue(entry.value),
        },
      },
    };
  }
  throw ArgumentError(
    'FakeFirebaseFirestore cannot encode a ${value.runtimeType} — '
    'Firestore field values are null, bool, int, double, String, List or '
    'Map<String, dynamic>.',
  );
}

/// Decodes one Firestore REST field value back into its Dart value.
///
/// Mirrors [encodeFirestoreValue]: the round-trip preserves types exactly
/// (an `integerValue` decodes to `int`, a `doubleValue` to `double`).
Object? decodeFirestoreValue(Map<String, dynamic> wire) {
  if (wire.containsKey('nullValue')) return null;
  if (wire.containsKey('booleanValue')) return wire['booleanValue'] as bool;
  if (wire.containsKey('integerValue')) {
    return int.parse(wire['integerValue'] as String);
  }
  if (wire.containsKey('doubleValue')) {
    final raw = wire['doubleValue'];
    return raw is num ? raw.toDouble() : double.parse('$raw');
  }
  if (wire.containsKey('stringValue')) return wire['stringValue'] as String;
  if (wire.containsKey('arrayValue')) {
    final array = wire['arrayValue'];
    final values = array is Map ? array['values'] : null;
    if (values is! List) return const <Object?>[];
    return [
      for (final item in values)
        decodeFirestoreValue(Map<String, dynamic>.from(item as Map)),
    ];
  }
  if (wire.containsKey('mapValue')) {
    final map = wire['mapValue'];
    final fields = map is Map ? map['fields'] : null;
    if (fields is! Map) return const <String, dynamic>{};
    return <String, dynamic>{
      for (final entry in fields.entries)
        entry.key: decodeFirestoreValue(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
  }
  throw ArgumentError(
    'FakeFirebaseFirestore cannot decode field value $wire — no known '
    'Firestore value type key.',
  );
}

/// One document read: existence plus the decoded field map.
class FakeDocumentSnapshot {
  const FakeDocumentSnapshot._(this.reference, this._wire);

  /// The document reference this snapshot was read from.
  final FakeDocumentReference reference;

  final Map<String, dynamic>? _wire;

  /// The document's id (convenience: the reference's id).
  String get id => reference.id;

  /// Whether the document exists (false after a delete or a miss).
  bool get exists => _wire != null;

  /// The document's decoded fields, or null when [exists] is false.
  Map<String, dynamic>? get data {
    final wire = _wire;
    if (wire == null) return null;
    return <String, dynamic>{
      for (final entry in wire.entries)
        entry.key: decodeFirestoreValue(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
  }
}

/// A document reference: get / set / delete against one collection path +
/// document id (Firestore's `collection(name).doc(id)` shape).
class FakeDocumentReference {
  FakeDocumentReference._(this._collection, this.id);

  final FakeCollectionReference _collection;

  /// The document id.
  final String id;

  /// Reads the document (a snapshot with `exists == false` when absent).
  Future<FakeDocumentSnapshot> get() async =>
      FakeDocumentSnapshot._(this, _collection._read(id));

  /// Writes [data] as the document's fields (typed-value wrapped), fully
  /// replacing any previous content — Firestore `set` semantics.
  Future<void> set(Map<String, dynamic> data) async {
    final wire = <String, dynamic>{
      for (final entry in data.entries)
        entry.key: encodeFirestoreValue(entry.value),
    };
    _collection._write(id, wire);
  }

  /// Deletes the document. Deleting a missing document is a no-op (the
  /// same idempotence Firestore's REST delete observes).
  Future<void> delete() async => _collection._remove(id);
}

/// A collection read: the documents that exist, in document-id order.
class FakeQuerySnapshot {
  const FakeQuerySnapshot._(this.documents);

  /// The snapshots in document-id order (deterministic — the ordering a
  /// differential gate needs).
  final List<FakeDocumentSnapshot> documents;
}

/// A collection reference: `doc([id])` and `get()` (Firestore's
/// `collection(name)` shape).
class FakeCollectionReference {
  FakeCollectionReference._(this._store, this.name);

  final FakeFirebaseFirestore _store;

  /// The collection name.
  final String name;

  /// References one document. Without [id] a fresh auto id is allocated
  /// (monotonic, deterministic — differential cases pass explicit ids).
  FakeDocumentReference doc([String? id]) {
    final resolved = id ?? _store._autoId();
    return FakeDocumentReference._(this, resolved);
  }

  /// Lists every existing document in document-id order.
  Future<FakeQuerySnapshot> get() async {
    final collection = _store._collections[name] ?? const <String, dynamic>{};
    final ids = collection.keys.toList()..sort();
    return FakeQuerySnapshot._([
      for (final id in ids)
        FakeDocumentSnapshot._(
          FakeDocumentReference._(this, id),
          collection[id] as Map<String, dynamic>?,
        ),
    ]);
  }

  Map<String, dynamic>? _read(String id) => _store._collections[name]?[id];

  void _write(String id, Map<String, dynamic> wire) {
    _store._collections.putIfAbsent(name, () => <String, dynamic>{})[id] = wire;
  }

  void _remove(String id) => _store._collections[name]?.remove(id);
}

/// The fake `FirebaseFirestore` instance backing the Tier-2 mock
/// provider: `collection(name)` lazily creates collections; documents
/// hold typed field values; nothing leaves memory (issue #1009: "same
/// interface, backed by a fake FirebaseFirestore instance").
class FakeFirebaseFirestore {
  final Map<String, Map<String, dynamic>> _collections =
      <String, Map<String, dynamic>>{};

  int _autoIdCounter = 0;

  /// References (and lazily creates) the collection named [name].
  FakeCollectionReference collection(String name) =>
      FakeCollectionReference._(this, name);

  String _autoId() => 'auto-${(++_autoIdCounter).toString().padLeft(6, '0')}';
}
