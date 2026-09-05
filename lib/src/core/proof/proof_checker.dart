import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../plugins/repository/contract/repository_contract_manifest.dart';
import '../project/receipt_store.dart';
import '../project/test_receipt.dart';

/// Proof-carrying generation (issue #807).
///
/// [ProofChecker] re-derives every digest recorded in `.zfa/receipts/`
/// against the current tree and reports, with precision:
///   * `modified`       — a receipted artifact no longer matches the bytes
///                        its generation run wrote (with a line diff when
///                        the receipt kept a snapshot),
///   * `deleted`        — a receipted artifact is gone,
///   * `stale_spec`     — the spec an artifact was generated FROM has
///                        drifted since the run (the finding names the
///                        exact spec delta),
///   * `stale_usecase`  — a test plugin `test.v1` receipt records a
///                        usecase whose current bytes differ from the
///                        digest at generation time: usecase/test drift
///                        (spec 980),
///   * `unprovenanced`  — a file under an audited coverage root that no
///                        receipt can prove provenance for.

/// One verification finding. [receipt] names the receipt document the
/// finding came from; [detail] is a single human line; [diff] carries the
/// precise line delta when a snapshot made one computable.
class ProofFinding {
  static const kindModified = 'modified';
  static const kindDeleted = 'deleted';
  static const kindStaleSpec = 'stale_spec';
  static const kindStaleUsecase = 'stale_usecase';
  static const kindUnprovenanced = 'unprovenanced';

  /// Spec 0973 — repository contract manifest findings.
  static const kindManifestDrift = 'manifest_drift';
  static const kindManifestCorrupt = 'manifest_corrupt';

  final String kind;
  final String path;
  final String receipt;
  final String detail;

  /// Unified-ish line diff (`-`/`+`/context lines) when computable.
  final String? diff;

  const ProofFinding({
    required this.kind,
    required this.path,
    required this.receipt,
    required this.detail,
    this.diff,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'path': path,
    'receipt': receipt,
    'detail': detail,
    if (diff != null) 'diff': diff,
  };
}

/// Machine-verifiable verdict for one `zfa proof check` invocation.
class ProofReport {
  static const schema = 'proof.v1';

  final bool ok;
  final int receipts;
  final int filesChecked;
  final List<ProofFinding> findings;

  const ProofReport({
    required this.ok,
    required this.receipts,
    required this.filesChecked,
    required this.findings,
  });

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'ok': ok,
    // Issue #996: the machine verdict also speaks `valid` — agents and
    // CI read one field for both proof families (make + capability).
    'valid': ok,
    'receipts': receipts,
    'filesChecked': filesChecked,
    'findings': findings.map((f) => f.toJson()).toList(),
  };
}

class ProofChecker {
  final String projectRoot;
  final ReceiptStore? store;

  /// Files above this line count refuse a full line diff even if a
  /// snapshot somehow exists; the finding degrades to a digest report.
  static const int maxDiffLines = 2000;

  const ProofChecker({required this.projectRoot, this.store});

  /// Verifies every receipt against the current tree. When
  /// [coverageRoots] is non-empty, every file under those roots
  /// (project-relative) must be covered by a receipt, or the check fails
  /// with `unprovenanced` findings — the CI gate for generated-code
  /// paths.
  Future<ProofReport> check({List<String> coverageRoots = const []}) async {
    final effectiveStore = store ?? ReceiptStore(projectRoot: projectRoot);
    final records = await effectiveStore.loadAll();

    // Latest receipt wins per artifact path: regeneration supersedes the
    // older proof for the same file.
    final latest =
        <String, ({ReceiptRecord record, GenerationReceiptFile entry})>{};
    for (final record in records) {
      for (final entry in record.receipt.files) {
        latest[entry.path] = (record: record, entry: entry);
      }
    }

    final findings = <ProofFinding>[];

    // 1. Digest verification of every receipted artifact.
    for (final covered in latest.entries) {
      final path = covered.key;
      final record = covered.value.record;
      final entry = covered.value.entry;
      final file = File(p.join(projectRoot, path));
      if (!file.existsSync()) {
        findings.add(
          ProofFinding(
            kind: ProofFinding.kindDeleted,
            path: path,
            receipt: record.fileName,
            detail:
                'artifact reported by ${record.receipt.command} is '
                'missing; reproduce with: ${record.receipt.repro}',
          ),
        );
        continue;
      }
      final actual = _digestOf(file);
      if (actual != entry.sha256) {
        final diff = _diffFor(entry.snapshot, file);
        findings.add(
          ProofFinding(
            kind: ProofFinding.kindModified,
            path: path,
            receipt: record.fileName,
            detail:
                'digest mismatch: receipt says ${_short(entry.sha256)}, '
                'disk has ${_short(actual)} '
                '(action: ${entry.action}); reproduce with: '
                '${record.receipt.repro}',
            diff: diff,
          ),
        );
      }
    }

    // 2. Stale-spec detection for the receipts that still own artifacts.
    final owning = latest.values.map((v) => v.record.fileName).toSet();
    for (final record in records) {
      if (!owning.contains(record.fileName)) continue;
      final spec = record.receipt.spec;
      if (spec == null) continue;
      final specFile = File(p.join(projectRoot, spec.path));
      if (!specFile.existsSync()) {
        findings.add(
          ProofFinding(
            kind: ProofFinding.kindStaleSpec,
            path: spec.path,
            receipt: record.fileName,
            detail:
                'spec file consumed by ${record.receipt.command} is '
                'gone; artifacts from this run have no source of truth',
          ),
        );
        continue;
      }
      final actual = _digestOf(specFile);
      if (actual == spec.sha256) continue;
      findings.add(
        ProofFinding(
          kind: ProofFinding.kindStaleSpec,
          path: spec.path,
          receipt: record.fileName,
          detail:
              'artifact from ${record.receipt.command} was generated '
              'from spec ${_short(spec.sha256)} but the current spec is '
              '${_short(actual)}; re-run: ${record.receipt.repro}',
          diff: _diffFor(spec.snapshot, specFile),
        ),
      );
    }

    // 2.5 Repository contract manifests (spec 0973): re-derive every
    // manifest's method-table hash and re-check its interface/impl
    // digests. A hand-edited artifact or a tampered method table makes
    // the contract stale — the same green/red bar as proof receipts.
    try {
      final manifestStore = RepositoryContractManifestStore(
        projectRoot: projectRoot,
      );
      for (final manifest in await manifestStore.loadAll()) {
        final finding = manifestStore.verify(manifest);
        if (finding == null) continue;
        findings.add(
          ProofFinding(
            kind: finding.kind,
            path: manifest.interface.path.isNotEmpty
                ? manifest.interface.path
                : manifest.entity,
            receipt: RepositoryContractManifestStore.fileNameFor(
              manifest.entity,
            ),
            detail: finding.detail,
          ),
        );
      }
    } catch (_) {
      // Unreadable receipts tree — proof receipts above already handled
      // what they can; never let manifest auditing crash the check.
    }

    // 3. Unprovenanced artifacts under audited coverage roots.
    for (final root in coverageRoots) {
      findings.addAll(_unprovenancedUnder(root, latest.keys.toSet()));
    }

    // 4. Test plugin receipts (schema test.v1, spec 980): usecase/test
    //    drift + integrity of the receipted test files themselves.
    final testReceipts = await (TestReceiptStore(
      projectRoot: projectRoot,
    )).loadAll();
    var testReceiptFiles = 0;
    for (final receipt in testReceipts) {
      final receiptName = TestReceiptStore.fileNameFor(receipt.entity);
      // Latest test file state per path within this receipt.
      final testStates = <String, TestReceiptEntry>{};
      final usecaseBindings = <String, String>{};
      for (final entry in receipt.tests) {
        testStates[entry.testPath] = entry;
        if (entry.useCasePath != null && entry.useCaseSha256 != null) {
          usecaseBindings[entry.useCasePath!] = entry.useCaseSha256!;
        }
      }
      testReceiptFiles += testStates.length;

      // 4a. Integrity of the receipted test files.
      for (final state in testStates.entries) {
        final testFile = File(p.join(projectRoot, state.key));
        if (!testFile.existsSync()) {
          findings.add(
            ProofFinding(
              kind: ProofFinding.kindDeleted,
              path: state.key,
              receipt: receiptName,
              detail:
                  'receipted test is missing; regenerate with: '
                  '${receipt.command}',
            ),
          );
          continue;
        }
        final actual = _digestOf(testFile);
        if (actual != state.value.testSha256) {
          findings.add(
            ProofFinding(
              kind: ProofFinding.kindModified,
              path: state.key,
              receipt: receiptName,
              detail:
                  'digest mismatch: receipt says ${_short(state.value.testSha256)}, '
                  'disk has ${_short(actual)}; regenerate with: '
                  '${receipt.command}',
            ),
          );
        }
      }

      // 4b. Usecase/test drift: the usecase source changed after the
      //     tests were generated against it.
      for (final binding in usecaseBindings.entries) {
        final usecaseFile = File(p.join(projectRoot, binding.key));
        if (!usecaseFile.existsSync()) {
          findings.add(
            ProofFinding(
              kind: ProofFinding.kindStaleUsecase,
              path: binding.key,
              receipt: receiptName,
              detail:
                  'usecase bound to ${receipt.entity}\'s generated tests is '
                  'gone; those tests have no source of truth; regenerate '
                  'with: ${receipt.command}',
            ),
          );
          continue;
        }
        final actual = _digestOf(usecaseFile);
        if (actual == binding.value) continue;
        final affected = receipt.tests
            .where((t) => t.useCasePath == binding.key)
            .map((t) => t.testPath)
            .toSet()
            .join(', ');
        findings.add(
          ProofFinding(
            kind: ProofFinding.kindStaleUsecase,
            path: binding.key,
            receipt: receiptName,
            detail:
                'usecase/test drift: ${binding.key} changed after '
                '$affected was generated for entity ${receipt.entity} '
                '(receipt digest ${_short(binding.value)}, current '
                '${_short(actual)}); regenerate with: ${receipt.command}',
          ),
        );
      }
    }

    return ProofReport(
      ok: findings.isEmpty,
      receipts: records.length + testReceipts.length,
      filesChecked: latest.length + testReceiptFiles,
      findings: findings,
    );
  }

  Iterable<ProofFinding> _unprovenancedUnder(
    String root,
    Set<String> covered,
  ) sync* {
    final rootDir = Directory(p.join(projectRoot, root));
    if (!rootDir.existsSync()) return;
    // Keep hidden/system trees out of the audit: they are project state,
    // not generated code.
    const skipNames = {'.git', '.dart_tool', '.zfa', 'build'};
    for (final entity in rootDir.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relative = _relativePosix(entity.path);
      final segments = p.split(relative);
      if (segments.any(skipNames.contains)) continue;
      if (covered.contains(relative)) continue;
      yield ProofFinding(
        kind: ProofFinding.kindUnprovenanced,
        path: relative,
        receipt: '',
        detail: 'no receipt covers this file under audit root "$root"',
      );
    }
  }

  String? _diffFor(String? snapshot, File current) {
    if (snapshot == null) return null;
    try {
      return lineDiff(snapshot, current.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  String _relativePosix(String filePath) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }

  static String _digestOf(File file) =>
      crypto.sha256.convert(file.readAsBytesSync()).toString();

  static String _short(String digest) =>
      digest.length <= 12 ? digest : digest.substring(0, 12);
}

/// Renders a precise, bounded line diff between [before] and [after].
///
/// Lines are prefixed `  ` (context), `- ` (removed) and `+ ` (added).
/// Only changed regions — with a small context window — are emitted, so
/// the diff explains the edit instead of echoing the file.
String lineDiff(String before, String after, {int context = 2}) {
  final a = before.split('\n');
  final b = after.split('\n');

  // Too large for a meaningful diff: fall back to a summary.
  if (a.length > ProofChecker.maxDiffLines ||
      b.length > ProofChecker.maxDiffLines) {
    return 'diff unavailable: file exceeds ${ProofChecker.maxDiffLines} '
        'lines (${_deltaSummary(a.length, b.length)})';
  }

  // Trim the common prefix/suffix so the LCS only sees the changed core.
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var endA = a.length, endB = b.length;
  while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }
  final coreA = a.sublist(start, endA);
  final coreB = b.sublist(start, endB);

  if (coreA.isEmpty && coreB.isEmpty) return '';

  final coreDiff = coreA.length <= 400 && coreB.length <= 400
      ? _lcsDiff(coreA, coreB)
      : [_deltaSummary(coreA.length, coreB.length)];

  // Re-attach a context window from the untouched prefix/suffix.
  final lines = <String>[];
  for (var i = (start - context).clamp(0, start), n = start; i < n; i++) {
    lines.add('  ${a[i]}');
  }
  lines.addAll(coreDiff);
  for (var i = endB, n = (endB + context).clamp(endB, b.length); i < n; i++) {
    lines.add('  ${b[i]}');
  }

  const maxDiffOutputLines = 60;
  if (lines.length > maxDiffOutputLines) {
    return '${lines.take(maxDiffOutputLines).join('\n')}\n'
        '... (${lines.length - maxDiffOutputLines} more changed lines)';
  }
  return lines.join('\n');
}

String _deltaSummary(int removed, int added) =>
    'changed region: $removed line(s) before, $added line(s) after';

/// Classic LCS table over the changed core; sizes are bounded by 400.
List<String> _lcsDiff(List<String> a, List<String> b) {
  final n = a.length, m = b.length;
  final lcs = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }

  final out = <String>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      out.add('  ${a[i]}');
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      out.add('- ${a[i]}');
      i++;
    } else {
      out.add('+ ${b[j]}');
      j++;
    }
  }
  while (i < n) {
    out.add('- ${a[i]}');
    i++;
  }
  while (j < m) {
    out.add('+ ${b[j]}');
    j++;
  }
  return out;
}
