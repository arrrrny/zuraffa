import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/file_parser.dart';
import '../../../core/project/receipt_store.dart';
import '../../../utils/string_utils.dart' show StringUtils;

/// Spec 0973 (issue #973) — repository contract manifest.
///
/// A [RepositoryContractManifest] is the per-entity, machine-readable
/// contract a fresh repository generation ships with its artifacts:
/// `.zfa/receipts/repository-<entity>.json` carries the interface method
/// set with params/returns signatures, bound by digests to the exact
/// interface/impl files the run wrote. The method table is itself hashed
/// ([RepositoryContractManifest.hashOfMethods]) so a hand-edited manifest
/// is detectable, not just hand-edited artifacts.
///
/// Consumers:
///   * `SourceInterfaceGuard` (issue #921) consumes the manifest's method
///     set when the manifest is **fresh** — the interface file on disk
///     still matches the digest recorded at generation time — and falls
///     back to parsing the source otherwise. One source of truth for "what
///     does the repository interface actually declare".
///   * `zfa proof check` re-derives the digests and goes red on drift or
///     manifest tampering (findings `manifest_drift` / `manifest_corrupt`).
///
/// Manifests are written only after the generation-time conformance gate
/// (spec 0973 T001) passed, so a manifest asserts "this pair conformed
/// when it was written".
const String repositoryContractSchema = 'repository-contract.v1';

/// One interface method's contract: name + returns + parameter signatures.
class RepositoryContractMethod {
  final String name;
  final String returns;

  /// Parameter signatures in declaration order, e.g. `QueryParams<Product>
  /// params`. Getters have none.
  final List<String> params;

  const RepositoryContractMethod({
    required this.name,
    required this.returns,
    required this.params,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'returns': returns,
    'params': params,
  };

  factory RepositoryContractMethod.fromJson(Map<String, dynamic> json) =>
      RepositoryContractMethod(
        name: json['name'] as String,
        returns: json['returns'] as String? ?? 'void',
        params: (json['params'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );

  /// The canonical string hashed into a manifest's `methods_sha256`.
  /// Deterministic: fixed key order, declaration order.
  String canonicalJson() => jsonEncode(toJson());
}

/// Digest-bound reference to one side of the pair.
class RepositoryContractFile {
  final String className;

  /// Project-relative POSIX path.
  final String path;

  /// SHA-256 (hex) of the file bytes at generation time.
  final String sha256;

  const RepositoryContractFile({
    required this.className,
    required this.path,
    required this.sha256,
  });

  Map<String, dynamic> toJson() => {
    'class': className,
    'path': path,
    'sha256': sha256,
  };

  factory RepositoryContractFile.fromJson(Map<String, dynamic> json) =>
      RepositoryContractFile(
        className: json['class'] as String? ?? '',
        path: json['path'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
      );
}

class RepositoryContractManifest {
  final String schema;
  final String entity;
  final RepositoryContractFile interface;
  final RepositoryContractFile implementation;
  final List<RepositoryContractMethod> methods;

  /// SHA-256 over the canonical JSON of [methods] (declaration order) —
  /// detects hand-edited method tables without the source files.
  final String methodsSha256;
  final String generatorVersion;
  final DateTime at;

  const RepositoryContractManifest({
    this.schema = repositoryContractSchema,
    required this.entity,
    required this.interface,
    required this.implementation,
    required this.methods,
    required this.methodsSha256,
    required this.generatorVersion,
    required this.at,
  });

  List<String> get methodNames =>
      methods.map((m) => m.name).toList(growable: false);

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'entity': entity,
    'interface': interface.toJson(),
    'implementation': implementation.toJson(),
    'methods': methods.map((m) => m.toJson()).toList(),
    'methods_sha256': methodsSha256,
    'generator_version': generatorVersion,
    'at': at.toUtc().toIso8601String(),
  };

  factory RepositoryContractManifest.fromJson(Map<String, dynamic> json) =>
      RepositoryContractManifest(
        schema: json['schema'] as String? ?? repositoryContractSchema,
        entity: json['entity'] as String? ?? '',
        interface: RepositoryContractFile.fromJson(
          Map<String, dynamic>.from(json['interface'] as Map? ?? const {}),
        ),
        implementation: RepositoryContractFile.fromJson(
          Map<String, dynamic>.from(
            json['implementation'] as Map? ?? const {},
          ),
        ),
        methods: (json['methods'] as List? ?? const [])
            .map(
              (m) => RepositoryContractMethod.fromJson(
                Map<String, dynamic>.from(m as Map),
              ),
            )
            .toList(growable: false),
        methodsSha256: json['methods_sha256'] as String? ?? '',
        generatorVersion: json['generator_version'] as String? ?? '',
        at: json['at'] is String
            ? DateTime.tryParse(json['at'] as String) ??
                  DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Recomputes the method-table hash from [methods]. Stable across runs
  /// with identical method sets (no timestamps, no map-order dependence).
  static String hashOfMethods(List<RepositoryContractMethod> methods) =>
      crypto.sha256
          .convert(utf8.encode(methods.map((m) => m.canonicalJson()).join()))
          .toString();
}

/// Extracts the contract method table from an emitted interface source.
class RepositoryContractExtractor {
  const RepositoryContractExtractor();

  List<RepositoryContractMethod> extract({
    required String interfaceSource,
    required String className,
  }) {
    final parseResult = const FileParser().parseSource(
      interfaceSource,
      path: '$className.dart',
    );
    final unit = parseResult.unit;
    if (unit == null) return const [];
    final classNode = const AstHelper().findClass(unit, className);
    if (classNode == null) return const [];

    final methods = <RepositoryContractMethod>[];
    for (final method in const AstHelper().findMethods(classNode)) {
      final params = <String>[];
      final parameterList = method.parameters;
      if (parameterList != null) {
        for (final parameter in parameterList.parameters) {
          final signature = _parameterSignature(parameter);
          if (signature.isNotEmpty) params.add(signature);
        }
      }
      methods.add(
        RepositoryContractMethod(
          name: method.name.lexeme,
          returns: method.returnType?.toSource() ?? 'void',
          params: params,
        ),
      );
    }
    return methods;
  }

  /// `Type name` for normal parameters; falls back to the parameter's own
  /// source when the shape is exotic (function-typed, etc.).
  String _parameterSignature(dynamic parameter) {
    try {
      dynamic inner = parameter;
      try {
        inner = parameter.parameter;
      } catch (_) {
        // Not a DefaultFormalParameter wrapper.
      }
      final type = inner.type?.toSource() ?? 'dynamic';
      final name = inner.name?.lexeme ?? '';
      if (name.isEmpty) return type;
      return '$type $name';
    } catch (_) {
      return parameter.toSource();
    }
  }
}

/// Reads and writes repository contract manifests under the existing
/// receipts directory (`<projectRoot>/.zfa/receipts/`, via [ReceiptStore]).
class RepositoryContractManifestStore {
  final String projectRoot;

  const RepositoryContractManifestStore({required this.projectRoot});

  /// Stable per-entity file name (`repository-<entity>.json`).
  static String fileNameFor(String entityName) =>
      'repository-${StringUtils.camelToSnake(entityName)}.json';

  Directory get directory => ReceiptStore(projectRoot: projectRoot).directory;

  File fileFor(String entityName) =>
      File(p.join(directory.path, fileNameFor(entityName)));

  /// Persists [manifest], overwriting the entity's previous contract.
  Future<File> save(RepositoryContractManifest manifest) async {
    await directory.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    return fileFor(manifest.entity).writeAsString(
      encoder.convert(manifest.toJson()),
    );
  }

  /// Loads the entity's manifest, or null when absent / corrupt / foreign
  /// schema. Corruption never throws — the guard fails open to source
  /// parsing and `zfa proof check` reports the tampering separately.
  Future<RepositoryContractManifest?> loadForEntity(String entityName) async {
    final file = fileFor(entityName);
    if (!file.existsSync()) return null;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final manifest = RepositoryContractManifest.fromJson(json);
      if (manifest.schema != repositoryContractSchema) return null;
      return manifest;
    } catch (_) {
      return null;
    }
  }

  /// Every parseable contract manifest in the receipts directory (used by
  /// `zfa proof check`).
  Future<List<RepositoryContractManifest>> loadAll() async {
    if (!directory.existsSync()) return const [];
    final manifests = <RepositoryContractManifest>[];
    for (final file in directory
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('repository-'))
        .where((f) => f.path.endsWith('.json'))) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (json['schema'] != repositoryContractSchema) continue;
        manifests.add(RepositoryContractManifest.fromJson(json));
      } catch (_) {
        // Skip corrupted manifests — `verify` surfaces tampering through
        // file-level checks; unparseable documents fail open here.
      }
    }
    return manifests;
  }

  /// Verifies [manifest] against the current tree. Returns a finding kind
  /// (`manifest_corrupt`, `manifest_drift`) with a detail line, or null
  /// when the manifest is fresh.
  ({String kind, String detail})? verify(
    RepositoryContractManifest manifest,
  ) {
    if (RepositoryContractManifest.hashOfMethods(manifest.methods) !=
        manifest.methodsSha256) {
      return (
        kind: 'manifest_corrupt',
        detail:
            'contract manifest method table for ${manifest.entity} was '
            'hand-edited (methods_sha256 mismatch); regenerate with: '
            'zfa repository create --name ${manifest.entity}',
      );
    }

    for (final side in [manifest.interface, manifest.implementation]) {
      if (side.path.isEmpty) continue;
      final file = File(p.join(projectRoot, side.path));
      if (!file.existsSync()) {
        return (
          kind: 'manifest_drift',
          detail:
              '${side.className} (${side.path}) recorded in the '
              '${manifest.entity} contract manifest is missing; regenerate '
              'with: zfa repository create --name ${manifest.entity}',
        );
      }
      final actual = crypto.sha256.convert(file.readAsBytesSync()).toString();
      if (actual != side.sha256) {
        return (
          kind: 'manifest_drift',
          detail:
              '${side.className} drifted from the ${manifest.entity} '
              'contract manifest (recorded ${_short(side.sha256)}, disk '
              '${_short(actual)}); regenerate with: zfa repository create '
              '--name ${manifest.entity}',
        );
      }
    }
    return null;
  }

  /// Freshness for guard consumption: the method table is intact and the
  /// interface file still matches the recorded digest.
  bool isFresh(RepositoryContractManifest manifest) {
    if (RepositoryContractManifest.hashOfMethods(manifest.methods) !=
        manifest.methodsSha256) {
      return false;
    }
    if (manifest.interface.path.isEmpty) return false;
    final file = File(p.join(projectRoot, manifest.interface.path));
    if (!file.existsSync()) return false;
    return crypto.sha256.convert(file.readAsBytesSync()).toString() ==
        manifest.interface.sha256;
  }

  static String _short(String digest) =>
      digest.length <= 12 ? digest : digest.substring(0, 12);
}

/// Resolves the project root a repository generation's receipts belong to.
///
/// The make flow passes [explicitProjectRoot] (PluginContext.core
/// .projectRoot — the same root [ReceiptStore] uses). Direct plugin calls
/// (and tests) derive it from the output directory: `<root>/lib/src` →
/// `<root>`; anything else owns its own receipts tree.
String repositoryProjectRootFor(
  String outputDir, {
  String? explicitProjectRoot,
}) {
  if (explicitProjectRoot != null && explicitProjectRoot.isNotEmpty) {
    return explicitProjectRoot;
  }
  final absolute = p.normalize(p.absolute(outputDir));
  final parts = p.split(absolute);
  if (parts.length >= 2 &&
      parts[parts.length - 2] == 'lib' &&
      parts.last == 'src') {
    final rootParts = parts.sublist(0, parts.length - 2);
    var root = rootParts.join(p.separator);
    if (!p.isAbsolute(root)) root = '${p.separator}$root';
    return root;
  }
  return absolute;
}

/// Digest of the exact bytes [source] will land on disk with.
String repositoryContractDigest(String source) =>
    crypto.sha256.convert(utf8.encode(source)).toString();
