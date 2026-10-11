// Review #1612 pins for the shared schema-1 evidence chain walk
// (`evidence_chain.dart`): the canonical arms (content, linkage), the
// missing-hash guard for chain-claiming sections, the legacy tolerance,
// and the certifier-writer tolerance the walk gained so committed
// `fixtures` / `world-*` sections are no longer reported as tampering.
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_evidence.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';
import 'package:zuraffa/src/plugins/tdd/services/evidence_chain.dart';

/// One renderable section, hashed the way CycleLog renders red/green
/// entries when [hash] is omitted (the canonical chain).
String entry({
  required String behavior,
  required String kind,
  String exit = '0',
  String at = '2026-09-01T00:00:00.000Z',
  String command = 'dart test foo_test.dart',
  String criterion = 'FR-001',
  String test = '',
  required String prevHash,
  String? hash,
  String? schema,
}) {
  final resolved =
      hash ??
      CycleLog.chainHashFromFields(
        behaviorId: behavior,
        kind: kind,
        exit: exit,
        command: command,
        criterion: criterion,
        test: test,
        timestamp: at,
        prevHash: prevHash,
      );
  final buffer = StringBuffer()
    ..writeln('## Cycle: $behavior ($kind)')
    ..writeln('- behavior: $behavior')
    ..writeln('- kind: $kind');
  if (test.isNotEmpty) buffer.writeln('- test: $test');
  buffer
    ..writeln('- criterion: $criterion')
    ..writeln('- command: `$command`')
    ..writeln('- exit: $exit')
    ..writeln('- at: $at');
  if (schema != null) buffer.writeln('- schema: $schema');
  buffer.writeln('- prev-hash: $prevHash');
  if (hash != null || schema != null) {
    buffer.writeln('- hash: $resolved');
  }
  return '$buffer\n';
}

void main() {
  group('verifyEvidenceChain', () {
    test('a canonical per-behavior chain verifies', () {
      final markdown = entry(
        behavior: 'B-001',
        kind: 'red',
        prevHash: 'genesis',
        schema: '1',
      );
      // Render the red hash first, then chain the green onto it.
      final red = CycleLog.chainHashFromFields(
        behaviorId: 'B-001',
        kind: 'red',
        exit: '0',
        command: 'dart test foo_test.dart',
        criterion: 'FR-001',
        test: '',
        timestamp: '2026-09-01T00:00:00.000Z',
        prevHash: 'genesis',
      );
      final read = entry(
        behavior: 'B-001',
        kind: 'green',
        prevHash: red,
        schema: '1',
      );

      final walk = verifyEvidenceChain(parseEntries(markdown + read));

      expect(
        walk.ok,
        isTrue,
        reason: walk.drifts.map((d) => d.message).join('\n'),
      );
      expect(walk.unverifiedKinds, isEmpty);
    });

    test('an edited certified fact is a content drift', () {
      final raw = entry(
        behavior: 'B-001',
        kind: 'green',
        prevHash: 'genesis',
        schema: '1',
      ).replaceFirst('- exit: 0', '- exit: 1');

      final walk = verifyEvidenceChain(parseEntries(raw));

      expect(walk.ok, isFalse);
      expect(walk.drifts.single.kind, EvidenceChainDriftKind.content);
      expect(walk.drifts.single.message, contains('tampered with'));
    });

    test('a severed prev-hash link is a linkage drift', () {
      final raw = entry(
        behavior: 'B-001',
        kind: 'green',
        prevHash: 'genesis',
        schema: '1',
      ).replaceFirst('- prev-hash: genesis', '- prev-hash: ${'0' * 64}');

      final walk = verifyEvidenceChain(parseEntries(raw));

      expect(walk.ok, isFalse);
      expect(walk.drifts.single.kind, EvidenceChainDriftKind.linkage);
      expect(walk.drifts.single.message, contains('does not link'));
    });

    test('a hash-less legacy section is unverified, never failed', () {
      const raw =
          '## Cycle: B-001 (red)\n\n'
          '- behavior: B-001\n'
          '- kind: red\n'
          '- criterion: FR-001\n'
          '- command: `dart test`\n'
          '- exit: 1\n'
          '- at: 2026-08-01T00:00:00.000Z\n';

      final walk = verifyEvidenceChain(parseEntries(raw));

      expect(walk.ok, isTrue);
      expect(walk.unverifiedKinds, ['red']);
    });

    test('a chain-claiming section with no well-formed hash line is drift '
        '(the hash-less tail bypass)', () {
      final raw =
          entry(
            behavior: 'B-001',
            kind: 'red',
            prevHash: 'genesis',
            schema: '1',
          ).replaceAll(
            RegExp(r'^- hash: [0-9a-f]{64}$', multiLine: true),
            '- hash: NOTHEX',
          );

      final walk = verifyEvidenceChain(parseEntries(raw));

      expect(walk.ok, isFalse);
      expect(walk.drifts.single.kind, EvidenceChainDriftKind.missingHash);
      expect(walk.drifts.single.message, contains('cannot be verified'));
    });

    test('a legacy foreign-writer (fixtures) section is tolerated, never '
        'failed — the certifier payload the canonical walk cannot rebuild', () {
      final raw = entry(
        behavior: '042-fixtures',
        kind: 'fixtures',
        prevHash: 'genesis',
        schema: '1',
        hash: 'd08179e0${'0' * 56}',
      );

      final walk = verifyEvidenceChain(parseEntries(raw));

      expect(
        walk.ok,
        isTrue,
        reason: walk.drifts.map((d) => d.message).join('\n'),
      );
    });

    test('a converged foreign-writer section (canonical chain hash) '
        'verifies cleanly', () {
      final raw = entry(
        behavior: '042-fixtures',
        kind: 'fixtures',
        prevHash: 'genesis',
        schema: '1',
      );

      final walk = verifyEvidenceChain(parseEntries(raw));

      expect(walk.ok, isTrue);
      expect(walk.drifts, isEmpty);
    });

    test('a foreign-writer content edit is still tolerated (its scheme is '
        'unverifiable by the canonical walk)', () {
      final raw = entry(
        behavior: '042-fixtures',
        kind: 'fixtures',
        prevHash: 'genesis',
        schema: '1',
      ).replaceFirst('- exit: 0', '- exit: 7');

      final walk = verifyEvidenceChain(parseEntries(raw));

      expect(walk.ok, isTrue);
    });

    test('a canonical entry chains across hash-less legacy entries from '
        'genesis', () {
      const legacy =
          '## Cycle: B-001 (red)\n\n'
          '- behavior: B-001\n'
          '- kind: red\n'
          '- criterion: FR-001\n'
          '- command: `dart test`\n'
          '- exit: 1\n'
          '- at: 2026-08-01T00:00:00.000Z\n';
      final hashed = entry(
        behavior: 'B-001',
        kind: 'green',
        prevHash: 'genesis',
        schema: '1',
      );

      final walk = verifyEvidenceChain(parseEntries(legacy + hashed));

      expect(walk.ok, isTrue);
      expect(walk.unverifiedKinds, ['red']);
    });
  });
}
