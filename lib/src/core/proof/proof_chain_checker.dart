import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../plugins/tdd/services/artifact_registry.dart';
import '../../plugins/tdd/services/cycle_evidence.dart';
import '../../plugins/tdd/services/import_resolution.dart';
import '../../plugins/usecase/conformance/usecase_gate.dart';
import '../project/receipt_store.dart';
import '../project/test_receipt.dart';
import 'proof_checker.dart';

// The proof chain (issue #1148, VISION-4, EPIC 5): one command that
// validates every link — spec → plan → behaviors → gen → verify-red →
// make → receipt → realize → world — against what actually exists on
// disk.
//
// [ProofChainChecker] is a READ-ONLY auditor. It walks `.zfa/receipts/`
// and the tdd stores under `specs/` and produces a [ProofChainReport]:
// a `proof-chain.v1` verdict listing every drift and every gap with
// category, file, expected, actual and a fix.
//
// Severity semantics (the issue's hard constraint: "missing receipts
// are reported as gaps, not errors"):
//   * `drift` — something that EXISTS contradicts its proof: a
//     receipted artifact whose digest no longer matches, green
//     evidence naming a deleted test, a failed route verify verdict,
//     usecases that no longer conform, a test-runner failure under
//     `--run-tests`. Drift exits 1.
//   * `gap` — a link of the chain that does not exist YET: a behavior
//     without green evidence, a route table never verified, an
//     untraced coverage kind, a usecase tree never generated. Gaps are
//     reported, never silently green — and never exit-failing.
//   * `info` — advisory context (runtime not exercised without
//     `--run-tests`, a route verify explicitly skipped with a reason).
//
// Exit codes follow the ratified SPEC 917 protocol: 0 intact (no
// drift), 1 drift, 2 infrastructure error (unreadable stores).
//
// The command composes the SAME stores the generation verbs, the tdd
// machinery and the verify gates write (`ReceiptStore`,
// `TestReceiptStore`, `CycleEvidence`, `ArtifactRegistry`, the route
// verify receipts, the usecase gate) — and the #807 [ProofChecker]
// engine, by composition, for the deep receipt findings (stale spec,
// stale usecase, manifest drift) its digest walk already derives. The
// existing `zfa proof check` command is untouched.

/// Severity of one verdict item.
enum ProofChainSeverity {
  /// Existing proof contradicts the tree — exit 1.
  drift,

  /// A chain link that does not exist yet — reported, never exit-failing.
  gap,

  /// Advisory context — never affects the exit code.
  info,
}

/// Which of the six chain checks produced an item.
enum ProofChainCheckKind {
  receiptDigest('receipt_digest'),
  behaviorCoverage('behavior_coverage'),
  testIntegrity('test_integrity'),
  testRuntime('test_runtime'),
  routeVerify('route_verify'),
  usecaseVerify('usecase_verify'),
  xrayCoverage('xray_coverage');

  const ProofChainCheckKind(this.category);

  /// The stable machine category string every item carries.
  final String category;

  /// The JSON key of the per-check count.
  String get countKey => switch (this) {
    receiptDigest => 'receiptDigest',
    behaviorCoverage => 'behaviorCoverage',
    testIntegrity => 'testIntegrity',
    testRuntime => 'testRuntime',
    routeVerify => 'routeVerify',
    usecaseVerify => 'usecaseVerify',
    xrayCoverage => 'xrayCoverage',
  };
}

/// One drift/gap/info item of the chain verdict.
class ProofChainItem {
  final ProofChainCheckKind check;
  final ProofChainSeverity severity;

  /// Stable machine category (mirrors [ProofChainCheckKind.category]).
  final String category;

  /// Project-relative POSIX path of the file the item is about.
  final String file;

  /// What the chain expects at this link.
  final String expected;

  /// What the tree actually holds.
  final String actual;

  /// The `--> fix:` line — one pasteable command or action.
  final String fix;

  const ProofChainItem({
    required this.check,
    required this.severity,
    required this.category,
    required this.file,
    required this.expected,
    required this.actual,
    required this.fix,
  });

  Map<String, dynamic> toJson() => {
    'check': check.category,
    'category': category,
    'severity': severity.name,
    'file': file,
    'expected': expected,
    'actual': actual,
    'fix': fix,
  };
}

/// The machine-verifiable verdict of one `zfa proof chain` invocation.
class ProofChainReport {
  static const schema = 'proof-chain.v1';

  final List<ProofChainItem> items;

  /// Infrastructure failures: stores that could not be read at all
  /// (issue #1148: "exit 2 = infrastructure error"). Everything else
  /// degrades to honest items.
  final List<String> infraErrors;

  const ProofChainReport({required this.items, this.infraErrors = const []});

  Iterable<ProofChainItem> get drifts =>
      items.where((i) => i.severity == ProofChainSeverity.drift);

  int get driftCount => drifts.length;

  int get gapCount =>
      items.where((i) => i.severity == ProofChainSeverity.gap).length;

  int get infoCount =>
      items.where((i) => i.severity == ProofChainSeverity.info).length;

  /// Per-check item counts (drift + gap — info items are context, not
  /// check surface). Every check key is always present.
  Map<String, int> get counts => {
    for (final kind in ProofChainCheckKind.values)
      kind.countKey: items
          .where(
            (i) => i.check == kind && i.severity != ProofChainSeverity.info,
          )
          .length,
  };

  /// True when the chain is intact: no infra errors and no drift. Gaps
  /// do NOT fail — they are open links, reported honestly.
  bool get ok => infraErrors.isEmpty && driftCount == 0;

  /// SPEC 917 exit code: 0 intact, 1 drift, 2 infrastructure error.
  int get exitCode => switch (this) {
    _ when infraErrors.isNotEmpty => 2,
    _ when driftCount > 0 => 1,
    _ => 0,
  };

  /// The exit class label (the JSON verdict's machine flavor).
  String get exitClass => switch (exitCode) {
    0 => 'ok',
    1 => 'drift',
    _ => 'infra',
  };

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'ok': ok,
    'exitClass': exitClass,
    'exitCode': exitCode,
    'counts': counts,
    'drifts': driftCount,
    'gaps': gapCount,
    'info': infoCount,
    'items': items.map((i) => i.toJson()).toList(),
    'infraErrors': infraErrors,
  };
}

/// Injectable test runner (the route-verify seam pattern): production
/// spawns `dart test`; unit tests fake it.
typedef ChainTestRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> args, {
      String? workingDirectory,
    });

/// The route verify verdict read from the persisted receipt
/// (`.zfa/receipts/routes-<Entity>-verify.json`, written by
/// `zfa route verify`).
class RouteVerifyVerdict {
  /// The entity whose routes were verified.
  final String entity;

  /// The raw verdict label recorded by the verify run
  /// (`pass` / `fail` / `skip`).
  final String label;

  /// The structured `verdict.ok` flag (false when absent).
  final bool ok;

  /// Whether the verify recorded an explicit skip.
  final bool skipped;

  /// The recorded skip reason, when present.
  final String? reason;

  const RouteVerifyVerdict({
    required this.entity,
    required this.label,
    required this.ok,
    required this.skipped,
    this.reason,
  });
}

/// Reads the LATEST route verify verdict receipt for an entity.
class RouteVerifyReader {
  final String projectRoot;

  const RouteVerifyReader({required this.projectRoot});

  Directory get _receipts => Directory(p.join(projectRoot, '.zfa', 'receipts'));

  /// Entities with a DECLARED route table receipt
  /// (`routes-<Entity>.json`, the `zfa route create` ledger).
  List<String> declaredEntities() {
    if (!_receipts.existsSync()) return const [];
    final entities = <String>[];
    for (final entity in _receipts.listSync().whereType<File>()) {
      final base = p.basename(entity.path);
      if (!base.startsWith('routes-')) continue;
      if (!base.endsWith('.json')) continue;
      if (base.endsWith('-verify.json')) continue;
      final name = base
          .substring('routes-'.length, base.length - '.json'.length)
          .trim();
      if (name.isNotEmpty) entities.add(name);
    }
    return entities.toSet().toList()..sort();
  }

  /// The verify verdict for [entity], or null when none was ever
  /// recorded (a gap, not an error).
  RouteVerifyVerdict? latestVerdict(String entity) {
    final file = File(p.join(_receipts.path, 'routes-$entity-verify.json'));
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      final input = json['input'] is Map
          ? Map<String, dynamic>.from(json['input'] as Map)
          : const <String, dynamic>{};
      final verdict = json['verdict'] is Map
          ? Map<String, dynamic>.from(json['verdict'] as Map)
          : const <String, dynamic>{};
      final rawLabel = input['verdict'];
      final label = rawLabel is String ? rawLabel : 'unknown';
      final skipped =
          label == 'skip' ||
          verdict['skipped'] == true ||
          input['skipped'] == true;
      final rawReason = verdict['reason'] ?? input['reason'];
      return RouteVerifyVerdict(
        entity: entity,
        label: label,
        ok: verdict['ok'] is bool ? verdict['ok'] as bool : false,
        skipped: skipped,
        reason: rawReason is String
            ? rawReason
            : (skipped ? '(no reason recorded)' : null),
      );
    } on FormatException {
      // A corrupt verdict receipt is unreadable evidence — reported by
      // the corrupt-receipt scan, never fatal here.
      return null;
    } on FileSystemException {
      return null;
    }
  }
}

/// The end-to-end proof chain checker (issue #1148).
class ProofChainChecker {
  final String projectRoot;

  /// Executes one registered test file. Defaults to `dart test <file>`;
  /// injectable so unit tests drive `--run-tests` without a subprocess.
  final ChainTestRunner testRunner;

  /// Per-test budget for the REAL runner (issue #1333's lesson: a
  /// crashed runner certifies nothing; a hung one must not hang the
  /// chain). Fakes bypass this entirely.
  static const Duration perTestBudget = Duration(minutes: 10);

  ProofChainChecker({required this.projectRoot, ChainTestRunner? testRunner})
    : testRunner = testRunner ?? _defaultTestRunner;

  static Future<ProcessResult> _defaultTestRunner(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final run = Process.run(
      executable,
      args,
      workingDirectory: workingDirectory,
    );
    try {
      return await run.timeout(perTestBudget);
    } on TimeoutException {
      // The future may still complete late; swallow it silently
      // instead of leaking an unhandled async error.
      run.ignore();
      return ProcessResult(
        0,
        -1,
        '',
        'test runner exceeded its budget (${perTestBudget.inMinutes}m)',
      );
    }
  }

  /// Runs every chain check and returns the verdict. Never throws for
  /// store-level problems — those land in [ProofChainReport.infraErrors]
  /// (exit 2) or degrade to honest items.
  Future<ProofChainReport> check({bool runTests = false}) async {
    final items = <ProofChainItem>[];
    final infra = <String>[];

    // Infra pre-check: the receipts path occupied by a non-directory is
    // unreadable state (issue #1148's exit-2 class).
    final receiptsType = FileSystemEntity.typeSync(
      p.join(projectRoot, '.zfa', 'receipts'),
    );
    if (receiptsType == FileSystemEntityType.file) {
      infra.add('.zfa/receipts exists but is a file, not a directory');
    }
    final specsType = FileSystemEntity.typeSync(p.join(projectRoot, 'specs'));
    if (specsType == FileSystemEntityType.file) {
      infra.add('specs/ exists but is a file, not a directory');
    }

    final greenByFeature = <String, Set<String>>{};

    await _checkReceiptDigests(items, infra);
    await _checkBehaviorCoverage(items, infra, greenByFeature);
    await _checkTestIntegrity(items, infra, runTests: runTests);
    await _checkRouteVerifies(items);
    await _checkUsecaseVerifies(items);
    await _checkXrayCoverage(items, infra, greenByFeature);

    return ProofChainReport(items: items, infraErrors: infra);
  }

  // ---------------------------------------------------------------------
  // Check 1 — receipt digest validation (issue #1148 AC 1).
  // ---------------------------------------------------------------------

  Future<void> _checkReceiptDigests(
    List<ProofChainItem> items,
    List<String> infra,
  ) async {
    final store = ReceiptStore(projectRoot: projectRoot);
    List<ReceiptRecord> records;
    try {
      records = await store.loadAll();
    } on FileSystemException catch (e) {
      infra.add('.zfa/receipts could not be read: ${e.message}');
      return;
    }

    // Corrupt documents are skipped by loadAll — surfaced here as gaps
    // (one broken receipt must not erase healthy provenance, but it
    // must not be silent either).
    await _scanCorruptReceipts(items);

    // Latest receipt wins per artifact path (regeneration supersedes).
    final latest =
        <String, ({ReceiptRecord record, GenerationReceiptFile entry})>{};
    for (final record in records) {
      for (final entry in record.receipt.files) {
        latest[entry.path] = (record: record, entry: entry);
      }
    }

    for (final covered in latest.entries) {
      final path = covered.key;
      final record = covered.value.record;
      final entry = covered.value.entry;
      final file = File(p.join(projectRoot, path));
      if (!file.existsSync()) {
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.receiptDigest,
            severity: ProofChainSeverity.drift,
            category: ProofChainCheckKind.receiptDigest.category,
            file: path,
            expected: 'file present (sha256 ${_short(entry.sha256)})',
            actual: 'missing from disk',
            fix: 'reproduce with: ${record.receipt.repro}',
          ),
        );
        continue;
      }
      final actualBytes = file.readAsBytesSync();
      final actual = crypto.sha256.convert(actualBytes).toString();
      if (actual != entry.sha256) {
        if (_isSanctionedAppend(path, entry, actualBytes)) continue;
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.receiptDigest,
            severity: ProofChainSeverity.drift,
            category: ProofChainCheckKind.receiptDigest.category,
            file: path,
            expected: entry.sha256,
            actual: actual,
            fix: 'reproduce with: ${record.receipt.repro}',
          ),
        );
      }
    }

    // test.v1 receipts (spec 980): per-method test digests.
    final testReceipts = await TestReceiptStore(
      projectRoot: projectRoot,
    ).loadAll();
    for (final receipt in testReceipts) {
      final receiptName = TestReceiptStore.fileNameFor(receipt.entity);
      for (final entry in receipt.tests) {
        final file = File(p.join(projectRoot, entry.testPath));
        if (!file.existsSync()) {
          items.add(
            ProofChainItem(
              check: ProofChainCheckKind.receiptDigest,
              severity: ProofChainSeverity.drift,
              category: ProofChainCheckKind.receiptDigest.category,
              file: entry.testPath,
              expected: 'file present (sha256 ${_short(entry.testSha256)})',
              actual: 'missing from disk',
              fix: 'regenerate with: ${receipt.command}',
            ),
          );
          continue;
        }
        final actual = crypto.sha256.convert(file.readAsBytesSync()).toString();
        if (actual == entry.testSha256) continue;
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.receiptDigest,
            severity: ProofChainSeverity.drift,
            category: ProofChainCheckKind.receiptDigest.category,
            file: entry.testPath,
            expected: entry.testSha256,
            actual: actual,
            fix: 'regenerate with: ${receipt.command} ($receiptName)',
          ),
        );
      }
    }

    // Deep findings from the #807 engine (stale spec, stale usecase,
    // manifest drift, unprovenanced coverage roots) — composed, never
    // modified. Deduped against the structured walk above by file.
    try {
      final deep = await ProofChecker(projectRoot: projectRoot).check();
      final flagged = items
          .where((i) => i.severity == ProofChainSeverity.drift)
          .map((i) => i.file)
          .toSet();
      for (final finding in deep.findings) {
        if (flagged.contains(finding.path)) continue;
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.receiptDigest,
            severity: ProofChainSeverity.drift,
            category: ProofChainCheckKind.receiptDigest.category,
            file: finding.path,
            expected: 'receipt-backed artifact unchanged (${finding.kind})',
            actual: finding.detail,
            fix:
                'reproduce with the receipt\'s repro command, or restore '
                'the recorded bytes',
          ),
        );
      }
    } catch (_) {
      // The deep engine must never crash the chain — its store is
      // already covered by the structured walk above.
    }
  }

  /// A corrupt receipt document is a gap (the ReceiptStore skip rule,
  /// made visible instead of silent).
  Future<void> _scanCorruptReceipts(List<ProofChainItem> items) async {
    final dir = Directory(p.join(projectRoot, '.zfa', 'receipts'));
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync().whereType<File>()) {
      final base = p.basename(entity.path);
      if (!base.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        if (base.startsWith('test-')) {
          TestReceipt.fromJson(json);
        } else {
          GenerationReceipt.fromJson(json);
        }
      } catch (_) {
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.receiptDigest,
            severity: ProofChainSeverity.gap,
            category: ProofChainCheckKind.receiptDigest.category,
            file: '.zfa/receipts/$base',
            expected: 'parseable receipt document',
            actual: 'corrupt JSON — skipped by loadAll',
            fix:
                'delete or regenerate the receipt: it proves nothing '
                'in this state',
          ),
        );
      }
    }
  }

  /// Whether the drift on [path] is the sanctioned append class
  /// (issue #1327) — the same rule `ProofChecker` applies, re-derived
  /// here so the structured walk can honor it. An append-only log
  /// (basename in [ProofChecker.appendOnlyBasenames]) whose receipt
  /// carries a snapshot and whose disk bytes still start with exactly
  /// those bytes is NOT drift: the receipted region is untouched.
  bool _isSanctionedAppend(
    String path,
    GenerationReceiptFile entry,
    List<int> actualBytes,
  ) {
    final snapshot = entry.snapshot;
    if (snapshot == null) return false;
    if (!ProofChecker.appendOnlyBasenames.contains(p.basename(path))) {
      return false;
    }
    final receiptedBytes = const Utf8Encoder().convert(snapshot);
    if (actualBytes.length < receiptedBytes.length) return false;
    for (var i = 0; i < receiptedBytes.length; i++) {
      if (actualBytes[i] != receiptedBytes[i]) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Check 2 — behavior test coverage (issue #1148 AC 2).
  // ---------------------------------------------------------------------

  Future<void> _checkBehaviorCoverage(
    List<ProofChainItem> items,
    List<String> infra,
    Map<String, Set<String>> greenByFeature,
  ) async {
    for (final featureDir in _featureDirs(infra)) {
      final feature = p.basename(featureDir.path);
      final evidence = CycleEvidence(featureDir.path);
      final green = await evidence.greenEvidence();
      greenByFeature[feature] = green;

      final testList = File(p.join(featureDir.path, 'tdd', 'test-list.md'));
      if (!testList.existsSync()) continue;
      String raw;
      try {
        raw = await testList.readAsString();
      } on FileSystemException {
        continue;
      }
      final ids = _behaviorIdsOf(raw, featureDir.path);
      if (ids.isEmpty) continue;

      final relativeList = 'specs/$feature/tdd/test-list.md';
      for (final id in ids) {
        if (green.contains(id)) continue;
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.behaviorCoverage,
            severity: ProofChainSeverity.gap,
            category: ProofChainCheckKind.behaviorCoverage.category,
            file: relativeList,
            expected: 'green evidence for "$id" in tdd/cycle-log.md',
            actual: 'no green entry for "$id"',
            fix: 'zfa tdd run $feature',
          ),
        );
      }

      // Evidence-without-artifact (issue #1264): green evidence whose
      // test file is gone is DRIFT — existing evidence must stay
      // honest (spec 1334 US2-S3).
      final orphaned = await evidence.orphanedGreenEvidence(
        projectRoot: projectRoot,
      );
      for (final id in orphaned) {
        final lastGreen = await evidence.lastEntryFor(id, kind: 'green');
        final testPath = lastGreen?.test ?? '(unknown)';
        final clean = testPath.contains('::')
            ? testPath.split('::').first
            : testPath;
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.testIntegrity,
            severity: ProofChainSeverity.drift,
            category: ProofChainCheckKind.testIntegrity.category,
            file: _relativePosix(clean),
            expected: 'test file backing green evidence for "$id"',
            actual: 'missing from disk (evidence-without-artifact)',
            fix: 'zfa tdd run $feature',
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Check 3 — generated test integrity (+ optional runtime) (AC 3).
  // ---------------------------------------------------------------------

  Future<void> _checkTestIntegrity(
    List<ProofChainItem> items,
    List<String> infra, {
    required bool runTests,
  }) async {
    for (final featureDir in _featureDirs(infra)) {
      final feature = p.basename(featureDir.path);
      final registry = ArtifactRegistry(featureDir: featureDir.path);
      final records = await registry.loadAll();
      if (records.isEmpty) continue;

      for (final record in records) {
        final resolved = p.isAbsolute(record.testPath)
            ? p.normalize(record.testPath)
            : p.normalize(p.join(projectRoot, record.testPath));
        final relative = _relativePosix(resolved);

        if (!File(resolved).existsSync()) {
          items.add(
            ProofChainItem(
              check: ProofChainCheckKind.testIntegrity,
              severity: ProofChainSeverity.drift,
              category: ProofChainCheckKind.testIntegrity.category,
              file: relative,
              expected: 'registered test file on disk',
              actual: 'missing from disk (artifacts.json records it)',
              fix:
                  'zfa tdd gen ${record.behaviorId} --feature $feature '
                  '(or zfa tdd reset $feature)',
            ),
          );
          continue;
        }

        // Compile-level integrity: every relative/self-package import
        // must resolve (the doctor import seam, issue #912).
        String source;
        try {
          source = File(resolved).readAsStringSync();
        } on FileSystemException {
          continue;
        }
        final issues = unresolvedImports(
          source: source,
          filePath: resolved,
          projectRoot: projectRoot,
          packageName: hostPackageName(projectRoot),
        );
        for (final issue in issues) {
          items.add(
            ProofChainItem(
              check: ProofChainCheckKind.testIntegrity,
              severity: ProofChainSeverity.drift,
              category: ProofChainCheckKind.testIntegrity.category,
              file: relative,
              expected: 'every import resolves',
              actual:
                  "import '${issue.uri}' does not resolve "
                  '(${issue.reason})',
              // Issue #1573: prescribe the flag form migrate-paths parses
              // (a positional slug is silently discarded).
              fix: 'zfa tdd migrate-paths --feature $feature',
            ),
          );
        }

        if (runTests) {
          final result = await testRunner('dart', [
            'test',
            resolved,
          ], workingDirectory: projectRoot);
          if (result.exitCode != 0) {
            final err = '${result.stderr}'.trim();
            final out = [
              '${result.stdout}'.trimRight(),
              if (err.isNotEmpty) err,
            ].where((s) => s.isNotEmpty).join('\n').trimRight();
            final tail = out.length > 600
                ? out.substring(out.length - 600)
                : out;
            items.add(
              ProofChainItem(
                check: ProofChainCheckKind.testRuntime,
                severity: ProofChainSeverity.drift,
                category: ProofChainCheckKind.testRuntime.category,
                file: relative,
                expected: 'dart test $relative exits 0',
                actual: 'exit ${result.exitCode}: $tail',
                fix: 'run dart test $relative locally and land the fix',
              ),
            );
          }
        }
      }

      if (!runTests) {
        // Honest runtime disclosure: without --run-tests the chain
        // never claims execution (NFR: gaps are never painted green).
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.testRuntime,
            severity: ProofChainSeverity.info,
            category: ProofChainCheckKind.testRuntime.category,
            file: 'specs/$feature/tdd/artifacts.json',
            expected: 'test executed (--run-tests)',
            actual:
                'runtime not exercised '
                '(${records.length} registered test(s))',
            fix: 're-run with --run-tests to execute the registered suite',
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Check 4 — route verification (issue #1148 AC 4).
  // ---------------------------------------------------------------------

  Future<void> _checkRouteVerifies(List<ProofChainItem> items) async {
    final reader = RouteVerifyReader(projectRoot: projectRoot);
    final entities = reader.declaredEntities();
    for (final entity in entities) {
      final verdict = reader.latestVerdict(entity);
      if (verdict == null) {
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.routeVerify,
            severity: ProofChainSeverity.gap,
            category: ProofChainCheckKind.routeVerify.category,
            file: '.zfa/receipts/routes-$entity.json',
            expected: 'verify verdict at routes-$entity-verify.json',
            actual: 'route table declared but never verified',
            fix: 'zfa route verify $entity',
          ),
        );
        continue;
      }
      if (verdict.skipped) {
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.routeVerify,
            severity: ProofChainSeverity.info,
            category: ProofChainCheckKind.routeVerify.category,
            file: '.zfa/receipts/routes-$entity-verify.json',
            expected: 'verify pass, or explicit skip with reason',
            actual: 'skipped: ${verdict.reason ?? '(no reason recorded)'}',
            fix: 'zfa route verify $entity when the router lands',
          ),
        );
        continue;
      }
      if (!verdict.ok) {
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.routeVerify,
            severity: ProofChainSeverity.drift,
            category: ProofChainCheckKind.routeVerify.category,
            file: '.zfa/receipts/routes-$entity-verify.json',
            expected: 'verify verdict ok',
            actual:
                'verdict ${verdict.label} (ok: false) — the recorded '
                'run failed',
            fix: 'zfa route verify $entity',
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Check 5 — use-case verification (issue #1148 AC 5).
  // ---------------------------------------------------------------------

  Future<void> _checkUsecaseVerifies(List<ProofChainItem> items) async {
    final entities = _usecaseCreateEntities();
    if (entities.isEmpty) return;
    final gate = UsecaseGate();
    for (final entity in entities) {
      try {
        final report = await gate.run(projectRoot: projectRoot, entity: entity);
        if (report.ok) continue;
        final auditedFiles = report.audits
            .map((a) => a.file)
            .whereType<String>()
            .where((f) => f.trim().isNotEmpty)
            .toList();
        final anyArtifactOnDisk = auditedFiles.any(
          (f) =>
              File(p.isAbsolute(f) ? f : p.join(projectRoot, f)).existsSync(),
        );
        if (!anyArtifactOnDisk) {
          items.add(
            ProofChainItem(
              check: ProofChainCheckKind.usecaseVerify,
              severity: ProofChainSeverity.gap,
              category: ProofChainCheckKind.usecaseVerify.category,
              file: auditedFiles.isNotEmpty
                  ? _relativePosix(auditedFiles.first)
                  : 'lib/src/domain/usecases/',
              expected: 'generated usecases for $entity',
              actual:
                  'artifacts missing on disk '
                  '(${report.audits.length} method audit(s))',
              fix: 'zfa usecase create $entity',
            ),
          );
        } else {
          final failing = report.findings.take(3).join('; ');
          items.add(
            ProofChainItem(
              check: ProofChainCheckKind.usecaseVerify,
              severity: ProofChainSeverity.drift,
              category: ProofChainCheckKind.usecaseVerify.category,
              file: _relativePosix(auditedFiles.first),
              expected:
                  'usecases conform to the contract '
                  '(${report.methods.join(', ')})',
              actual: failing.isEmpty
                  ? 'conformance gate failed'
                  : 'conformance findings: $failing',
              fix:
                  'zfa usecase create $entity --force (or zfa usecase '
                  'verify $entity for the detail)',
            ),
          );
        }
      } catch (e) {
        // The gate refusing to run (missing entity source, unreadable
        // config) is a gap, not a crash.
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.usecaseVerify,
            severity: ProofChainSeverity.gap,
            category: ProofChainCheckKind.usecaseVerify.category,
            file: 'lib/src/domain/entities/',
            expected: 'usecase gate runnable for $entity',
            actual: 'gate could not run: $e',
            fix: 'zfa usecase create $entity',
          ),
        );
      }
    }
  }

  /// Entities declared by usecase-create capability receipts
  /// (`usecase-create-<entity>-<timestamp>.json`, issue #1138 key shape).
  List<String> _usecaseCreateEntities() {
    final dir = Directory(p.join(projectRoot, '.zfa', 'receipts'));
    if (!dir.existsSync()) return const [];
    final entities = <String>[];
    for (final entity in dir.listSync().whereType<File>()) {
      final base = p.basename(entity.path);
      if (!base.startsWith('usecase-create-')) continue;
      if (!base.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
        final receipt = GenerationReceipt.fromJson(json);
        if (receipt.plugin != 'usecase') continue;
        if (receipt.capability != null && receipt.capability != 'create') {
          continue;
        }
        final name = (receipt.entity ?? receipt.target).trim();
        if (name.isNotEmpty) entities.add(name);
      } catch (_) {
        // Corrupt receipt — the corrupt-receipt scan reports it.
      }
    }
    return entities.toSet().toList()..sort();
  }

  // ---------------------------------------------------------------------
  // Check 6 — xray coverage traceability (issue #1148 AC 6).
  // ---------------------------------------------------------------------

  Future<void> _checkXrayCoverage(
    List<ProofChainItem> items,
    List<String> infra,
    Map<String, Set<String>> greenByFeature,
  ) async {
    for (final featureDir in _featureDirs(infra)) {
      final feature = p.basename(featureDir.path);
      final ledgerFile = File(p.join(featureDir.path, 'tdd', 'ui-ledger.md'));
      if (!ledgerFile.existsSync()) continue;
      String raw;
      try {
        raw = await ledgerFile.readAsString();
      } on FileSystemException {
        continue;
      }
      final green = greenByFeature.putIfAbsent(feature, () => const <String>{});

      final relativeLedger = 'specs/$feature/tdd/ui-ledger.md';
      for (final row in _ledgerRows(raw)) {
        final provers = row.provers
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final traced = provers.any((id) => green.contains(id));
        if (traced) continue;
        items.add(
          ProofChainItem(
            check: ProofChainCheckKind.xrayCoverage,
            severity: ProofChainSeverity.gap,
            category: ProofChainCheckKind.xrayCoverage.category,
            file: relativeLedger,
            expected:
                '"${row.surface}" (${row.kind}) traced by a green '
                'behavior',
            actual: provers.isEmpty
                ? 'no green prover (row declares none)'
                : 'no green prover (declared: ${provers.join(', ')})',
            fix: 'zfa tdd run $feature',
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Shared helpers.
  // ---------------------------------------------------------------------

  /// Feature directories under `specs/` (empty when absent/unreadable).
  List<Directory> _featureDirs(List<String> infra) {
    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (FileSystemEntity.typeSync(specsDir.path) == FileSystemEntityType.file) {
      return const [];
    }
    if (!specsDir.existsSync()) return const [];
    try {
      return specsDir
          .listSync(followLinks: false)
          .whereType<Directory>()
          .toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    } on FileSystemException catch (e) {
      infra.add('specs/ could not be listed: ${e.message}');
      return const [];
    }
  }

  /// Project-relative POSIX path.
  String _relativePosix(String filePath) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : p.normalize(filePath);
    return rel.replaceAll('\\', '/');
  }

  static String _short(String digest) =>
      digest.length <= 12 ? digest : digest.substring(0, 12);
}

/// One parsed `ui-ledger.md` table row.
class _LedgerRow {
  final String surface;
  final String kind;
  final String provers;

  const _LedgerRow(this.surface, this.kind, this.provers);
}

/// Parses the ledger's `| surface | kind | proven by | state |` table
/// rows (the `UiLedgerBuilder.toMarkdown` shape), skipping headers and
/// separators.
List<_LedgerRow> _ledgerRows(String raw) {
  final rows = <_LedgerRow>[];
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    final cells = trimmed.split('|').map((c) => c.trim()).toList();
    // Leading pipe yields an empty first cell; drop it and the trailing.
    if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
    if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
    if (cells.length < 3) continue;
    final isSeparator = cells.any(
      (c) => c.isNotEmpty && RegExp(r'^-+$').hasMatch(c),
    );
    if (isSeparator) continue;
    if (cells[0].toLowerCase() == 'surface') continue; // header row
    rows.add(_LedgerRow(cells[0], cells[1], cells[2]));
  }
  return rows;
}

/// The behavior-section vocabulary of `tdd/test-list.md` (headers whose
/// rows are BEHAVIORS — everything else is declarations or protocol).
const _behaviorSectionMarkers = [
  'behaviors',
  'behaviour',
  'outer loop',
  'inner loop',
  'theme harness',
  'native loop',
  'platform harness',
  'contract loop',
  'widget behaviors',
];

/// Extracts behavior ids from a test-list: table rows under a behavior
/// section, first cell, id-shaped. Handles both the plan-generated
/// shapes and the hand-shaped `## Behaviors` tables the strict
/// `TestListReader` rejects — a read-only auditor must read what
/// exists, not demand a dialect. Lane-split meta-indexes contribute
/// their engine/skin lane plan files' rows too.
List<String> _behaviorIdsOf(String raw, String featureDir) {
  final ids = <String>[];
  final sources = <String>[raw];
  final splitEngine = File(p.join(featureDir, 'tdd', '04-ENGINE.md'));
  final splitSkin = File(p.join(featureDir, 'tdd', '04-SKIN.md'));
  if (raw.toLowerCase().contains('## lane split')) {
    if (splitEngine.existsSync()) {
      sources.add(splitEngine.readAsStringSync());
    }
    if (splitSkin.existsSync()) {
      sources.add(splitSkin.readAsStringSync());
    }
  }

  for (final source in sources) {
    var inBehaviorSection = false;
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('## ')) {
        final header = trimmed.substring(3).toLowerCase();
        inBehaviorSection = _behaviorSectionMarkers.any(
          (m) => header.startsWith(m),
        );
        continue;
      }
      if (!inBehaviorSection) continue;
      if (!trimmed.startsWith('|')) continue;
      final cells = trimmed.split('|').map((c) => c.trim()).toList();
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.isEmpty) continue;
      final isSeparator = cells.any(
        (c) => c.isNotEmpty && RegExp(r'^-+$').hasMatch(c),
      );
      if (isSeparator) continue;
      final id = cells[0];
      if (id.isEmpty || id == '#') continue;
      if (cells.length > 1 &&
          (cells[1].toLowerCase() == 'behavior' ||
              cells[1].toLowerCase() == 'id')) {
        continue; // header row
      }
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$').hasMatch(id)) continue;
      if (!ids.contains(id)) ids.add(id);
    }
  }
  return ids;
}
