@Tags(['slow'])
// Issue #1975 — `zfa tdd gen --all` stops the WHOLE batch at the first
// refusing row, even when that row belongs to a different, already-shipped
// feature, and the stop's fix line prescribes a destructive
// `zfa tdd reset <other-feature>` — a remedy for a feature the caller may
// not even be repairing.
//
// The refusal itself is correct and intended (issue #1388 — the subject
// progressed past the stub stage, so gen never clobbers real work). The
// defect is the blast radius: an unscoped `--all` batch scans every
// feature, so ONE refusal in an unrelated shipped feature starves the
// pending pairs of the feature under repair (`created=0`).
//
// Fix under test:
//   U1 — a refusal is scoped to the FEATURE that owns the refused row: the
//        batch skips that feature's remaining rows and keeps driving the
//        other features, so the in-flight feature's pending pair is still
//        generated.
//   U2 — in an UNSCOPED batch the refusing row's fix line names the
//        scoping lever `--feature <feature>` and never prescribes
//        `zfa tdd reset` on the unrelated feature.
//   U3 — a SCOPED batch (`--all --feature <shipped>`) still stops at the
//        refusal and keeps the `zfa tdd reset <feature>` remedy — there the
//        refusing feature IS the feature under repair.
//   U4 — the skip is ASSERTED: the refusing feature's remaining row is
//        not generated, while the identical row of the OTHER feature is.
//   U5 — the JSON envelope accounts for EVERY target: the refused row,
//        the skipped rows, and no `stopped_at` (the batch drove past the
//        refusal).
//   U6 — a HARD failure (an FR-008 ownership conflict on an unowned
//        file) still stops the WHOLE batch — the refusal scoping never
//        starves a hard stop.
//
// The fixture mirrors the issue's shape: two features in one project —
// `001-purchase-store` (shipped: its pair exists, its subject progressed,
// its declared routing changed) and `002-subscription-error-vocabulary`
// (in flight: planned, never generated).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The planned shape of a feature's spec — one unit-fallback behavior
/// (`U1`) whose traces cell resolves to no declared signature (the
/// guard-only pair the #1388 fingerprint gate arms on).
const shippedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: purchase-store

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: FR-001

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// The declared-routing change the shipped feature's spec took AFTER its
/// pair was generated: FR-001 now traces to the declared single-method
/// row, so the pair's reuse fingerprint drifts.
const shippedMigratedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: purchase-store

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: RouteContentType

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// The in-flight feature's spec — the same shape, its own feature dir.
const inflightSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: subscription-error-vocabulary

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: FR-001

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

const shippedFeature = '001-purchase-store';
const inflightFeature = '002-subscription-error-vocabulary';

void main() {
  late TddFixture fx;
  final runner = CliRunner(exitOnCompletion: false);

  setUp(() async {
    fx = await TddFixture.create(featureName: shippedFeature);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  /// Plan the shipped feature, generate its pair, progress its subject
  /// (the real implementation landed — never clobbered) and change its
  /// declared routing. The next gen of that row REFUSES the reuse
  /// (issue #1388) — the shape the issue's batch hit.
  Future<void> seedRefusingShippedFeature() async {
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString(shippedSpec);
    await runner.runCapturing([
      'tdd',
      'plan',
      shippedFeature,
      '--allow-unit-fallback',
      '--project',
      fx.root.path,
    ]);
    await runner.runCapturing(['tdd', 'gen', 'U1', '--project', fx.root.path]);

    // The subject progressed past the stub stage (real implementation).
    final subjectFile = File(
      p.join(fx.root.path, 'lib', 'tdd', shippedFeature, 'u1_subject.dart'),
    );
    final progressed = (await subjectFile.readAsString())
        .replaceFirst(
          RegExp(r'=> throw UnimplementedError\([^;]*\);'),
          "=> 'text/event-stream';",
        )
        .replaceFirst(
          '/// Throws [UnimplementedError] until the real implementation '
              "lands.\n",
          '',
        );
    expect(
      progressed.contains('UnimplementedError'),
      isFalse,
      reason: 'the progressed subject must not mention the stub error',
    );
    await subjectFile.writeAsString(progressed);

    // The declared routing changed since the pair was generated.
    await File(
      p.join(fx.featureDir, 'spec.md'),
    ).writeAsString(shippedMigratedSpec);
    await runner.runCapturing([
      'tdd',
      'plan',
      shippedFeature,
      '--allow-unit-fallback',
      '--project',
      fx.root.path,
    ]);
  }

  /// Plan the in-flight feature (its row is pending — never generated).
  Future<void> seedInflightFeature() async {
    final dir = p.join(fx.root.path, 'specs', inflightFeature);
    await Directory(dir).create(recursive: true);
    await File(p.join(dir, 'spec.md')).writeAsString(inflightSpec);
    await runner.runCapturing([
      'tdd',
      'plan',
      inflightFeature,
      '--allow-unit-fallback',
      '--project',
      fx.root.path,
    ]);
  }

  /// The batch verdict envelope — the FINAL stdout line under `--json`.
  Map<String, dynamic> batchEnvelope(String out) {
    final last = out.trimRight().split('\n').last;
    final decoded = jsonDecode(last);
    expect(
      decoded,
      isA<Map<String, dynamic>>(),
      reason: 'the FINAL stdout line must be the batch envelope:\n$out',
    );
    return decoded as Map<String, dynamic>;
  }

  test('U1: a refusal in the shipped feature does not starve the '
      "in-flight feature's pending pair", () async {
    await seedRefusingShippedFeature();
    await seedInflightFeature();

    final out = await runner.runCapturing([
      'tdd',
      'gen',
      '--all',
      '--project',
      fx.root.path,
    ]);

    expect(
      out,
      contains('reuse refused'),
      reason: 'the shipped feature\'s row must refuse:\n$out',
    );
    expect(
      File(
        p.join(fx.root.path, 'test', 'tdd', inflightFeature, 'u1_test.dart'),
      ).existsSync(),
      isTrue,
      reason:
          'the batch must reach the in-flight feature and generate its '
          'pending pair — one refusal in an unrelated shipped feature must '
          'not starve it (issue #1975):\n$out',
    );
    expect(
      File(
        p.join(fx.root.path, 'lib', 'tdd', inflightFeature, 'u1_subject.dart'),
      ).existsSync(),
      isTrue,
      reason: 'the in-flight feature\'s subject is generated too:\n$out',
    );
    expect(
      CliRunner.lastDispatchedExitCode,
      isNot(0),
      reason: 'a refusal is still a non-zero exit — never a silent pass:\n$out',
    );
  });

  test('U2: the refusing row names the scoping lever `--feature` — never '
      'a destructive reset of the unrelated feature', () async {
    await seedRefusingShippedFeature();
    await seedInflightFeature();

    final out = await runner.runCapturing([
      'tdd',
      'gen',
      '--all',
      '--project',
      fx.root.path,
    ]);

    expect(
      out,
      contains('--> fix:'),
      reason: 'the refusal names a remedy:\n$out',
    );
    expect(
      out,
      contains('--feature $shippedFeature'),
      reason:
          'the unscoped batch must name the scoping lever — the refused '
          'row belongs to $shippedFeature (issue #1975):\n$out',
    );
    expect(
      out,
      isNot(contains('zfa tdd reset')),
      reason:
          'an unscoped batch never prescribes a destructive reset of a '
          'feature the caller may not be repairing (issue #1975):\n$out',
    );
  });

  test('U3: a SCOPED batch still stops at the refusal and keeps the '
      '`zfa tdd reset <feature>` remedy', () async {
    await seedRefusingShippedFeature();

    final out = await runner.runCapturing([
      'tdd',
      'gen',
      '--all',
      '--feature',
      shippedFeature,
      '--project',
      fx.root.path,
    ]);

    expect(
      out,
      contains('reuse refused'),
      reason: 'the scoped batch hits the same refusal:\n$out',
    );
    expect(
      out,
      contains('zfa tdd reset $shippedFeature'),
      reason:
          'in a scoped batch the refusing feature IS the feature under '
          'repair — the reset remedy stays (issue #1975):\n$out',
    );
    expect(
      out,
      isNot(contains('the batch continues with the other features')),
      reason:
          'a scoped batch has no other features to continue with — the '
          'message must be true in both scopes (issue #1975):\n$out',
    );
    expect(
      CliRunner.lastDispatchedExitCode,
      isNot(0),
      reason: 'the scoped batch stops at the refusal:\n$out',
    );
  });

  test('U4: the refusing feature\'s remaining row is skipped — the skip '
      'is part of the contract, not an accident', () async {
    await seedRefusingShippedFeature();
    await seedInflightFeature();

    final out = await runner.runCapturing([
      'tdd',
      'gen',
      '--all',
      '--project',
      fx.root.path,
    ]);

    expect(
      File(
        p.join(
          fx.root.path,
          'test',
          'tdd',
          shippedFeature,
          'contract_a1_test.dart',
        ),
      ).existsSync(),
      isFalse,
      reason:
          'the refusing feature\'s remaining rows are skipped — the skip '
          'is part of the contract (issue #1975):\n$out',
    );
    expect(
      File(
        p.join(
          fx.root.path,
          'lib',
          'tdd',
          shippedFeature,
          'contract_a1_subject.dart',
        ),
      ).existsSync(),
      isFalse,
      reason: 'the skipped row\'s subject is not generated either:\n$out',
    );
    expect(
      File(
        p.join(
          fx.root.path,
          'test',
          'tdd',
          inflightFeature,
          'contract_a1_test.dart',
        ),
      ).existsSync(),
      isTrue,
      reason:
          'the IDENTICAL row of the OTHER feature is generated — the skip '
          'is scoped to the refusing feature, never a blanket refusal '
          '(issue #1975):\n$out',
    );
    expect(
      out,
      contains('the batch continues with the other features'),
      reason: 'the unscoped batch says what it does:\n$out',
    );
  });

  test(
    'U5: the JSON envelope accounts for EVERY target of the batch',
    () async {
      await seedRefusingShippedFeature();
      await seedInflightFeature();

      final out = await runner.runCapturing([
        'tdd',
        'gen',
        '--all',
        '--json',
        '--project',
        fx.root.path,
      ]);

      final envelope = batchEnvelope(out);
      final details = envelope['details'] as Map<String, dynamic>;

      expect(
        envelope['verdict'],
        'fail',
        reason: 'a refusal is a failure of the run — never a pass:\n$out',
      );
      expect(details['refused'], 1, reason: out);
      expect(details['refused_rows'], '$shippedFeature:U1', reason: out);
      expect(details['skipped'], 1, reason: out);
      expect(
        details['skipped_rows'],
        '$shippedFeature:contract:A1',
        reason: 'the skipped row is NAMED, never dropped silently:\n$out',
      );
      expect(
        details.containsKey('stopped_at'),
        isFalse,
        reason:
            'the batch drove every remaining row — it did not stop at the '
            'refusal, so no row may be named as the stop point (issue '
            '#1975):\n$out',
      );
      expect(details['behaviors'], 4, reason: out);
    },
  );

  test('U6: a HARD failure (an unowned-file ownership conflict) still '
      'stops the WHOLE batch', () async {
    // The shipped feature's SECOND row owns a file no registry record
    // owns — gen refuses it with the FR-008 ownership conflict, a HARD
    // stop that is never scoped to a feature: the in-flight feature's
    // pending pair must NOT be generated.
    await fx.seedTestList([
      (
        id: 'B-001',
        description: 'first behavior red',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'B-002',
        description: 'second behavior red',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'B-003',
        description: 'never reached',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    final unowned = p.join(
      fx.root.path,
      'test',
      'tdd',
      shippedFeature,
      'b_002_test.dart',
    );
    await File(unowned).parent.create(recursive: true);
    await File(unowned).writeAsString('// unowned file\n');
    await seedInflightFeature();

    final out = await runner.runCapturing([
      'tdd',
      'gen',
      '--all',
      '--json',
      '--project',
      fx.root.path,
    ]);

    expect(
      CliRunner.lastDispatchedExitCode,
      isNot(0),
      reason: 'the hard failure stops the batch:\n$out',
    );
    expect(
      File(
        p.join(fx.root.path, 'test', 'tdd', inflightFeature, 'u1_test.dart'),
      ).existsSync(),
      isFalse,
      reason:
          'a hard failure stops the WHOLE batch — the other feature is '
          'never driven (issue #1975):\n$out',
    );
    expect(
      File(
        p.join(fx.root.path, 'test', 'tdd', shippedFeature, 'b_003_test.dart'),
      ).existsSync(),
      isFalse,
      reason: 'the row after the hard failure never ran:\n$out',
    );
    final details = batchEnvelope(out)['details'] as Map<String, dynamic>;
    expect(
      details['stopped_at'],
      'B-002',
      reason: 'the hard stop names its row — only a refusal is scoped:\n$out',
    );
  });
}
