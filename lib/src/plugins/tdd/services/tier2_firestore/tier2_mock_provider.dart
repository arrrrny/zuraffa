/// `Tier2MockProvider` — the Firestore-shaped adapter the realize-mock
/// differential gate swaps in (issue #1009).
///
/// "Same interface" means the same invocation surface the Tier-1 mock
/// exposes through the driver contract: one method name plus its argument
/// map in, one JSON result map out. The difference is the backing store —
/// every call is routed through a [FakeFirebaseFirestore]: reads go
/// through document snapshots, writes through the typed-value wrap, so
/// the adapter observes Firestore's storage semantics (typed fields,
/// per-collection isolation, document-id ordering) instead of the Tier-1
/// in-memory map. The method surface itself — the CRUD methods the mock
/// generators emit (`get<Entity>ById`, `getAll<Entity>s`,
/// `save<Entity>`, `delete<Entity>`, plus their generic spellings) — is
/// preserved, which is what lets the SAME contract cases run against
/// both tiers.
///
/// Fail-closed: a method outside the surface throws
/// [Tier2MockMethodError] naming the method — an adapter that cannot run
/// a case must never silently guess one.
library;

import 'fake_firebase_firestore.dart';

/// The unsupported-method error: the method the adapter could not route,
/// named (the differential gate reports it, never swallows it).
class Tier2MockMethodError implements Exception {
  Tier2MockMethodError(this.method, this.reason);

  /// The method name that was rejected.
  final String method;

  /// Why it was rejected (one line).
  final String reason;

  @override
  String toString() => 'Tier2MockMethodError: method "$method" — $reason';
}

/// Result conventions the provider returns (documented so the Tier-1
/// oracle side records comparable JSON):
/// - read-by-id hit  → the document's field map
/// - read-by-id miss → `{}`
/// - list            → `{'items': [<field maps in document-id order>]}`
/// - save            → `{'id': <document id>}`
/// - delete          → `{'id': <document id>}`
/// - exists          → `{'exists': <bool>}`
class Tier2MockProvider {
  /// Builds the adapter for [entity]'s collection, over [firestore] (a
  /// fresh [FakeFirebaseFirestore] when omitted).
  Tier2MockProvider({required String entity, FakeFirebaseFirestore? firestore})
    : entity = entity,
      firestore = firestore ?? FakeFirebaseFirestore(),
      collectionPath = collectionOf(entity);

  /// The entity this adapter serves (collection owner).
  final String entity;

  /// The fake Firestore instance backing every call.
  final FakeFirebaseFirestore firestore;

  /// The collection documents live in (the entity's snake-case name).
  final String collectionPath;

  /// The standard collection name for an entity: the snake-case of its
  /// name (`Login` -> `login`, `UserProfile` -> `user_profile`) — the
  /// same convention the skeleton's Firestore data source builder uses
  /// for `_collectionPath`.
  static String collectionOf(String entity) {
    final snake = entity
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
    return snake.toLowerCase();
  }

  /// Seeds the collection with [records] (maps carrying a String `id`
  /// field — the primary-key convention the generators emit) and clears
  /// any prior content first, so per-case seeding is deterministic.
  Future<void> seed(List<Map<String, dynamic>> records) async {
    final collection = firestore.collection(collectionPath);
    final existing = await collection.get();
    for (final doc in existing.documents) {
      await doc.reference.delete();
    }
    for (final record in records) {
      final id = record['id'];
      if (id is! String) {
        throw ArgumentError(
          'seed records must carry a String "id" field — got '
          '${id == null ? 'null' : id.runtimeType} in ${record.keys}',
        );
      }
      await collection.doc(id).set(Map<String, dynamic>.from(record));
    }
  }

  /// Invokes one interface method with [args] and returns the result
  /// JSON (the conventions documented on the class).
  ///
  /// The method is normalized (lower-cased, the entity name stripped)
  /// before routing, so entity-qualified names (`getLoginById`) and
  /// generic ones (`getById`) hit the same route.
  Future<Map<String, dynamic>> invoke(
    String method,
    Map<String, dynamic> args,
  ) async {
    final normalized = _normalize(method);
    final collection = firestore.collection(collectionPath);
    if (normalized.contains('byid')) {
      final id = args['id'];
      if (id is! String) {
        throw Tier2MockMethodError(
          method,
          'read-by-id needs a String "id" argument — got '
          '${id == null ? 'null' : id.runtimeType}',
        );
      }
      final snapshot = await collection.doc(id).get();
      final data = snapshot.data;
      return data == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(data);
    }
    const listVerbs = ['getall', 'listall', 'findall', 'list', 'all', 'allx'];
    if (listVerbs.any(normalized.startsWith) || normalized == 'list') {
      final snapshot = await collection.get();
      return <String, dynamic>{
        'items': [
          for (final doc in snapshot.documents)
            Map<String, dynamic>.from(doc.data ?? const <String, dynamic>{}),
        ],
      };
    }
    if (normalized.startsWith('exists') || normalized.startsWith('has')) {
      final id = args['id'];
      if (id is! String) {
        throw Tier2MockMethodError(
          method,
          'exists needs a String "id" argument — got '
          '${id == null ? 'null' : id.runtimeType}',
        );
      }
      final snapshot = await collection.doc(id).get();
      return <String, dynamic>{'exists': snapshot.exists};
    }
    const writeVerbs = ['save', 'create', 'update', 'put', 'upsert'];
    if (writeVerbs.any(normalized.startsWith)) {
      final record = _documentOf(args);
      final id = record['id'];
      if (id is! String) {
        throw Tier2MockMethodError(
          method,
          'save needs a String "id" on the document — got '
          '${id == null ? 'null' : id.runtimeType}',
        );
      }
      await collection.doc(id).set(record);
      return <String, dynamic>{'id': id};
    }
    const deleteVerbs = ['delete', 'remove'];
    if (deleteVerbs.any(normalized.startsWith)) {
      final id = args['id'];
      if (id is! String) {
        throw Tier2MockMethodError(
          method,
          'delete needs a String "id" argument — got '
          '${id == null ? 'null' : id.runtimeType}',
        );
      }
      await collection.doc(id).delete();
      return <String, dynamic>{'id': id};
    }
    throw Tier2MockMethodError(
      method,
      'outside the mock datasource surface (getById / getAll / save / '
      'delete / exists and their entity-qualified spellings)',
    );
  }

  /// The document to write: the explicit `record` map when the arguments
  /// carry one, otherwise the arguments themselves minus the routing
  /// noise.
  Map<String, dynamic> _documentOf(Map<String, dynamic> args) {
    final record = args['record'];
    if (record is Map) {
      return Map<String, dynamic>.from(record);
    }
    return <String, dynamic>{
      for (final entry in args.entries)
        if (entry.key != 'op' && entry.key != 'seed') entry.key: entry.value,
    };
  }

  /// `getLoginById` -> `getbyid` (entity stripped, lower-cased; the
  /// plural `s` of `getAll<Entity>s` is tolerated by the route checks).
  String _normalize(String method) {
    var normalized = method.toLowerCase();
    final entityLower = entity.toLowerCase();
    if (normalized.contains(entityLower)) {
      normalized = normalized.replaceAll(entityLower, '');
    }
    return normalized;
  }
}
