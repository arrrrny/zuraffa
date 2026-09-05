import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/plugin_system/capability_invocation_wrapper.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/models/generated_file.dart';

/// Spec 0996 (issue #996) — receipts on standalone capability invocations.
///
/// A [CapabilityInvocationWrapper] executes a capability and, when the run
/// succeeds and wrote files, auto-persists a `proof.v1` receipt into
/// `.zfa/receipts/` keyed `<plugin>-<capability>-<entity>-<timestamp>.json`
/// with the machine-readable schema
/// `{plugin, capability, entity, hash, methodset, files, receipt_version: 1}`.
void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_cap_receipt_');
  });

  tearDown(() {
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  /// A capability stub that REALLY writes the artifact to disk (receipts
  /// bind the final on-disk bytes) and reports it via `generatedFiles`.
  WritingCapability writingCapability({
    String name = 'Product',
    String action = 'created',
    bool success = true,
    String capabilityName = 'create',
  }) => WritingCapability(
    projectRoot: workspace.path,
    entityName: name,
    action: action,
    success: success,
    capabilityName: capabilityName,
  );

  Directory receiptsDir() =>
      Directory(p.join(workspace.path, '.zfa', 'receipts'));

  group('T001 — wrapper auto-persists a receipt after success', () {
    test('a file appears in .zfa/receipts/ keyed '
        '<plugin>-<capability>-<entity>-<timestamp>.json', () async {
      final capability = writingCapability();
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'di',
        projectRoot: workspace.path,
      );

      final result = await wrapper.execute({
        'name': 'Product',
        'methods': ['get', 'update'],
      });

      expect(result.success, isTrue, reason: 'the run itself succeeds');
      expect(
        receiptsDir().existsSync(),
        isTrue,
        reason: '.zfa/receipts/ must exist after the invocation',
      );
      final files = receiptsDir()
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList();
      expect(files, hasLength(1));
      // Key shape: <plugin>-<capability>-<entity>-<timestamp>.json. The
      // timestamp is the portable UTC ISO-8601 form (colons sanitized).
      expect(
        files.single,
        matches(
          RegExp(
            r'^di-create-Product-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}'
            r'(\.\d+)?Z?\.json$',
          ),
        ),
        reason: 'receipt file name must follow the issue #996 key shape',
      );
    });

    test('a failed execution writes NO receipt', () async {
      final capability = writingCapability(success: false);
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'usecase',
        projectRoot: workspace.path,
      );

      final result = await wrapper.execute({'name': 'Product'});

      expect(result.success, isFalse);
      expect(receiptsDir().existsSync(), isFalse);
    });

    test(
      'a successful execution that wrote ZERO files writes NO receipt',
      () async {
        final capability = WritingCapability(
          projectRoot: workspace.path,
          entityName: 'Product',
          action: 'created',
          success: true,
          writeArtifact: false,
        );
        final wrapper = CapabilityInvocationWrapper(
          capability: capability,
          pluginId: 'service',
          projectRoot: workspace.path,
        );

        await wrapper.execute({'name': 'Product'});

        expect(receiptsDir().existsSync(), isFalse);
      },
    );

    test('skipped and deleted actions are not receipted (no final bytes '
        'from this run)', () async {
      final capability = writingCapability(action: 'skipped');
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'provider',
        projectRoot: workspace.path,
      );

      await wrapper.execute({'name': 'Product'});

      expect(receiptsDir().existsSync(), isFalse);
    });

    test('receipt persistence is best-effort: an unwritable store warns, '
        'the run still succeeds', () async {
      // A FILE parked where `.zfa/receipts/` must go makes the store
      // unwritable — the capability result must survive untouched.
      await File(p.join(workspace.path, '.zfa')).writeAsString('blocker');
      final capability = writingCapability();
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'di',
        projectRoot: workspace.path,
      );

      final result = await wrapper.execute({'name': 'Product'});

      expect(result.success, isTrue);
    }, skip: Platform.isWindows ? 'POSIX blocker file' : false);
  });

  group('T003 — machine-readable receipt schema', () {
    test('receipt JSON carries {plugin, capability, entity, hash, '
        'methodset, files, receipt_version: 1}', () async {
      final capability = writingCapability();
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'di',
        projectRoot: workspace.path,
      );

      await wrapper.execute({
        'name': 'Product',
        'methods': ['get', 'update'],
      });

      final store = ReceiptStore(projectRoot: workspace.path);
      final records = await store.loadAll();
      expect(records, hasLength(1));
      final receipt = records.single.receipt;

      // proof.v1 envelope — `zfa proof check` re-derives these digests.
      expect(receipt.schema, 'proof.v1');
      expect(receipt.command, 'di create');
      expect(receipt.target, 'Product');
      expect(receipt.repro, 'zfa di create Product');
      expect(receipt.files, hasLength(1));
      final artifact = p.join(workspace.path, receipt.files.single.path);
      expect(File(artifact).existsSync(), isTrue);
      final artifactBytes = File(artifact).readAsBytesSync();
      expect(
        receipt.files.single.sha256,
        crypto.sha256.convert(artifactBytes).toString(),
      );
      // B-005: the exact per-file binding `zfa proof check` re-derives —
      // action, byte count and text snapshot (proof drift diffs the
      // snapshot). Pinning all three keeps the wrapper's digest contract
      // mutation-tight.
      expect(receipt.files.single.action, 'created');
      expect(receipt.files.single.bytes, artifactBytes.length);
      expect(receipt.files.single.snapshot, '// generated Product\n');
      expect(receipt.files.single.path, 'lib/src/domain/product.dart');

      // Issue #996 machine-readable fields — asserted on the RAW stored
      // JSON document (machine readers consume the file, not the class).
      final json =
          jsonDecode(
                receiptsDir()
                    .listSync()
                    .whereType<File>()
                    .map((f) => f.readAsStringSync())
                    .single,
              )
              as Map<String, dynamic>;
      expect(json['plugin'], 'di');
      expect(json['capability'], 'create');
      expect(json['entity'], 'Product');
      expect(json['receipt_version'], 1);
      expect((json['methodset'] as List).toList(), ['get', 'update']);
      expect(
        json['hash'],
        isA<String>().having(
          (h) => RegExp(r'^[0-9a-f]{64}$').hasMatch(h),
          'sha256 hex',
          isTrue,
        ),
      );
      expect(json['files'], isA<List>().having((l) => l.length, 'length', 1));
    });

    test('hash binds the run: entity + methodset + per-file '
        '(path, action, digest)', () async {
      final capability = writingCapability();
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'repository',
        projectRoot: workspace.path,
      );

      await wrapper.execute({
        'name': 'Product',
        'methods': ['get'],
      });

      final store = ReceiptStore(projectRoot: workspace.path);
      final receipt = (await store.loadAll()).single.receipt;
      final file = receipt.files.single;

      // Canonical derivation, pinned exactly so a mutant in the hash
      // computation cannot survive.
      final canonical = StringBuffer()
        ..writeln('entity:Product')
        ..writeln('methodset:get');
      canonical.writeln('file:${file.path}:${file.action}:${file.sha256}');
      final expected = crypto.sha256
          .convert(utf8.encode(canonical.toString()))
          .toString();
      expect(receipt.runHash, expected);
    });

    test('methodset defaults to the wired methods from args; entity falls '
        'back to the result name', () async {
      // sync enable carries no methods arg — the methodset is empty but
      // PRESENT in the JSON (machine readers must not guess).
      final capability = writingCapability(capabilityName: 'enable');
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'sync',
        projectRoot: workspace.path,
      );
      await wrapper.execute({'name': 'Cart'});

      final store = ReceiptStore(projectRoot: workspace.path);
      final receipt = (await store.loadAll()).single.receipt;
      expect(receipt.methodset, isEmpty);
      expect(receipt.entity, 'Cart');
      expect(receipt.capability, 'enable');
      expect(receipt.plugin, 'sync');
    });
  });

  group('mutation hardening — exact contracts the audit must not lose', () {
    test('a binary artifact is receipted with NO snapshot (snapshot path '
        'only admits UTF-8 text)', () async {
      // 2 KiB of non-UTF-8 bytes: small enough to keep a snapshot, but
      // binary — the wrapper must store null, not garbage.
      final capability = WritingCapability(
        projectRoot: workspace.path,
        entityName: 'Blob',
        artifacts: [('lib/src/domain/blob.bin', List.filled(2048, 0xff))],
      );
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'datasource',
        projectRoot: workspace.path,
      );

      final result = await wrapper.execute({'name': 'Blob'});

      expect(result.success, isTrue);
      final store = ReceiptStore(projectRoot: workspace.path);
      final records = await store.loadAll();
      expect(
        records,
        hasLength(1),
        reason:
            'binary artifacts still ship a '
            'receipt',
      );
      final entry = records.single.receipt.files.single;
      expect(
        entry.snapshot,
        isNull,
        reason:
            'binary content is never '
            'snapshotted',
      );
      expect(entry.bytes, 2048);
    });

    test('an artifact of exactly maxSnapshotBytes keeps its snapshot '
        '(boundary is inclusive)', () async {
      final exactly = ReceiptStore.maxSnapshotBytes;
      final capability = WritingCapability(
        projectRoot: workspace.path,
        entityName: 'Big',
        artifacts: [('lib/src/domain/big.txt', utf8.encode('x' * exactly))],
      );
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'service',
        projectRoot: workspace.path,
      );

      await wrapper.execute({'name': 'Big'});

      final records = await ReceiptStore(projectRoot: workspace.path).loadAll();
      expect(records, hasLength(1));
      expect(
        records.single.receipt.files.single.snapshot,
        isNotNull,
        reason: 'bytes == maxSnapshotBytes is within the snapshot cap',
      );
    });

    test('multi-file receipts are path-sorted (and the run hash binds the '
        'sorted order)', () async {
      // Reported in REVERSE order on purpose: the receipt must sort.
      final capability = WritingCapability(
        projectRoot: workspace.path,
        entityName: 'Multi',
        artifacts: [
          ('lib/src/domain/zeta.dart', utf8.encode('// z\n')),
          ('lib/src/domain/alpha.dart', utf8.encode('// a\n')),
        ],
      );
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'usecase',
        projectRoot: workspace.path,
      );

      await wrapper.execute({
        'name': 'Multi',
        'methods': ['get'],
      });

      final records = await ReceiptStore(projectRoot: workspace.path).loadAll();
      final receipt = records.single.receipt;
      expect(
        receipt.files.map((f) => f.path).toList(),
        ['lib/src/domain/alpha.dart', 'lib/src/domain/zeta.dart'],
        reason:
            'receipt files are sorted by path, whatever the generator '
            'reported',
      );
      // The hash derivation re-derives over the SORTED files.
      final canonical = StringBuffer()
        ..writeln('entity:Multi')
        ..writeln('methodset:get');
      for (final f in receipt.files) {
        canonical.writeln('file:${f.path}:${f.action}:${f.sha256}');
      }
      expect(
        receipt.runHash,
        crypto.sha256.convert(utf8.encode(canonical.toString())).toString(),
      );
    });

    test('an empty name falls through the entity chain to the capability '
        'name', () async {
      final capability = writingCapability();
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'di',
        projectRoot: workspace.path,
      );

      await wrapper.execute({'name': ''});

      final records = await ReceiptStore(projectRoot: workspace.path).loadAll();
      expect(
        records.single.receipt.entity,
        'create',
        reason:
            'args name "" is not an entity; the capability name is '
            'the last resort',
      );
    });

    test(
      'the result payload name is the entity when args carry none',
      () async {
        final capability = WritingCapability(
          projectRoot: workspace.path,
          entityName: 'Product',
          resultName: 'FromResult',
        );
        final wrapper = CapabilityInvocationWrapper(
          capability: capability,
          pluginId: 'di',
          projectRoot: workspace.path,
        );

        await wrapper.execute({
          'methods': ['get'],
        });

        final records = await ReceiptStore(
          projectRoot: workspace.path,
        ).loadAll();
        expect(records.single.receipt.entity, 'FromResult');
      },
    );

    test(
      'a comma-separated --methods STRING is split into the methodset',
      () async {
        final capability = writingCapability();
        final wrapper = CapabilityInvocationWrapper(
          capability: capability,
          pluginId: 'di',
          projectRoot: workspace.path,
        );

        await wrapper.execute({'name': 'Product', 'methods': 'get, update'});

        final records = await ReceiptStore(
          projectRoot: workspace.path,
        ).loadAll();
        expect(records.single.receipt.methodset, [
          'get',
          'update',
        ], reason: 'the CLI delivers list flags as comma strings');
      },
    );

    test('backslash separators in reported paths are normalized to POSIX '
        'separators', () async {
      // A file literally named with backslashes is a valid POSIX artifact;
      // the receipt path must use forward slashes.
      const reported = 'lib\\generated\\win_path.dart';
      final capability = WritingCapability(
        projectRoot: workspace.path,
        entityName: 'Win',
        artifacts: [(reported, utf8.encode('// win\n'))],
      );
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'observer',
        projectRoot: workspace.path,
      );

      await wrapper.execute({'name': 'Win'});

      final records = await ReceiptStore(projectRoot: workspace.path).loadAll();
      expect(
        records.single.receipt.files.single.path,
        'lib/generated/win_path.dart',
      );
    });

    test('NamedCapability is a persistence view: execute is unsupported '
        'and says so', () async {
      await expectLater(
        () => NamedCapability('list').execute(const {}),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message ?? '',
            'message',
            contains('NamedCapability is a receipt-persistence view'),
          ),
        ),
      );
    });
  });

  group('wrapper — plain capability delegation', () {
    test(
      'execute() forwards the args verbatim and returns the result',
      () async {
        final capability = writingCapability();
        final wrapper = CapabilityInvocationWrapper(
          capability: capability,
          pluginId: 'observer',
          projectRoot: workspace.path,
        );

        await wrapper.execute({'name': 'Product', 'dryRun': false});

        expect(capability.lastArgs, {'name': 'Product', 'dryRun': false});
      },
    );
  });
}

/// Real-file-writing capability stub.
class WritingCapability implements ZuraffaCapability {
  WritingCapability({
    required this.projectRoot,
    required this.entityName,
    this.action = 'created',
    this.success = true,
    this.writeArtifact = true,
    this.capabilityName = 'create',
    this.resultName,
    this.artifacts = const [],
  });

  final String projectRoot;
  final String entityName;
  final String action;
  final bool success;
  final bool writeArtifact;
  final String capabilityName;

  /// Name reported in ExecutionResult.data['name'] (the entity fallback
  /// chain: args -> result -> capability name).
  final String? resultName;

  /// Extra artifacts to write and report, as (relativePath, bytes) pairs;
  /// when empty the default single product artifact is used.
  final List<(String, List<int>)> artifacts;

  Map<String, dynamic>? lastArgs;

  @override
  String get name => capabilityName;

  @override
  String get description => 'Writing capability stub';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'methods': {'type': 'array'},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'files': {'type': 'array'},
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'plan',
    pluginId: 'stub',
    capabilityName: name,
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    lastArgs = args;
    if (!success) {
      return ExecutionResult(success: false, message: 'declined');
    }
    final generated = <GeneratedFile>[];
    if (artifacts.isEmpty) {
      if (writeArtifact) {
        final file = File(
          p.join(projectRoot, 'lib', 'src', 'domain', 'product.dart'),
        );
        await file.parent.create(recursive: true);
        await file.writeAsString('// generated $entityName\n');
        generated.add(
          GeneratedFile(
            path: 'lib/src/domain/product.dart',
            type: 'entity',
            action: action,
          ),
        );
      }
    } else {
      for (final (relative, bytes) in artifacts) {
        final file = File(p.join(projectRoot, relative));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        generated.add(
          GeneratedFile(path: relative, type: 'entity', action: action),
        );
      }
    }
    return ExecutionResult(
      success: true,
      files: generated.map((f) => f.path).toList(),
      data: {
        'generatedFiles': generated,
        if (resultName != null) 'name': resultName,
      },
    );
  }
}
