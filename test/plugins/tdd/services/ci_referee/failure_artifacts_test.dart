// US4 (spec 070): failure artifacts — concise cycle-log excerpts with the
// failing test name, failing line, and a suggested fix direction (FR-006),
// grouped by feature with a summary count (FR-007), truncated with a link
// to the full report when over the comment limit (FR-011). Never log
// walls: <50 lines per failure (SC-004), excerpt ≤20 lines (US4.AC1).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/failure_artifacts.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('failures_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> writeCycleLog(
    String feature, {
    required String testName,
    required List<String> outputLines,
  }) async {
    final buf = StringBuffer('# Cycle Log\n');
    buf
      ..writeln('## Cycle: B-001 (red)')
      ..writeln()
      ..writeln('- behavior: B-001')
      ..writeln('- kind: red')
      ..writeln('- classification: assertion_failure')
      ..writeln('- test: test/${feature}_test.dart')
      ..writeln('- command: `dart test test/${feature}_test.dart`')
      ..writeln('- exit: 1')
      ..writeln('- at: 2026-09-03T00:00:00Z')
      ..writeln('- output:')
      ..writeln('```');
    for (final line in outputLines) {
      buf.writeln(line);
    }
    buf
      ..writeln('```')
      ..writeln();
    final file = File(
      p.join(root.path, 'specs', feature, 'tdd', 'cycle-log.md'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(buf.toString());
  }

  test('A11: a failing test produces an artifact with name, ≤20-line excerpt, '
      'failing line, and a suggested fix direction', () async {
    final longOutput = [
      'Loading test file...',
      'Running suite...',
      'line 1 filler',
      'line 2 filler',
      'line 3 filler',
      'Expected: <42>',
      '  Actual: <13>',
      'package:test failing at test/cart_test.dart:18',
      'line 9 filler',
    ];
    await writeCycleLog(
      'f-cart',
      testName: 'cart total',
      outputLines: [
        ...longOutput,
        // A wall of filler that MUST be trimmed to an excerpt.
        ...List.generate(60, (i) => 'filler line $i'),
      ],
    );

    final failures = await FailureArtifactBuilder(root.path).build();
    expect(failures, hasLength(1));
    final artifact = failures.first;
    expect(artifact.feature, 'f-cart');
    expect(artifact.testName, contains('f-cart'));
    expect(
      artifact.excerpt.split('\n').where((l) => l.isNotEmpty).length,
      lessThanOrEqualTo(20),
      reason: 'US4.AC1: excerpt is max 20 lines',
    );
    expect(
      artifact.excerpt,
      contains('Expected: <42>'),
      reason: 'the meaningful failure lines survive',
    );
    expect(artifact.failingLine, isNotNull);
    expect(artifact.failingLine, contains('cart_test.dart'));
    expect(artifact.fixDirection, isNotEmpty);
    expect(artifact.lineCount, lessThan(50), reason: 'SC-004');
  });

  test('A12: multiple failures group by feature with a summary count at the '
      'top, one excerpt per failure', () async {
    await writeCycleLog(
      'f-alpha',
      testName: 'alpha',
      outputLines: ['Expected: <1>', '  Actual: <2>'],
    );
    await writeCycleLog(
      'f-beta',
      testName: 'beta',
      outputLines: ['Expected: <3>', '  Actual: <4>'],
    );

    final failures = await FailureArtifactBuilder(root.path).build();
    final report = FailureReportRenderer.render(failures);

    expect(failures.map((f) => f.feature).toSet(), {'f-alpha', 'f-beta'});
    // Summary count at the top.
    expect(
      report.firstWhere((l) => l.contains('2')),
      contains('failure'),
      reason: 'the summary count leads the report',
    );
    // One group per feature (grouped, never a concatenated wall).
    expect(report.where((l) => l.contains('### f-alpha')), hasLength(1));
    expect(report.where((l) => l.contains('### f-beta')), hasLength(1));
    // No blank-wall: total rendered lines stay bounded.
    expect(report.length, lessThan(50));
  });

  test('A13: an over-limit report truncates gracefully and links to the full '
      'report, never silently dropping a failure', () async {
    // Ten features, each with a failing red entry.
    for (var i = 0; i < 10; i++) {
      await writeCycleLog(
        'f-feature-$i',
        testName: 'feature $i',
        outputLines: [
          'Expected: <$i>',
          '  Actual: <${i + 1}>',
          'failed at test/f${i}_test.dart:1$i',
        ],
      );
    }

    final failures = await FailureArtifactBuilder(root.path).build();
    final renderer = FailureReportRenderer(maxCommentChars: 400);
    final (rendered, truncated, fullReportPath) = renderer.renderLimited(
      failures,
      projectRoot: root.path,
    );

    final renderedText = rendered.join('\n');
    expect(truncated, isTrue);
    expect(
      renderedText.length,
      lessThanOrEqualTo(400),
      reason: 'the rendered comment respects the limit',
    );
    expect(
      renderedText,
      contains('full failure report'),
      reason: 'the truncation notice links onward',
    );
    expect(
      fullReportPath,
      isNotNull,
      reason: 'the full report is written to disk, nothing dropped',
    );
    // The full report still carries EVERY failure.
    final full = await File(fullReportPath!).readAsLines();
    for (var i = 0; i < 10; i++) {
      expect(
        full.any((l) => l.contains('f-feature-$i')),
        isTrue,
        reason: 'failure $i must not be silently dropped',
      );
    }
    // And the rendered comment names every feature too.
    for (var i = 0; i < 10; i++) {
      expect(renderedText.contains('f-feature-$i'), isTrue);
    }
  });
}
