// Feature 1484 (FR manual exemption) — plan-level end-to-end proof.
//
// `zfa tdd plan` routes manually-declared FRs (explicit `**Type**: manual`
// marker, or the 1484 default for unbound unmarked FRs) out of the unit
// behaviour lane: no U row, a WARNING naming the FR and the two remedies
// for defaulted FRs, and a `## manual:` section in tdd/traceability.md.
// All-FR-traced specs plan byte-identically (backwards compatible — the
// marker is opt-in). `zfa tdd run` is untouched by design: it only sees
// behaviours that passed plan, and manual FRs never produce a row.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

Future<(String out, String list, String matrix)> planSpec(String body) async {
  final tmp = Directory.systemTemp.createTempSync('fr1484_');
  try {
    final featureDir = p.join(tmp.path, 'specs', '1484-e2e');
    await Directory(featureDir).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 1484-e2e

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

## Functional Requirements

$body

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the widget renders "Ready".
   **Type**: widget
''');
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'plan',
      '1484-e2e',
      '--project',
      tmp.path,
    ]);
    final list = await File(
      p.join(featureDir, 'tdd', 'test-list.md'),
    ).readAsString();
    final matrix = await File(
      p.join(featureDir, 'tdd', 'traceability.md'),
    ).readAsString();
    return (out, list, matrix);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

const _mixed = '''
- **FR-001**: The system MUST compute the total when totals are requested.
  traces: Formatter
- **FR-010**: The system MUST visually distinguish completed tasks.
  **Type**: manual
- **FR-021**: The system MUST NOT transmit task data anywhere.
''';

void main() {
  test(
    'explicit marker routes manual end-to-end (no U row, manual section)',
    () async {
      final (out, list, matrix) = await planSpec(_mixed);
      expect(exitCode, 0, reason: out);
      // FR-001 (traced) keeps its unit row:
      expect(list, contains('FR-001'));
      expect(list, contains('| U1 |'));
      // FR-010 (explicitly manual) produces no unit row:
      expect(list, isNot(contains('FR-010')));
      expect(
        list,
        isNot(contains('| U2 |')),
        reason:
            'FR-010 consumes U2 '
            'but emits no row — the next traced FR would take U3',
      );
      // The traceability matrix tracks it under the manual: section:
      expect(matrix, contains('## manual:'));
      expect(matrix, contains('manual (**Type**: manual)'));
      expect(
        matrix,
        contains('The system MUST visually distinguish completed tasks.'),
      );
      final fr2Row = matrix
          .split('\n')
          .firstWhere((l) => l.startsWith('| FR-010 '), orElse: () => '');
      expect(fr2Row, contains('manual'), reason: matrix);
    },
  );

  test(
    'defaulted FR warns naming the FR and both remedies, routes manual',
    () async {
      final (out, list, matrix) = await planSpec(_mixed);
      expect(exitCode, 0, reason: out);
      // The warning names the defaulted FR and BOTH remedies:
      expect(out, contains('WARNING'));
      expect(out, contains('FR-021'));
      expect(out, contains('traces:'), reason: 'remedy (a): a contract trace');
      expect(
        out,
        contains('**Type**: manual'),
        reason:
            'remedy (b): declare '
            'the exemption',
      );
      // It routes manual — no unit row:
      expect(list, isNot(contains('FR-021')));
      // The defaulted FR is tagged defaulted in the matrix:
      expect(matrix, contains('manual (defaulted'));
    },
  );

  test('explicitly-marked FRs warn nothing', () async {
    final (out, _, _) = await planSpec(_mixed);
    expect(
      out,
      isNot(contains('FR-010 derives no unit behaviour')),
      reason:
          'the author already declared the exemption — no warning: '
          '$out',
    );
  });

  test(
    'all-FR-traced specs plan byte-identically (backwards compat)',
    () async {
      const traced = '''
- **FR-001**: The system MUST compute the total when totals are requested.
  traces: Formatter
- **FR-002**: The system MUST normalize the template before formatting.
  traces: Formatter
''';
      final (out, list, matrix) = await planSpec(traced);
      expect(exitCode, 0, reason: out);
      expect(list, contains('| U1 |'));
      expect(list, contains('| U2 |'));
      expect(list, contains('FR-001'));
      expect(list, contains('FR-002'));
      // No default-to-manual warnings on an all-traced spec:
      expect(out, isNot(contains('derives no unit behaviour')));
      // No manual section for a spec with no manual FRs:
      expect(matrix, isNot(contains('## manual:')));
      expect(matrix, contains('fr-manual: 0'));
    },
  );

  test('traceability machine block counts the manual declarations', () async {
    final (_, list, matrix) = await planSpec(_mixed);
    // statements: FR-001, FR-010, FR-021, AC-1 = 4; manual: 2; the two
    // automated rows are U1 (FR-001) and A1 (AC-1).
    expect(matrix, contains('fr-manual: 2'));
    expect(matrix, contains('manual: 2'));
    expect(matrix, contains('automated: 2'));
    expect(matrix, contains('open-gaps: 0'));
    // The test list the run loop consumes has no manual rows at all:
    expect(list, isNot(contains('FR-010')));
    expect(list, isNot(contains('FR-021')));
  });
}
