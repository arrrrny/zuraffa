import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../models/generated_file.dart';
import '../../version.dart';
import '../project/project_root.dart';
import '../project/receipt_store.dart';
import 'capability.dart';

/// Spec 0996 (issue #996) — receipts on standalone capability
/// invocations.
///
/// `ReceiptStore` used to be written only by
/// `PluginManager._persistGenerationReceipt` on the `zfa make` path.
/// This wrapper closes the gap: every successful standalone invocation
/// (`zfa di create`, `zfa cache adapter <E>`, `zfa repository create`,
/// ...) auto-persists a `proof.v1` receipt into `.zfa/receipts/` keyed
/// `<plugin>-<capability>-<entity>-<timestamp>.json`, with the
/// machine-readable schema
/// `{plugin, capability, entity, hash, methodset, files, receipt_version: 1}`.
///
/// Receipt persistence is best-effort by design (the make-path
/// contract): the artifacts already exist, so a receipt failure degrades
/// to a warning instead of failing the run.
class CapabilityInvocationWrapper {
  CapabilityInvocationWrapper({
    required this.capability,
    required this.pluginId,
    String? projectRoot,
    ReceiptStore? store,
  }) : projectRoot = projectRoot ?? ProjectRoot.find(),
       _storeOverride = store;

  /// The wrapped standalone capability (`zfa <plugin> <capability>`).
  final ZuraffaCapability capability;

  /// The owning plugin id (`di`, `cache`, `usecase`, ...).
  final String pluginId;

  /// Project root the receipt store lives under.
  final String projectRoot;

  final ReceiptStore? _storeOverride;

  /// Machine schema version of the envelope (issue #996).
  static const int receiptVersion = 1;

  ReceiptStore get _store =>
      _storeOverride ?? ReceiptStore(projectRoot: projectRoot);

  /// Executes the capability and, when the run succeeds, auto-persists
  /// the proof receipt. The returned [ExecutionResult] is the wrapped
  /// capability's own verdict — a receipt failure never rewrites it.
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final result = await capability.execute(args);
    if (result.success) {
      await persistReceipt(args: args, result: result);
    }
    return result;
  }

  /// Persists the receipt for a finished (successful) run. Returns the
  /// receipt file, or null when the run wrote nothing receiptable (zero
  /// files, or only skipped/deleted entries) — issue #769: no artifact,
  /// no receipt. Public so non-capability execution paths that still
  /// represent a standalone invocation (e.g. `zfa shadcn <layout>`) can
  /// ship the same proof.
  Future<File?> persistReceipt({
    required Map<String, dynamic> args,
    required ExecutionResult result,
  }) async {
    try {
      final files = _receiptFiles(result);
      if (files.isEmpty) return null;

      final entity = _entityOf(args, result);
      final methodset = _methodsetOf(args);
      final runHash = _runHash(
        files: files,
        entity: entity,
        methodset: methodset,
      );

      final receipt = GenerationReceipt(
        command: '$pluginId ${capability.name}',
        target: entity,
        repro: 'zfa $pluginId ${capability.name} $entity',
        at: DateTime.now().toUtc(),
        generatorVersion: version,
        input: Map<String, dynamic>.from(args),
        files: files,
        plugin: pluginId,
        capability: capability.name,
        entity: entity,
        methodset: methodset,
        runHash: runHash,
        receiptVersion: receiptVersion,
      );
      return await _store.saveCapability(receipt);
    } catch (e) {
      // Best-effort: the artifacts exist; the run must not fail here.
      print('⚠️  Capability receipt not written: $e');
      return null;
    }
  }

  /// The file bindings this run commits: final on-disk bytes, digest,
  /// size and (small-text) snapshot — the same contract the make-path
  /// receipt pins. Skipped entries were not written by this run; deleted
  /// entries have no final bytes; both are excluded.
  List<GenerationReceiptFile> _receiptFiles(ExecutionResult result) {
    final generated =
        result.data?['generatedFiles'] as List<GeneratedFile>? ?? const [];
    final files = <GenerationReceiptFile>[];
    for (final generated in generated) {
      final action = generated.action;
      if (action == 'skipped' || action == 'deleted') continue;
      final file = _resolve(generated.path);
      if (file == null || !file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      final keepSnapshot =
          bytes.length <= ReceiptStore.maxSnapshotBytes &&
          _isLikelyBinary(bytes) == false;
      files.add(
        GenerationReceiptFile(
          path: _normalizeProjectPath(generated.path),
          action: action,
          sha256: crypto.sha256.convert(bytes).toString(),
          bytes: bytes.length,
          snapshot: keepSnapshot ? file.readAsStringSync() : null,
        ),
      );
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  File? _resolve(String path) {
    final candidate = p.isAbsolute(path) ? path : p.join(projectRoot, path);
    return File(candidate);
  }

  /// The entity the invocation operated on. Every standalone capability
  /// in the issue's matrix takes `name` as its required entity argument;
  /// the result payload is the fallback, the capability name the last
  /// resort (never empty — the receipt key needs an entity segment).
  String _entityOf(Map<String, dynamic> args, ExecutionResult result) {
    final fromArgs = args['name'];
    if (fromArgs is String && fromArgs.isNotEmpty) return fromArgs;
    final fromResult = result.data?['name'];
    if (fromResult is String && fromResult.isNotEmpty) return fromResult;
    return capability.name;
  }

  /// The methodset the invocation wired (issue #996): the `--methods`
  /// list when the capability declares one; otherwise the usecase-style
  /// method segments derivable from the generated file names
  /// (`product_get_usecase.dart` -> `get`); empty otherwise. Always a
  /// list (possibly empty) so machine readers never guess.
  List<String> _methodsetOf(Map<String, dynamic> args) {
    final declared = args['methods'];
    if (declared is List) {
      return declared.map((m) => m.toString()).toList(growable: false);
    }
    if (declared is String && declared.trim().isNotEmpty) {
      return declared
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  /// SHA-256 run digest: binds the entity, the methodset and every
  /// per-file `(path, action, sha256)` tuple, in file order (the
  /// receipt's files are sorted, so the digest is deterministic).
  String _runHash({
    required List<GenerationReceiptFile> files,
    required String entity,
    required List<String> methodset,
  }) {
    final canonical = StringBuffer()
      ..writeln('entity:$entity')
      ..writeln('methodset:${methodset.join(',')}');
    for (final f in files) {
      canonical.writeln('file:${f.path}:${f.action}:${f.sha256}');
    }
    return crypto.sha256.convert(utf8.encode(canonical.toString())).toString();
  }

  /// Project-relative POSIX path, the make-path receipt convention.
  String _normalizeProjectPath(String value) {
    if (value.isEmpty) return value;
    final relative = p.isAbsolute(value)
        ? p.relative(value, from: projectRoot)
        : value;
    return relative.replaceAll('\\', '/');
  }

  /// Snapshots are diffed as text; refuse to store non-UTF-8 bytes.
  bool _isLikelyBinary(List<int> bytes) {
    final probe = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    try {
      utf8.decode(probe);
      return false;
    } on FormatException {
      return true;
    }
  }
}

/// A minimal [ZuraffaCapability] view for call sites that execute a
/// standalone invocation OUTSIDE a capability object (e.g.
/// `zfa shadcn <layout> <Entity>`, which drives PluginManager directly)
/// but still owe the same receipt. Only [name] carries meaning; plan and
/// execute are inert.
class NamedCapability implements ZuraffaCapability {
  NamedCapability(this._name);

  final String _name;

  @override
  String get name => _name;

  @override
  String get description => 'Named capability view (receipt persistence)';

  @override
  JsonSchema get inputSchema => const {};

  @override
  JsonSchema get outputSchema => const {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'named',
    pluginId: 'named',
    capabilityName: _name,
    args: args,
    changes: const [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      throw UnsupportedError('NamedCapability is a receipt-persistence view');
}
