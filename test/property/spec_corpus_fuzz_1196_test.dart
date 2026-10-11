// Issue #1196 (part of #908 P0) — fuzz-style mutation + property tests
// over the committed ZikZak corpus: the parser must never crash and
// never silently misroute when a spec's FORM changes (CRLF, HTML
// entities, BOM, nested numbering, unbolded markers, translated
// headings, dropped Lanes) — the derived behavior set is
// form-invariant. Content mutations (dropped treaty pin, emptied
// spec, duplicated marker) must land in HONEST outcomes: refusals
// that name the offending line, or a clean parse whose plan-level
// drift the gate reports (#919/#990).
//
// Property tier (dart_test.yaml): `dart test --preset=property`.
// Deterministic by construction — no RNG: the mutation set is the
// cross product of the 10 operators with the first spec of every
// shape class (13 specs × 10 operators = 130 mutants).
@Tags(['property', 'slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart'
    as parser_lib;
import 'package:zuraffa/src/plugins/tdd/services/spec_corpus_sweeper.dart';

import '../helpers/project_root.dart' as pr;

/// One deterministic mutation operator: id, whether it changes only
/// the spec's FORM (behavior set must stay identical) or its CONTENT
/// (honest refusal/drift expected), and the rewrite.
class MutationOp {
  const MutationOp(this.id, {required this.formOnly, required this.apply});

  final String id;
  final bool formOnly;
  final String Function(String) apply;
}

const List<MutationOp> ops = [
  MutationOp('to-crlf', formOnly: true, apply: _toCrlf),
  MutationOp('html-entities', formOnly: true, apply: _entityHeadings),
  MutationOp('drop-lanes', formOnly: true, apply: _dropLanes),
  MutationOp('bom', formOnly: true, apply: _bom),
  MutationOp('nest-numbering', formOnly: true, apply: _nestNumbering),
  MutationOp('unbold-markers', formOnly: true, apply: _unbold),
  MutationOp('translate-headings', formOnly: true, apply: _translate),
  MutationOp('drop-pin', formOnly: false, apply: _dropPin),
  MutationOp('empty', formOnly: false, apply: _empty),
  MutationOp('double-marker', formOnly: false, apply: _doubleMarker),
];

String _toCrlf(String md) =>
    md.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');

String _entityHeadings(String md) => md
    .replaceAllMapped(
      RegExp(r'^(#{1,6} .*)$', multiLine: true),
      (m) => m.group(1)!.replaceAll('&', '&amp;'),
    )
    .replaceAll(
      'External Dependencies & Contracts',
      'External Dependencies &amp; Contracts',
    );

String _dropLanes(String md) => md.replaceAll(
  RegExp(r'^## Lanes\b[^#]*\n(?:[^#\n]*\n?)*', multiLine: true),
  '',
);

String _bom(String md) => '\uFEFF$md';

String _nestNumbering(String md) => md.replaceAllMapped(
  RegExp(r'^(\d+)\. (\*\*Given\*\*)', multiLine: true),
  (m) => '${m.group(1)}.1. ${m.group(2)}',
);

String _unbold(String md) => md
    .replaceAll('**Given**', 'Given')
    .replaceAll('**When**', 'When')
    .replaceAll('**Then**', 'Then');

String _translate(String md) => md
    .replaceAllMapped(
      RegExp(r'^## Key Entities\b', multiLine: true, caseSensitive: false),
      (m) => '${m.group(0)} (Entidades Clave)',
    )
    .replaceAllMapped(
      RegExp(r'^## Layer Contracts\b', multiLine: true, caseSensitive: false),
      (m) => '${m.group(0)} — Contratos de Capa',
    );

String _dropPin(String md) => md.replaceAll(
  RegExp(r'^\*\*Template Version\*\*:.*\r?\n?', multiLine: true),
  '',
);

String _empty(String md) => md.replaceAll(RegExp(r'.', dotAll: true), ' ');

String _doubleMarker(String md) => md.replaceFirstMapped(
  RegExp(r'^(\s*)\*\*Type\*\*:.*$', multiLine: true),
  (m) => '${m.group(1)}**Type**: widget\n${m.group(1)}**Type**: widget',
);

/// The derived behavior fingerprint: ids + criteria + kinds — the
/// routing surface a form-only mutation must not move.
String fingerprint(String specMd) {
  final behaviors = const parser_lib.SpecParser().parse('fuzz', specMd);
  return behaviors
      .map((b) => '${b.id}:${b.sourceCriterion}:${b.kind.name}')
      .join('|');
}

void main() {
  late final Directory corpusRoot;
  late final Map<String, String> oracle;

  setUpAll(() async {
    final root = await pr.findProjectRoot();
    corpusRoot = Directory(p.join(root, 'corpus', 'zik_zak'));
    oracle = {
      for (final line in File(
        p.join(corpusRoot.path, 'corpus-shapes.txt'),
      ).readAsStringSync().split('\n'))
        if (line.trim().isNotEmpty)
          line.trim().split(RegExp(r'\s+'))[0]: line.trim().split(
            RegExp(r'\s+'),
          )[1],
    };
  });

  /// The first spec of every shape class — a deterministic sample
  /// covering the whole format matrix.
  Map<String, String> sampleSpecs() {
    final seen = <String, String>{};
    final names = oracle.keys.toList()..sort();
    for (final name in names) {
      final shape = oracle[name]!;
      if (seen.containsKey(shape)) continue;
      seen[shape] = File(
        p.join(corpusRoot.path, name, 'spec.md'),
      ).readAsStringSync();
    }
    return seen;
  }

  test('P1 (no crash): every mutant of every sampled spec parses or refuses '
      'with a line — never crashes', () {
    final sweeper = const SpecCorpusSweeper();
    final crashes = <String>[];
    for (final entry in sampleSpecs().entries) {
      for (final op in ops) {
        final mutant = op.apply(entry.value);
        final record = sweeper.sweepContent('${entry.key}~${op.id}', mutant);
        if (record.outcome == SweepOutcome.crashed) {
          crashes.add('${entry.key} ~ ${op.id}: ${record.error}');
        }
      }
    }
    expect(
      crashes.join('\n'),
      '',
      reason:
          '${sampleSpecs().length} shapes x ${ops.length} operators: '
          'crashed=${crashes.length}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('P2 (form invariance): form-only mutations never move the behavior '
      'set (no silent misroute)', () {
    final moved = <String>[];
    for (final entry in sampleSpecs().entries) {
      // The base fingerprint only exists for specs that parse; a
      // pathological base (empty/marker refusals) has no set to move.
      final baseRecord = const SpecCorpusSweeper().sweepContent(
        entry.key,
        entry.value,
      );
      if (baseRecord.outcome != SweepOutcome.clean) continue;
      final base = fingerprint(entry.value);
      for (final op in ops.where((o) => o.formOnly)) {
        final mutant = op.apply(entry.value);
        final record = const SpecCorpusSweeper().sweepContent(
          '${entry.key}~${op.id}',
          mutant,
        );
        if (record.outcome != SweepOutcome.clean) {
          moved.add(
            '${entry.key} ~ ${op.id}: clean parse became '
            '${record.outcome.name}',
          );
          continue;
        }
        final mutated = fingerprint(mutant);
        if (mutated != base) {
          moved.add(
            '${entry.key} ~ ${op.id}: behavior set moved\n'
            '  base:     $base\n'
            '  mutated:  $mutated',
          );
        }
      }
    }
    expect(
      moved.join('\n'),
      '',
      reason:
          'a spec whose FORM changed (CRLF, entities, BOM, nesting, '
          'unbolding, heading translation, dropped Lanes) must derive '
          'the same behaviors — anything else is a silent misroute',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('P3 (honest content mutations): pin drop, emptying, and duplicated '
      'markers land in honest outcomes', () {
    final sweeper = const SpecCorpusSweeper();
    for (final entry in sampleSpecs().entries) {
      // drop-pin: the parse stays clean, the pin is gone (the plan
      // drift gate reports it — exit 3, issue #990).
      final dropped = _dropPin(entry.value);
      final record = sweeper.sweepContent('${entry.key}~drop-pin', dropped);
      expect(
        record.outcome,
        anyOf(SweepOutcome.clean, SweepOutcome.refused),
        reason: '${entry.key}: drop-pin must not crash the parse',
      );
      if (record.facts != null) {
        expect(
          record.facts!.templateVersion,
          anyOf(isNull, isNot('zuraffa-1.0')),
          reason: 'the pin must be honestly absent after drop-pin',
        );
      }

      // empty: a line-addressed refusal, never a crash.
      final emptied = sweeper.sweepContent(
        '${entry.key}~empty',
        _empty(entry.value),
      );
      expect(
        emptied.outcome,
        SweepOutcome.refused,
        reason: '${entry.key}: an emptied spec refuses honestly',
      );

      // double-marker: honest refusal naming the line (where a Type
      // marker exists to duplicate).
      if (entry.value.contains('**Type**')) {
        final doubled = sweeper.sweepContent(
          '${entry.key}~double-marker',
          _doubleMarker(entry.value),
        );
        expect(
          doubled.outcome,
          SweepOutcome.refused,
          reason: '${entry.key}: duplicated marker refuses with a line',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the mutation oracle: every operator actually mutates its input '
      '(a no-op operator would pass the properties vacuously)', () {
    final samples = sampleSpecs();
    final modern = samples['modern']!;
    for (final op in ops) {
      // `empty` and `drop-lanes` produce trivially different output;
      // the oracle checks non-vacuity on the modern shape for all
      // ops that can apply to it.
      if (op.id == 'double-marker' && !modern.contains('**Type**')) {
        continue;
      }
      expect(
        op.apply(modern) != modern,
        isTrue,
        reason: 'operator ${op.id} must change its input',
      );
    }
  });
}
