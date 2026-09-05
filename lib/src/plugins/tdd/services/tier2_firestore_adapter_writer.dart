/// The Tier-2 Firestore-shaped adapter writer (spec 1009, issue #1009):
/// renders the differential gate's Tier-2 subject.
///
/// `zfa tdd realize-mock <Entity> --against=firestore` runs the Tier-1
/// contract test against BOTH:
/// - the Tier-1 mock (the committed bytes, unchanged), and
/// - a **Tier-2 MockProvider** — a Firestore-shaped adapter implementing
///   the SAME `<Entity>DataSource` interface, backed by a fake in-memory
///   `FirebaseFirestore` ([FakeFirebaseFirestore] below, rendered into the
///   same file).
///
/// [Tier2FirestoreAdapterWriter] renders the adapter source; the zuraffa
/// root package is pure Dart (`.specify/memory/tdd-profile.md`), so the
/// "Firestore shape" is the adapter's API routing (collection → doc →
/// get/set/delete, collection get/snapshots), not a cloud_firestore
/// dependency — exactly like the spec-1001 sandbox's `dart test` choice.
///
/// [swapSubject] swaps the Tier-1 subject of the COMMITTED contract test
/// (its `LoginMockDataSource()` construction) for the Tier-2 provider —
/// the identical pins (typed tear-offs through the INTERFACE type) then
/// prove the adapter satisfies the same contract. Exactly one construction
/// site must exist, or the swap refuses (misfire-stop, never a guess).
library;

import 'package:path/path.dart' as p;

import '../../mock/certification/mock_contract_test_writer.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/entity_utils.dart';
import '../../../utils/string_utils.dart';

/// Renders the Tier-2 Firestore-shaped adapter + the subject-swapped
/// contract test for one entity's differential run.
class Tier2FirestoreAdapterWriter {
  const Tier2FirestoreAdapterWriter();

  /// The Tier-2 provider class name for [entityName].
  static String providerClassName(String entityName) =>
      '${entityName}Tier2MockProvider';

  /// The sandbox-relative path the adapter is written to (the project
  /// layout is mirrored inside the certification sandbox; the adapter is
  /// never committed to the target project).
  static String adapterRelPath(String entityName) => p.posix.join(
    'lib',
    'src',
    'data',
    'datasources',
    StringUtils.camelToSnake(entityName),
    '${StringUtils.camelToSnake(entityName)}_tier2_firestore_mock_provider.dart',
  );

  /// Renders the adapter source implementing `<Entity>DataSource`.
  ///
  /// [methods] is the interface contract (extracted from the datasource
  /// interface on disk under [outputDir]). [divergeMethod] (the `--diverge`
  /// chaos hook) forces the named method's body to fail on the Tier-2 side
  /// only — a wrong-typed value whose cast throws at runtime — proving the
  /// gate catches divergence.
  String render({
    required String entityName,
    required List<ContractMethod> methods,
    required String outputDir,
    String? divergeMethod,
  }) {
    final snake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final provider = providerClassName(entityName);
    final interface = MockContractTestWriter.interfaceName(entityName);
    final idField = _idFieldName(entityName, outputDir);
    final collectionPath = '${entityCamel}s';
    final diverge = divergeMethod;

    final buffer = StringBuffer()
      ..writeln('// GENERATED - DO NOT EDIT')
      ..writeln(
        '// Tier-2 Firestore-shaped mock provider (spec 1009, issue #1009).',
      )
      ..writeln('//')
      ..writeln(
        '// The differential gate subject: implements the same $interface',
      )
      ..writeln('// interface as the Tier-1 mock, backed by a fake in-memory')
      ..writeln('// FirebaseFirestore. Never committed to the target project —')
      ..writeln('// it exists to be compared against the Tier-1 mock by the')
      ..writeln('// realize-mock differential gate.')
      ..writeln("import 'dart:async';")
      ..writeln()
      ..writeln(
        "import 'package:zuraffa/mock.dart'"
        '${_hideList(entityName)};',
      )
      ..writeln("import '../../../domain/entities/$snake/$snake.dart';")
      ..writeln("import '${snake}_datasource.dart';")
      ..writeln("import '../../mock/${snake}_mock_data.dart';")
      ..writeln()
      ..writeln(_fakeFirestoreSource())
      ..writeln(
        '/// Tier-2 Firestore-shaped provider for $entityName (spec 1009).',
      )
      ..writeln(
        'class $provider with Loggable, FailureHandler '
        'implements $interface {',
      )
      ..writeln('  $provider({FakeFirebaseFirestore? firestore})')
      ..writeln('      : _firestore = firestore ?? FakeFirebaseFirestore() {')
      ..writeln('    _seed();')
      ..writeln('  }')
      ..writeln()
      ..writeln('  final FakeFirebaseFirestore _firestore;')
      ..writeln("  static const String _collectionPath = '$collectionPath';")
      ..writeln()
      ..writeln('  /// The records the fake store serves, keyed by document')
      ..writeln('  /// id. Seeded from the same mock data the Tier-1 mock')
      ..writeln('  /// serves, so a conforming Tier-2 adapter agrees with the')
      ..writeln('  /// Tier-1 results on every method.')
      ..writeln('  final Map<String, $entityName> _byDocId = _seedRecords();')
      ..writeln(
        '  late final List<String> _docIds = '
        '_byDocId.keys.toList(growable: true);',
      )
      ..writeln()
      ..writeln('  static Map<String, $entityName> _seedRecords() {');
    if (idField != null) {
      buffer.writeln(
        '    return <String, $entityName>{ '
        'for (final record in ${entityName}MockData.$collectionPath) '
        'record.$idField: record };',
      );
    } else {
      buffer
        ..writeln('    final seeded = ${entityName}MockData.$collectionPath;')
        ..writeln('    return <String, $entityName>{')
        ..writeln(
          "      for (var i = 0; i < seeded.length; i++) "
          "'doc-\$i': seeded[i],",
        )
        ..writeln('    };');
    }
    buffer
      ..writeln('  }')
      ..writeln()
      ..writeln('  void _seed() {')
      ..writeln('    for (final id in _docIds) {')
      ..writeln('      _firestore.collection(_collectionPath).doc(id).set(')
      ..writeln(
        "        <String, Object?>{${idField != null ? "'$idField': id" : "'doc': id"}},",
      )
      ..writeln('      );')
      ..writeln('    }')
      ..writeln('  }')
      ..writeln();

    // Helpers are emitted only when the interface's method set uses them
    // (no unused-element noise in the sandbox analyze).
    final names = methods.map((m) => m.name).toSet();
    final needsFirst =
        names.contains('get') ||
        names.contains('update') ||
        names.contains('toggle');
    final needsAll = names.contains('list') || names.contains('getList');
    final needsWatchFirst = names.contains('watch');
    final needsWatchAll = names.contains('watchList');
    final needsRecordFor =
        needsFirst || needsAll || needsWatchFirst || needsWatchAll;

    if (needsRecordFor) {
      buffer
        ..writeln('  $entityName _recordFor(FakeDocumentSnapshot doc) =>')
        ..writeln('      _byDocId[doc.id]!;')
        ..writeln();
    }
    if (needsFirst) {
      buffer
        ..writeln('  Future<$entityName> _firstRecord() async => _recordFor(')
        ..writeln('        await _firestore')
        ..writeln('            .collection(_collectionPath)')
        ..writeln('            .doc(_docIds.first)')
        ..writeln('            .get(),')
        ..writeln('      );')
        ..writeln();
    }
    if (needsAll) {
      buffer
        ..writeln('  Future<List<$entityName>> _allRecords() async => [')
        ..writeln(
          '        for (final doc in await _firestore'
          '.collection(_collectionPath).get())',
        )
        ..writeln('          _recordFor(doc),')
        ..writeln('      ];')
        ..writeln();
    }
    if (needsWatchFirst) {
      buffer
        ..writeln('  Stream<$entityName> _watchFirst() async* {')
        ..writeln('    final docs =')
        ..writeln('        await _firestore.collection(_collectionPath).get();')
        ..writeln('    if (docs.isNotEmpty) yield _recordFor(docs.first);')
        ..writeln('  }')
        ..writeln();
    }
    if (needsWatchAll) {
      buffer
        ..writeln('  Stream<List<$entityName>> _watchAll() =>')
        ..writeln(
          '      _firestore.collection(_collectionPath).snapshots().map(',
        )
        ..writeln(
          '        (docs) => [for (final doc in docs) _recordFor(doc)],',
        )
        ..writeln('      );')
        ..writeln();
    }
    if (diverge != null) {
      buffer
        ..writeln(
          '  /// The wrong-typed value the `--diverge $diverge` chaos hook',
        )
        ..writeln(
          '  /// returns: the cast in the divergent method throws at runtime,',
        )
        ..writeln(
          '  /// so the contract test for $diverge fails on the Tier-2 side',
        )
        ..writeln('  /// only — the differential gate must name it.')
        ..writeln(
          "  final Object _divergentValue = "
          "'tier-2 divergent value (wrong type)';",
        )
        ..writeln();
    }
    for (final method in methods) {
      buffer
        ..writeln(
          _methodSource(
            entityName: entityName,
            method: method,
            idField: idField,
            diverge: diverge == method.name,
          ),
        )
        ..writeln();
    }
    buffer
      ..writeln('}')
      ..writeln();
    return buffer.toString();
  }

  /// The per-method override. Canonical CRUD bodies route through the
  /// fake Firestore; unknown shapes degrade to type-correct defaults (the
  /// contract's behavioral invocations only cover synthesizable params,
  /// same rule as the spec-1001 contract writer).
  String _methodSource({
    required String entityName,
    required ContractMethod method,
    required String? idField,
    required bool diverge,
  }) {
    final ret = method.returnType;
    final inner = _unwrapAsync(ret);
    final isStream = ret.startsWith('Stream<');

    // Divergence injection (the --diverge chaos hook): the named method
    // fails on the Tier-2 side only.
    if (diverge) {
      if (ret == 'Future<void>' || ret == 'void') {
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) async {\n'
            "    throw StateError('tier-2 divergence injected into "
            '${method.name}\');\n'
            '  }';
      }
      if (isStream) {
        // The contract awaits `.first` — an error stream fails the test
        // immediately (never a hang).
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) =>\n'
            "      Stream<$inner>.error(\n"
            "        StateError('tier-2 divergence injected into "
            '${method.name}\'),\n'
            '      );';
      }
      return '  @override\n'
          '  $ret ${method.name}(${_paramDecl(method)}) async =>\n'
          '      _divergentValue as $inner;';
    }

    switch (method.name) {
      case 'get':
      case 'update':
      case 'toggle':
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) async =>\n'
            '      _firstRecord();';
      case 'create':
        final docIdExpr = idField == null
            ? "'doc-\${_docIds.length}'"
            : 'record.$idField';
        final idLiteral = idField == null
            ? "'doc': docId"
            : "'$idField': record.$idField";
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) async {\n'
            '    final record = ${_paramName(method)};\n'
            '    final docId = $docIdExpr;\n'
            '    _byDocId[docId] = record;\n'
            '    _docIds.add(docId);\n'
            '    await _firestore.collection(_collectionPath)'
            '.doc(docId).set(\n'
            '      <String, Object?>{$idLiteral},\n'
            '    );\n'
            '    return record;\n'
            '  }';
      case 'delete':
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) async {\n'
            '    if (_docIds.isEmpty) return;\n'
            '    final id = _docIds.first;\n'
            '    await _firestore.collection(_collectionPath).doc(id)'
            '.delete();\n'
            '    _docIds.remove(id);\n'
            '    _byDocId.remove(id);\n'
            '  }';
      case 'list':
      case 'getList':
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) async =>\n'
            '      _allRecords();';
      case 'watch':
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) =>\n'
            '      _watchFirst();';
      case 'watchList':
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) =>\n'
            '      _watchAll();';
      case 'initialize':
      case 'dispose':
        return '  @override\n'
            '  $ret ${method.name}(${_paramDecl(method)}) async {}';
      case 'isInitialized':
        return '  @override\n'
            '  $ret get ${method.name} => const Stream<bool>.value(true);';
    }

    // Unknown shape: type-correct default, or an honest throwing stub when
    // no typed default exists (the pin still proves the signature).
    if (ret == 'Future<void>' || ret == 'void') {
      return '  @override\n'
          '  $ret ${method.name}(${_paramDecl(method)}) async {}';
    }
    final defaultValue = _defaultOfType(inner, entityName);
    if (defaultValue != null) {
      return isStream
          ? '  @override\n'
                '  $ret ${method.name}(${_paramDecl(method)}) =>\n'
                '      Stream.value($defaultValue);'
          : '  @override\n'
                '  $ret ${method.name}(${_paramDecl(method)}) async =>\n'
                '      $defaultValue;';
    }
    return '  @override\n'
        '  $ret ${method.name}(${_paramDecl(method)}) async =>\n'
        "      throw UnimplementedError('tier-2: ${method.name}');";
  }

  /// The fake Firestore source (rendered verbatim into the adapter file).
  String _fakeFirestoreSource() => '''
/// Minimal in-memory Firestore-shaped fake (spec 1009): the API surface
/// the Tier-2 adapter routes through — collection().doc().get()/set()/
/// delete(), collection().get() and collection().snapshots() with watcher
/// notification on writes. NOT a cloud_firestore substitute; it exists so
/// the differential gate exercises a Firestore-shaped path in a pure-Dart
/// sandbox with no SDK or network dependency.
class FakeFirebaseFirestore {
  FakeFirebaseFirestore();

  final Map<String, Map<String, Map<String, Object?>>> _collections = {};
  final Map<String, List<StreamController<List<FakeDocumentSnapshot>>>>
      _watchers = {};

  FakeCollectionReference collection(String path) =>
      FakeCollectionReference._(this, path);

  List<FakeDocumentSnapshot> _docsOf(String path) => [
        for (final entry in (_collections[path] ?? const {}).entries)
          FakeDocumentSnapshot._(entry.key, entry.value),
      ];

  void _notify(String path) {
    final docs = _docsOf(path);
    for (final controller in (_watchers[path] ?? const []).toList()) {
      if (!controller.isClosed) controller.add(docs);
    }
  }
}

class FakeCollectionReference {
  FakeCollectionReference._(this._firestore, this._path);

  final FakeFirebaseFirestore _firestore;
  final String _path;

  FakeDocumentReference doc(String id) =>
      FakeDocumentReference._(_firestore, _path, id);

  Future<List<FakeDocumentSnapshot>> get() async =>
      _firestore._docsOf(_path);

  Stream<List<FakeDocumentSnapshot>> snapshots() {
    final controller =
        StreamController<List<FakeDocumentSnapshot>>.broadcast();
    _firestore._watchers.putIfAbsent(_path, () => []).add(controller);
    controller.add(_firestore._docsOf(_path));
    return controller.stream;
  }
}

class FakeDocumentReference {
  FakeDocumentReference._(this._firestore, this._path, this._id);

  final FakeFirebaseFirestore _firestore;
  final String _path;
  final String _id;

  Future<FakeDocumentSnapshot> get() async => FakeDocumentSnapshot._(
        _id,
        _firestore._collections[_path]?[_id],
      );

  Future<void> set(Map<String, Object?> data) async {
    _firestore._collections.putIfAbsent(_path, () => {})[_id] = data;
    _firestore._notify(_path);
  }

  Future<void> delete() async {
    _firestore._collections[_path]?.remove(_id);
    _firestore._notify(_path);
  }
}

class FakeDocumentSnapshot {
  FakeDocumentSnapshot._(this.id, this._data);

  final String id;
  final Map<String, Object?>? _data;

  bool get exists => _data != null;
  Map<String, Object?>? get data => _data;
}
''';

  /// Swap the Tier-1 subject of the COMMITTED contract test for the
  /// Tier-2 provider: the mock-datasource import is replaced by the
  /// adapter import, and the `<Entity>MockDataSource()` construction by
  /// `<Entity>Tier2MockProvider()`. Every pin stays byte-identical.
  ///
  /// Throws [StateError] when the test does not carry exactly one Tier-1
  /// construction site (misfire-stop, never a guess).
  static String swapSubject({
    required String entityName,
    required String contractTestSource,
  }) {
    final snake = StringUtils.camelToSnake(entityName);
    final mockClass = MockContractTestWriter.mockClassName(entityName);
    final provider = providerClassName(entityName);

    final constructions = RegExp(
      '$mockClass\\(\\)',
    ).allMatches(contractTestSource).length;
    if (constructions != 1) {
      throw StateError(
        'the committed contract test for $entityName carries '
        '$constructions `$mockClass()` construction site(s) — expected '
        'exactly 1. The subject swap refuses to guess; regenerate the '
        'contract test with `zfa mock create $entityName --certify`.',
      );
    }

    final mockImport =
        "import '../../../lib/src/data/datasources/$snake/"
        '${snake}_mock_datasource.dart\';';
    final adapterImport =
        "import '../../../lib/src/data/datasources/$snake/"
        '${snake}_tier2_firestore_mock_provider.dart\';';
    var swapped = contractTestSource;
    if (swapped.contains(mockImport)) {
      swapped = swapped.replaceFirst(mockImport, adapterImport);
    } else {
      swapped = swapped.replaceFirst('import', '$adapterImport\nimport');
    }
    swapped = swapped.replaceFirst('$mockClass()', '$provider()');
    return swapped;
  }

  String _paramDecl(ContractMethod method) =>
      '${method.paramsType} ${_paramName(method)}';

  /// `create(Login login)` keeps a value-ish parameter name (positional
  /// override conformance does not pin parameter names).
  String _paramName(ContractMethod method) =>
      method.name == 'create' ? 'entity' : 'params';

  static String? _idFieldName(String entityName, String outputDir) {
    final fields = EntityAnalyzer.analyzeEntity(entityName, outputDir);
    if (fields.containsKey('id')) return 'id';
    if (fields.isEmpty) return null;
    final first = fields.entries.first;
    const scalars = {'String', 'int', 'String?', 'int?'};
    return scalars.contains(first.value) ? first.key : null;
  }

  /// The barrel hide list (issue #942): when the entity's own symbols
  /// collide with zuraffa core exports, the mock barrel import hides
  /// exactly those names so the entity's definitions win resolution —
  /// same convention the generated mock datasource uses.
  static String _hideList(String entityName) {
    final hide = EntityUtils.barrelHideNames(entityName);
    if (hide.isEmpty) return '';
    return ' hide ${hide.join(', ')}';
  }

  static String? _defaultOfType(String type, String entityName) {
    switch (type) {
      case 'bool':
        return 'true';
      case 'int':
      case 'num':
        return '0';
      case 'double':
        return '0.0';
      case 'String':
        return "''";
    }
    if (type == 'List<$entityName>') return 'const <$entityName>[]';
    return null;
  }

  static String _unwrapAsync(String ret) {
    if (ret.startsWith('Future<') && ret.endsWith('>')) {
      return ret.substring(7, ret.length - 1);
    }
    if (ret.startsWith('Stream<') && ret.endsWith('>')) {
      return ret.substring(7, ret.length - 1);
    }
    return ret;
  }
}
