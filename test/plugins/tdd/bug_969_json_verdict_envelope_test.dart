/// Issue #969 (tdd A+ upgrade, T001) — `--json` on every `zfa tdd`
/// subcommand emits ONE versioned verdict envelope as the final stdout
/// line: `{schema: verdict.v1, command, feature?, verdict, exit_class,
/// fix?, drifts, details, timestamp}`.
///
/// Red-first contract:
///   * every verb (all 22, including the new `verdicts`) emits the
///     envelope under `--json` — on success AND refusal paths;
///   * the exact schema (key set) is asserted for at least plan, gen,
///     verify-red, make, run, realize;
///   * the grammar is uniform: no verb adds a key outside the canonical
///     set, and the required keys are always present;
///   * without `--json` nothing changes: the last stdout line stays the
///     human summary (no `{"schema":...}` line appears).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/spec_fixture.dart';

/// The keys every verdict envelope MUST carry.
const Set<String> kRequiredEnvelopeKeys = {
  'schema',
  'command',
  'verdict',
  'exit_class',
  'drifts',
  'details',
  'timestamp',
};

/// The only keys allowed beyond the required set (optional fields).
const Set<String> kOptionalEnvelopeKeys = {'feature', 'fix'};

/// The canonical schema name (never drifts).
const String kSchemaName = 'verdict.v1';

/// The allowed verdict categories.
const Set<String> kVerdictCategories = {
  'pass',
  'fail',
  'stopped',
  'error',
};

/// The canonical envelope key set (required + optional).
const Set<String> kCanonicalKeySet = {
  ...kRequiredEnvelopeKeys,
  ...kOptionalEnvelopeKeys,
};

String _lastNonEmptyLine(String out) {
  final lines = out.trimRight().split('\n');
  return lines.isEmpty ? '' : lines.last;
}

Map<String, Object?> _decodeEnvelope(String out) {
  final last = _lastNonEmptyLine(out);
  final decoded = jsonDecode(last);
  expect(
    decoded,
    isA<Map<String, Object?>>(),
    reason: 'the FINAL stdout line must be a single JSON object, got: $last',
  );
  return decoded as Map<String, Object?>;
}

void _expectEnvelopeShape(
  Map<String, Object?> envelope, {
  required String command,
}) {
  expect(envelope['schema'], kSchemaName);
  expect(envelope['command'], command);
  expect(
    envelope['verdict'],
    anyOf(kVerdictCategories.map((v) => equals(v)).toList()),
  );
  expect(envelope['exit_class'], isA<String>());
  expect(envelope['drifts'], isA<List<Object?>>());
  expect(envelope['details'], isA<Map<String, Object?>>());
  expect(envelope['timestamp'], isA<String>());
  // The exact-schema contract: no key outside the canonical set.
  expect(
    envelope.keys.toSet().difference(kCanonicalKeySet),
    isEmpty,
    reason:
        'envelope for `$command` carries undocumented keys: '
        '${envelope.keys.toSet().difference(kCanonicalKeySet)}',
  );
}

void main() {
  late Directory tmp;
  const feature = '090-tdd-fixture';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bug969_json_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> runJson(List<String> args) {
    return CliRunner(exitOnCompletion: false).runCapturing([...args]);
  }

  /// Seeds `specs/<feature>/spec.md` (creating the directory first).
  Future<void> seedSpec(String body, {bool marker = true}) async {
    final featureDir = p.join(tmp.path, 'specs', feature);
    await Directory(featureDir).create(recursive: true);
    if (marker) {
      await writeSpec(featureDir, body);
    } else {
      await writeRawSpec(featureDir, body);
    }
  }

  group('issue #969 T001 — --json verdict envelope on every verb', () {
    test('plan emits the envelope on the contract-drift refusal path', () async {
      await seedSpec('# Spec\n\nno template marker\n', marker: false);
      final out = await runJson([
        'tdd',
        'plan',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'plan');
      expect(envelope['feature'], feature);
    });

    test('plan emits the envelope on the SUCCESS path (exact schema)', () async {
      await seedSpec(kMinimalAcceptance);
      final out = await runJson([
        'tdd',
        'plan',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'plan');
      expect(envelope['verdict'], 'pass');
      expect(envelope['exit_class'], 'ok');
      // The exact-schema assertion the acceptance names for `plan`.
      expect(envelope.keys.toSet(), containsAll(kRequiredEnvelopeKeys));
      expect(
        envelope.keys.toSet().difference(kCanonicalKeySet),
        isEmpty,
      );
    });

    test('gen emits the envelope on the SUCCESS path (exact schema)', () async {
      final specDir = p.join(tmp.path, 'specs', feature);
      await Directory(specDir).create(recursive: true);
      await File(p.join(specDir, 'spec.md')).writeAsString('''
# Spec for $feature

## Functional Requirements

- **FR-001**: the pdf-to-markdown ffi binding converts a sample pdf
''');
      await Directory(p.join(specDir, 'tdd')).create(recursive: true);
      await File(p.join(specDir, 'tdd', 'test-list.md')).writeAsString('''
# Test List for $feature

## Native loop: ffi behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U1 | the pdf-to-markdown ffi binding converts a sample pdf | FR-001 | PENDING |
''');
      final out = await runJson([
        'tdd',
        'gen',
        'U1',
        '--json',
        '--project',
        tmp.path,
        '--feature',
        feature,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'gen');
      expect(envelope['verdict'], 'pass');
      expect(kRequiredEnvelopeKeys.difference(envelope.keys.toSet()), isEmpty);
    });

    test('verify-red emits the envelope on the refusal path (exact schema)',
        () async {
      // No registry at all: verify-red refuses before any test run.
      final out = await runJson([
        'tdd',
        'verify-red',
        'U1',
        '--json',
        '--project',
        tmp.path,
        '--feature',
        feature,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'verify-red');
      expect(kRequiredEnvelopeKeys.difference(envelope.keys.toSet()), isEmpty);
    });

    test('make emits the envelope on the resolution-error path (exact schema)',
        () async {
      final out = await runJson([
        'tdd',
        'make',
        'U1',
        '--json',
        '--project',
        tmp.path,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'make');
      expect(kRequiredEnvelopeKeys.difference(envelope.keys.toSet()), isEmpty);
    });

    test('run emits the envelope on the error path (exact schema)', () async {
      final out = await runJson([
        'tdd',
        'run',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'run');
      expect(kRequiredEnvelopeKeys.difference(envelope.keys.toSet()), isEmpty);
    });

    test('realize emits the envelope on the error path (exact schema)',
        () async {
      final out = await runJson([
        'tdd',
        'realize',
        'Product',
        '--adapter',
        'RestProductAdapter',
        '--json',
        '--project',
        tmp.path,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'realize');
      expect(kRequiredEnvelopeKeys.difference(envelope.keys.toSet()), isEmpty);
    });

    test('verdicts emits the envelope; --schema is diff-stable', () async {
      final out1 = await runJson(['tdd', 'verdicts', '--schema', '--json']);
      final envelope = _decodeEnvelope(out1);
      _expectEnvelopeShape(envelope, command: 'verdicts');

      final out2 = await runJson(['tdd', 'verdicts', '--schema']);
      final out3 = await runJson(['tdd', 'verdicts', '--schema']);
      expect(out2, out3, reason: 'verdicts --schema must be diff-stable');
    });

    test('init emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'init',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'init');
    });

    test('fake emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'fake',
        'products',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'fake');
    });

    test('wire emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'wire',
        'U1',
        '--entity',
        'Product',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'wire');
    });

    test('compose emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'compose',
        'U1',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'compose');
    });

    test('func emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'func',
        'U1',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'func');
    });

    test('view emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'view',
        'U1',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'view');
    });

    test('refactor emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'refactor',
        '--feature',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'refactor');
    });

    test('replay emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'replay',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'replay');
    });

    test('verify emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'verify',
        '--feature',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'verify');
    });

    test('migrate-paths emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'migrate-paths',
        '--feature',
        feature,
        '--dry-run',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'migrate-paths');
    });

    test('corpus status emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'corpus',
        'status',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'corpus status');
    });

    test('corpus audit emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'corpus',
        'audit',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'corpus audit');
    });

    test('corpus run emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'corpus',
        'run',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'corpus run');
    });

    test('corpus differential emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'corpus',
        'differential',
        '--from',
        'HEAD~1',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out),
          command: 'corpus differential');
    });

    test('referee gate emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'referee',
        'gate',
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'referee gate');
    });

    test('diff-check emits the envelope', () async {
      final out = await runJson([
        'tdd',
        'diff-check',
        '--feature',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      _expectEnvelopeShape(_decodeEnvelope(out), command: 'diff-check');
    });

    test('reset emits the envelope (unified single machine line)', () async {
      final out = await runJson([
        'tdd',
        'reset',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'reset');
      // T005 unification: exactly ONE machine JSON line under --json —
      // the legacy reset custom JSON object must not appear.
      final jsonLines = out
          .split('\n')
          .where((l) => l.trimLeft().startsWith('{"schema"'))
          .toList();
      expect(jsonLines, hasLength(1));
    });

    test('doctor emits the envelope (unified single machine line)', () async {
      Directory(p.join(tmp.path, 'specs', feature, 'tdd'))
          .createSync(recursive: true);
      final out = await runJson([
        'tdd',
        'doctor',
        feature,
        '--json',
        '--project',
        tmp.path,
      ]);
      final envelope = _decodeEnvelope(out);
      _expectEnvelopeShape(envelope, command: 'doctor');
      final jsonLines = out
          .split('\n')
          .where((l) => l.trimLeft().startsWith('{"schema"'))
          .toList();
      expect(
        jsonLines,
        hasLength(1),
        reason: 'doctor must emit ONE envelope line under --json, '
            'not a second raw verdict object',
      );
    });
  });

  group('issue #969 T005 — uniform last-line grammar', () {
    test('every verb emits the SAME required key set under --json', () async {
      final observed = <String, Set<String>>{};
      Future<void> probe(String verb, List<String> args) async {
        final out = await runJson(args);
        observed[verb] = _decodeEnvelope(out).keys.toSet();
      }

      Directory(
        p.join(tmp.path, 'specs', feature, 'tdd'),
      ).createSync(recursive: true);
      await seedSpec('# Spec\n\nno marker\n', marker: false);

      await probe('plan', ['tdd', 'plan', feature, '--json', '--project', tmp.path]);
      await probe('make', ['tdd', 'make', 'U1', '--json', '--project', tmp.path]);
      await probe('run', ['tdd', 'run', feature, '--json', '--project', tmp.path]);
      await probe('reset', ['tdd', 'reset', feature, '--json', '--project', tmp.path]);
      await probe(
        'doctor',
        ['tdd', 'doctor', feature, '--json', '--project', tmp.path],
      );

      for (final entry in observed.entries) {
        expect(
          kRequiredEnvelopeKeys.difference(entry.value),
          isEmpty,
          reason: 'verb `${entry.key}` misses required keys: '
              '${kRequiredEnvelopeKeys.difference(entry.value)}',
        );
      }
    });
  });

  group('issue #969 — no behavior change without --json', () {
    test('plan without --json keeps the human last line (no envelope)',
        () async {
      await seedSpec(kMinimalAcceptance);
      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'plan',
        feature,
        '--project',
        tmp.path,
      ]);
      final last = _lastNonEmptyLine(out);
      expect(last.startsWith('{"schema"'), isFalse);
      // The compact envelope encoding never appears in captured output.
      expect(out, isNot(contains('"schema":"verdict.v1"')));
    });
  });
}
