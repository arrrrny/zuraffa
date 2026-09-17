import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../plugins/repository/contract/repository_contract_manifest.dart';
import '../../simulation/worlds/world_manifest.dart';
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

  /// Spec 1136 lane 5 — a world-run receipt whose recorded `world_hash`
  /// no longer matches the committed world manifest (or whose manifest
  /// is gone): the recorded green is no longer attributable to any
  /// committed world version.
  static const kindWorldDrift = 'world_drift';

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

  /// Spec 1136 lane 5 — how many receipts of each kind were verified
  /// (`world`, `spec-fuzz`, `entity`, `make`, `tdd`, `route`,
  /// `usecase`, ...): the epic's "validates every receipt" surface,
  /// broken down. Null when no receipts were found.
  final Map<String, int>? receiptKinds;

  const ProofReport({
    required this.ok,
    required this.receipts,
    required this.filesChecked,
    required this.findings,
    this.receiptKinds,
  });

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'ok': ok,
    // Issue #996: the machine verdict also speaks `valid` — agents and
    // CI read one field for both proof families (make + capability).
    'valid': ok,
    'receipts': receipts,
    'filesChecked': filesChecked,
    if (receiptKinds != null) 'kinds': receiptKinds,
    'findings': findings.map((f) => f.toJson()).toList(),
  };
}

class ProofChecker {
  final String projectRoot;
  final ReceiptStore? store;

  /// Files above this line count refuse a full line diff even if a
  /// snapshot somehow exists; the finding degrades to a digest report.
  static const int maxDiffLines = 2000;

  /// Append-only logs (issue #1327): the run driver, prove, refactor and
  /// the journal append evidence to these AFTER the verb receipts that
  /// cover them were written — a digest mismatch against those receipts
  /// is the sanctioned append class, not hand-drift. When the receipt
  /// carries a snapshot of the log at receipt time and the current disk
  /// bytes still start with exactly those bytes (nothing before or
  /// inside the receipted region changed), the check passes. A snapshot
  /// is required: without the receipted bytes there is nothing to pin
  /// the prefix against, so legacy snapshot-less receipts still drift.
  static const Set<String> appendOnlyBasenames = {'cycle-log.md'};

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
        // Issue #1429: a receipted REMOVAL is the expected-absence
        // contract. The tombstone `zfa entity remove` writes records the
        // deletion intent with `action: 'delete'`, so a missing artifact
        // whose LATEST receipt entry is a deletion is provenance, not
        // drift — the `deleted` finding must not fire (it was permanent:
        // no verb could retire a mis-declared entity's receipt without
        // hand-editing the store). Recreating the artifact still lands in
        // the digest check below — a tombstone does not hide new bytes.
        if (entry.action == 'delete') continue;
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
      final actualBytes = file.readAsBytesSync();
      final actual = crypto.sha256.convert(actualBytes).toString();
      if (actual != entry.sha256) {
        if (_isSanctionedAppend(path, entry, actualBytes)) continue;
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

    // 2.6 World-run receipts (spec 1136 lane 5): re-derive every
    // world-run receipt's recorded `world_hash` from the committed
    // world manifest it names. A mutated (or missing) manifest means
    // the recorded green is no longer attributable to any committed
    // world version — drift detected as receipt mismatch.
    for (final record in records) {
      if (!record.fileName.startsWith('world-run-')) continue;
      final worldHash = record.raw['world_hash'] as String?;
      final scenario = record.raw['scenario'] as String?;
      final feature = record.raw['feature'] as String?;
      if (worldHash == null || scenario == null || feature == null) {
        continue;
      }
      final manifestPath = p.join(
        'specs',
        feature,
        'tdd',
        'worlds',
        '$scenario.world.json',
      );
      final manifestFile = File(p.join(projectRoot, manifestPath));
      final String current;
      if (!manifestFile.existsSync()) {
        findings.add(
          ProofFinding(
            kind: ProofFinding.kindWorldDrift,
            path: manifestPath,
            receipt: record.fileName,
            detail:
                'world manifest for the recorded green run is gone — '
                'the run (world hash ${_short(worldHash)}) is no longer '
                'attributable to any committed world version; restore '
                'the manifest or re-run `zfa simulate run $scenario '
                '--feature $feature`',
          ),
        );
        continue;
      }
      try {
        current = WorldManifest.parse(
          manifestFile.readAsBytesSync(),
        ).worldHash;
      } catch (_) {
        findings.add(
          ProofFinding(
            kind: ProofFinding.kindWorldDrift,
            path: manifestPath,
            receipt: record.fileName,
            detail:
                'world manifest is unreadable — the recorded green run '
                '(world hash ${_short(worldHash)}) cannot be '
                're-derived; repair the manifest or re-run `zfa '
                'simulate run $scenario --feature $feature`',
          ),
        );
        continue;
      }
      if (current != worldHash) {
        findings.add(
          ProofFinding(
            kind: ProofFinding.kindWorldDrift,
            path: manifestPath,
            receipt: record.fileName,
            detail:
                'world drift: receipt says world-hash ${_short(worldHash)} '
                'but the committed manifest hashes to ${_short(current)} '
                '— the green run was recorded against a different world; '
                're-run `zfa simulate run $scenario --feature $feature` '
                'against the current world',
          ),
        );
      }
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
      receiptKinds: records.isEmpty && testReceipts.isEmpty
          ? null
          : _receiptKinds(records),
    );
  }

  /// Spec 1136 lane 5 — the receipt-kind breakdown: how many receipts
  /// of each kind the check verified. Named receipts classify by their
  /// stable prefix; timestamped ones by their command verb.
  static Map<String, int> _receiptKinds(List<ReceiptRecord> records) {
    final kinds = <String, int>{};
    for (final record in records) {
      final name = record.fileName;
      final command = record.receipt.command;
      final String kind;
      if (name.startsWith('world-run-')) {
        kind = 'world';
      } else if (name.startsWith('spec-fuzz-')) {
        kind = 'spec-fuzz';
      } else if (name.startsWith('routes-')) {
        kind = 'route';
      } else if (name.startsWith('mcp-replay-')) {
        kind = 'mcp-replay';
      } else if (name.startsWith('mock-')) {
        kind = 'mock';
      } else if (name.startsWith('state-')) {
        kind = 'state';
      } else if (name.startsWith('provider-')) {
        kind = 'provider';
      } else if (name.startsWith('datasource-')) {
        kind = 'datasource';
      } else if (name.startsWith('usecase-')) {
        kind = 'usecase';
      } else if (command.startsWith('entity')) {
        kind = 'entity';
      } else if (command.startsWith('tdd')) {
        kind = 'tdd';
      } else if (command.startsWith('make')) {
        kind = 'make';
      } else if (command.startsWith('spec')) {
        kind = 'spec';
      } else {
        kind = 'other';
      }
      kinds[kind] = (kinds[kind] ?? 0) + 1;
    }
    return kinds;
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

  /// Whether the drift on [path] is the sanctioned append class
  /// (issue #1327): an append-only log whose receipt carries a snapshot
  /// and whose disk bytes are exactly [snapshotBytes] followed by more
  /// bytes. Anything that touches the receipted region — an edit, a
  /// reformat, a truncation, a different leading byte — is still drift.
  bool _isSanctionedAppend(
    String path,
    GenerationReceiptFile entry,
    List<int> actualBytes,
  ) {
    final snapshot = entry.snapshot;
    if (snapshot == null) return false;
    if (!appendOnlyBasenames.contains(p.basename(path))) return false;
    final receiptedBytes = const Utf8Encoder().convert(snapshot);
    if (actualBytes.length < receiptedBytes.length) return false;
    for (var i = 0; i < receiptedBytes.length; i++) {
      if (actualBytes[i] != receiptedBytes[i]) return false;
    }
    return true;
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
