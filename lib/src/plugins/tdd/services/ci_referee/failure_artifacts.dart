/// Failure artifacts (spec 070 US4): concise cycle-log excerpts with the
/// failing test name, failing line, and a suggested fix direction
/// (FR-006); grouped by feature with a summary count at the top
/// (FR-007); truncated with a link to the full report when the rendered
/// comment exceeds the platform limit (FR-011). Never a full log dump:
/// the excerpt is ≤20 lines and the whole artifact <50 lines per
/// failure (SC-004).
///
/// The excerpts are extracted from the existing cycle-log infrastructure
/// (red entries' `output:` blocks), formatted for brevity — not
/// regenerated (spec assumption).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The maximum excerpt length (US4.AC1: "max 20 lines").
const int maxExcerptLines = 20;

class FailureArtifact {
  const FailureArtifact({
    required this.feature,
    required this.testName,
    required this.excerpt,
    required this.failingLine,
    required this.fixDirection,
  });

  final String feature;
  final String testName;
  final String excerpt;
  final String? failingLine;
  final String fixDirection;

  /// The artifact's line count (SC-004: <50 per failure).
  int get lineCount =>
      excerpt.split('\n').where((l) => l.trim().isNotEmpty).length + 4;
}

class FailureArtifactBuilder {
  FailureArtifactBuilder(this.projectRoot);

  final String projectRoot;

  /// Build one artifact per red cycle-log entry across all features.
  /// Red entries are the failures by contract (046): a red entry's
  /// `output:` block is the captured runner output the excerpt is cut
  /// from.
  Future<List<FailureArtifact>> build() async {
    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (!await specsDir.exists()) return const [];

    final artifacts = <FailureArtifact>[];
    final featureDirs =
        specsDir.listSync().whereType<Directory>().map((d) => d.path).toList()
          ..sort();
    for (final dir in featureDirs) {
      final cycleLog = File(p.join(dir, 'tdd', 'cycle-log.md'));
      if (!await cycleLog.exists()) continue;
      final feature = p.basename(dir);
      artifacts.addAll(await _parseRedEntries(feature, cycleLog));
    }
    artifacts.sort((a, b) => a.feature.compareTo(b.feature));
    return artifacts;
  }

  /// Parse the red entries of one feature's cycle log. Each red entry
  /// contributes exactly one artifact (its output block trimmed to the
  /// excerpt).
  Future<List<FailureArtifact>> _parseRedEntries(
    String feature,
    File cycleLog,
  ) async {
    final lines = (await cycleLog.readAsString()).split('\n');
    final artifacts = <FailureArtifact>[];

    String? currentTest;
    var inRed = false;
    var inOutput = false;
    final output = <String>[];

    void closeEntry() {
      if (currentTest == null) return;
      final trimmed = output
          .map((l) => l.trimRight())
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (trimmed.isNotEmpty) {
        final failingLine = _findFailingLine(trimmed);
        artifacts.add(
          FailureArtifact(
            feature: feature,
            testName: currentTest!,
            excerpt: _excerptAround(trimmed, failingLine),
            failingLine: failingLine,
            fixDirection: _fixDirectionFor(trimmed, failingLine),
          ),
        );
      }
      currentTest = null;
      inRed = false;
      inOutput = false;
      output.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('## Cycle:')) {
        closeEntry();
        inRed = trimmed.endsWith('(red)');
        continue;
      }
      if (inRed && trimmed.startsWith('- test:')) {
        currentTest = trimmed.substring('- test:'.length).trim();
        continue;
      }
      if (inRed && trimmed == '```') {
        inOutput = !inOutput;
        continue;
      }
      if (inRed && inOutput) {
        output.add(line);
      }
    }
    closeEntry();
    return artifacts;
  }

  /// The most failure-looking line: the location frame first (file:line),
  /// then the assertion delta, then error shapes.
  static String? _findFailingLine(List<String> output) {
    final patterns = [
      RegExp(r'\.dart:\d+'),
      RegExp(r'^Expected(:|>)'),
      RegExp(r'^  Actual(:|>)'),
      RegExp(r'^(EXCEPTION|Error|error)'),
    ];
    for (final pattern in patterns) {
      for (final line in output) {
        if (pattern.hasMatch(line)) return line.trim();
      }
    }
    return output.isEmpty ? null : output.last.trim();
  }

  /// Cut the excerpt around the failing line: up to [maxExcerptLines]
  /// lines, centered on the failure, keeping the meaningful context.
  static String _excerptAround(List<String> output, String? failingLine) {
    final index = failingLine == null
        ? output.length - 1
        : output.indexWhere((l) => l.trim() == failingLine);
    final anchor = index < 0 ? output.length - 1 : index;
    // Keep the failing line and the lines after it (the delta + frame
    // usually follow), falling back to preceding context when short.
    final start = (anchor - 5).clamp(0, output.length - 1);
    final end = (anchor + maxExcerptLines - 5).clamp(0, output.length);
    final cut = output.sublist(start, end);
    if (cut.length > maxExcerptLines) cut.length = maxExcerptLines;
    return cut.join('\n');
  }

  /// A suggested fix direction derived from the failure shape (FR-006:
  /// direction, not a patch).
  static String _fixDirectionFor(List<String> output, String? failingLine) {
    final joined = output.join('\n');
    if (RegExp(r'^Expected(:|>)', multiLine: true).hasMatch(joined)) {
      return 'Assertion delta — reconcile the expected value with the '
          'behavior\'s contract; check the subject\'s latest hand-delta.';
    }
    if (joined.contains('EXCEPTION') || joined.contains('Error')) {
      return 'Unexpected exception — inspect the failing frame\'s subject '
          'call path; likely a null or contract mismatch at the boundary.';
    }
    if (joined.contains('Failed to load') || joined.contains('compile')) {
      return 'Load/compile failure — fix the import or syntax error in '
          'the failing file before re-running the behavior.';
    }
    return failingLine == null
        ? 'Inspect the red entry\'s output block for the failure shape.'
        : 'Inspect the failing line and align the behavior with its '
              'spec criterion.';
  }
}

class FailureReportRenderer {
  const FailureReportRenderer({this.maxCommentChars = 60000});

  final int maxCommentChars;

  /// Render the full grouped report (FR-007): summary count first, then
  /// one `### <feature>` group per feature with its artifacts — one
  /// excerpt per failure, never a concatenated wall.
  static List<String> render(List<FailureArtifact> failures) {
    if (failures.isEmpty) return const [];

    final byFeature = <String, List<FailureArtifact>>{};
    for (final failure in failures) {
      byFeature.putIfAbsent(failure.feature, () => []).add(failure);
    }
    final orderedFeatures = byFeature.keys.toList()..sort();

    final lines = <String>[
      '## CI Referee Failure Report',
      '',
      '${failures.length} failure(s) across '
          '${orderedFeatures.length} feature(s):',
      '',
    ];
    for (final feature in orderedFeatures) {
      lines.add('### $feature (${byFeature[feature]!.length})');
      lines.add('');
      for (final failure in byFeature[feature]!) {
        lines.add('- **${failure.testName}**');
        if (failure.failingLine != null) {
          lines.add('  - failing line: `${failure.failingLine}`');
        }
        lines.add('  - fix direction: ${failure.fixDirection}');
        lines.add('  - cycle-log excerpt:');
        for (final excerptLine in failure.excerpt.split('\n')) {
          lines.add('        $excerptLine');
        }
        lines.add('');
      }
    }
    return lines;
  }

  /// Render under [maxCommentChars], truncating gracefully with a link
  /// to the full report written next to it (FR-011). Returns the
  /// rendered lines, whether truncation happened, and the full report
  /// path (null when nothing needed truncating).
  ///
  /// Truncation degrades progressively — excerpt bodies first, then
  /// fix-direction and failing-line details — but the failing feature
  /// list is ALWAYS rendered: a failure is never silently dropped.
  (List<String>, bool, String?) renderLimited(
    List<FailureArtifact> failures, {
    String? projectRoot,
  }) {
    final full = render(failures);
    if (failures.isEmpty) return (full, false, null);

    final fullText = full.join('\n');
    if (fullText.length <= maxCommentChars) {
      return (full, false, null);
    }

    // The full report is persisted before truncation — the failures are
    // never silently dropped (FR-011).
    final reportDir = p.join(
      projectRoot ?? Directory.current.path,
      '.zfa',
      'corpus',
    );
    final fullReportPath = p.join(reportDir, 'failure-report.md');
    File(fullReportPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(fullText);

    // The compact, budget-respecting comment: summary + the failing
    // feature list (always complete) + per-failure details added
    // greedily while the budget allows.
    final notice =
        '*(truncated — see the full failure report at $fullReportPath)*';
    final byFeature = <String, List<FailureArtifact>>{};
    for (final failure in failures) {
      byFeature.putIfAbsent(failure.feature, () => []).add(failure);
    }
    final orderedFeatures = byFeature.keys.toList()..sort();

    final head = <String>[
      '## CI Referee Failure Report',
      '',
      '${failures.length} failure(s) across '
          '${orderedFeatures.length} feature(s).',
      '',
      'Failing features: ${orderedFeatures.join(", ")}',
      '',
    ];
    final headText = head.join('\n');
    final noticeBlock = '\n\n$notice';
    final detailBudget = maxCommentChars - headText.length - noticeBlock.length;

    final details = <String>[];
    var used = 0;
    for (final failure in failures) {
      final lines = <String>[
        '- ${failure.feature} — ${failure.testName}',
        if (failure.failingLine != null) '  failing: `${failure.failingLine}`',
        '  fix: ${failure.fixDirection}',
      ];
      final cost = lines.join('\n').length + 1;
      if (used + cost > detailBudget) break;
      details.addAll(lines);
      used += cost;
    }

    final compact = [...head, ...details];
    if (details.length < failures.length * 3) {
      compact
        ..add('')
        ..add(
          '${failures.length - details.where((l) => l.startsWith('- ')).length} '
          'more failure(s) in the full report.',
        );
    }
    compact
      ..add('')
      ..add(notice);
    return (compact, true, fullReportPath);
  }
}
