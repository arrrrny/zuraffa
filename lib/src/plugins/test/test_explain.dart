import '../../models/generated_file.dart';
import 'test_certifier.dart';

/// Spec 1129 — the `--explain` human-readable block for
/// `zfa test create <Entity>`.
///
/// `--explain` is the human twin of `--json` (the issue #1125 convention
/// on the tdd verbs, issue #1122 on the route surface): `--json` is the
/// machine-readable certification envelope, `--explain` is the human
/// prose, and both may be passed together — the envelope line comes
/// first, then this block.
///
/// The block describes exactly what the orders demand:
///
///   * `generated files:` — which test files were generated (path,
///     action, kind, per-file trust tier);
///   * `test kinds:` — which test kinds (unit/integration/widget) were
///     produced, honestly counted per produced file;
///   * `self-certification:` — the self-certification result per file
///     plus the machine verdict line;
///   * `trust tier:` — the trust tier of the generated artifacts (the
///     block-level floor over the files this run wrote) with a legend;
///   * `summary:` — a one-paragraph narrative.
///
/// The builder is a PURE function of the generation result: no I/O, no
/// clock, no store reads — it cannot drift from what generation actually
/// did. Trust tiers are read-only derivations from the certification
/// evidence (an error attributed by file path), so the self-certification
/// gate itself is untouched (FR-005).

/// The per-file trust tiers (spec 1129 / FR-006).
const String kTierCertified = 'certified';
const String kTierFailed = 'failed';
const String kTierUnverified = 'unverified';
const String kTierPreExisting = 'pre-existing';

/// The `--explain` flag's help text (the kExplainFlagHelp pattern of the
/// tdd verbs, adjusted for the test create surface).
const String kTestExplainFlagHelp =
    'After the regular output, print a human-readable explanation of what '
    'this run did: which test files were generated, which test kinds '
    '(unit/integration/widget) were produced, the self-certification '
    'result per file, and the trust tier of the generated artifacts '
    '(spec 1129). The human twin of --json: both flags may be passed '
    'together — the JSON envelope comes first, then the explain block.';

/// POSIX-normalizes a path for display.
String _display(String path) => path.replaceAll('\\', '/');

/// True when [errorPath] names the same file as [filePath]. The
/// certifier's scoped analyzer echoes the path it was handed, so exact
/// (separator-normalized) equality is the contract; a lenient suffix
/// match guards against absolute/relative spelling drift.
bool _sameFile(String errorPath, String filePath) {
  final e = _display(errorPath);
  final f = _display(filePath);
  return e == f || e.endsWith('/$f') || f.endsWith('/$e');
}

/// Derives the trust tier of one produced file from the run's
/// certification evidence (read-only — the gate is untouched):
///
///   * `pre-existing` — the file was skipped (already on disk, untouched
///     by this run);
///   * `unverified` — no certification evidence exists (dry run, revert,
///     or nothing was certified);
///   * `failed` — the certification attributed a compile error to the
///     file;
///   * `certified` — the file was written and analyzed clean.
String testTrustTier(GeneratedFile file, TestCertification? certification) {
  if (file.action == 'skipped') return kTierPreExisting;
  if (certification == null) return kTierUnverified;
  final attributed = certification.errors.any(
    (error) => _sameFile(error.file, file.path),
  );
  return attributed ? kTierFailed : kTierCertified;
}

/// Classifies the test kind of one produced file across the
/// unit/integration/widget lanes. The test plugin emits pure-Dart usecase
/// unit tests (`package:test`), so production output classifies as
/// `unit`; the widget/integration lanes are recognized honestly from the
/// artifact itself should a future builder emit them.
String testKindOf(GeneratedFile file) {
  final content = file.content ?? '';
  final displayPath = _display(file.path);
  if (displayPath.contains('integration_test/') ||
      content.contains('package:integration_test/')) {
    return 'integration';
  }
  if (content.contains('flutter_test') && content.contains('testWidgets(')) {
    return 'widget';
  }
  return 'unit';
}

/// The block-level trust tier: the honest FLOOR over the files this run
/// actually wrote. `pre-existing` never lowers it (this run made no
/// claim about those bytes); a single `failed` file fails the block; a
/// written-but-unverified file caps the block at `unverified`. With no
/// written files there is no evidence either way — `unverified`.
String blockTrustTier(List<GeneratedFile> files, TestCertification? cert) {
  var failed = false;
  var unverified = false;
  var wrote = false;
  for (final file in files) {
    if (file.action == 'skipped') continue;
    wrote = true;
    final tier = testTrustTier(file, cert);
    if (tier == kTierFailed) failed = true;
    if (tier == kTierUnverified) unverified = true;
  }
  if (failed) return kTierFailed;
  if (!wrote || unverified) return kTierUnverified;
  return kTierCertified;
}

/// Builds the explain block (FR-002). Pure: same inputs, same bytes —
/// the CLI output and `ExecutionResult.data['explain']` share it by
/// construction.
String buildTestExplain({
  required String entity,
  required List<GeneratedFile> files,
  required TestCertification? certification,
}) {
  final written = files
      .where((f) => f.action != 'skipped')
      .toList(growable: false);
  final skipped = files
      .where((f) => f.action == 'skipped')
      .toList(growable: false);

  // Per-file lines: path (action) kind=… tier=…
  final fileLines = <String>[];
  var unit = 0;
  var integration = 0;
  var widget = 0;
  for (final file in files) {
    final kind = testKindOf(file);
    final tier = testTrustTier(file, certification);
    // Only files this run produced count toward the produced kinds.
    if (file.action != 'skipped') {
      switch (kind) {
        case 'integration':
          integration++;
        case 'widget':
          widget++;
        default:
          unit++;
      }
    }
    fileLines.add(
      '  - ${_display(file.path)} (${file.action}) kind=$kind tier=$tier',
    );
  }

  // Self-certification: per-file result + the machine verdict line.
  final certLines = <String>[];
  if (certification == null) {
    certLines.add('  - none — nothing was written to certify');
    certLines.add('  verdict: none');
  } else {
    for (final file in written) {
      final attributed = certification.errors.where(
        (error) => _sameFile(error.file, file.path),
      );
      if (attributed.isEmpty) {
        certLines.add('  - ${_display(file.path)}: pass');
      } else {
        certLines.add(
          '  - ${_display(file.path)}: FAIL — ${attributed.first.message}',
        );
      }
    }
    certLines.add('  verdict: ${certification.verdictLine}');
  }

  final tier = blockTrustTier(files, certification);
  const legend =
      '  legend: certified=written + scoped dart analyze clean; '
      'failed=written with compile errors; unverified=written without '
      'certification evidence; pre-existing=already on disk, untouched';

  final summary = StringBuffer()
    ..write('Generated ${written.length} test file(s) for $entity')
    ..write(
      written.isEmpty
          ? ' (nothing written this run'
          : ' ($unit unit, $integration integration, $widget widget',
    )
    ..write('); ');
  if (skipped.isNotEmpty) {
    summary.write('${skipped.length} pre-existing file(s) skipped; ');
  }
  summary.write('block trust tier: $tier.');

  final buf = StringBuffer()
    ..writeln('--- explain: test create ---')
    ..writeln('generated files:');
  if (fileLines.isEmpty) {
    buf.writeln('  none');
  } else {
    for (final line in fileLines) {
      buf.writeln(line);
    }
  }
  buf
    ..writeln(
      'test kinds: unit=$unit, integration=$integration, '
      'widget=$widget',
    )
    ..writeln('self-certification:');
  for (final line in certLines) {
    buf.writeln(line);
  }
  buf
    ..writeln('trust tier: $tier')
    ..writeln(legend)
    ..writeln('summary: ${summary.toString().trim()}');
  return buf.toString().trimRight();
}
