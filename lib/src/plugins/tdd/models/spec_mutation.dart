/// Spec-mutation models (spec 0967-spec-mutation-arena) — the arena's
/// vocabulary: declared operators, addressable candidates, per-mutant
/// verdicts, the round gate, and the machine-readable weakness report
/// (`{mutation_id, spec_line, operator, verdict, evidence}` rows, the
/// issue #967 contract).
///
/// Determinism rules (VISION §7 "deterministic verdicts", #806 replay
/// semantics): candidate ids are document-order `SM-###`; report bodies
/// carry no timestamps and no wall-clock derived values; selection is a
/// seeded shuffle (`Random(seed)`, never `String.hashCode`).
library;

import 'dart:convert';

/// The declared operator set — mutations are per CONTRACT ELEMENT (Then
/// clauses, edge-case scenarios, FR literals/routes/keys/ranges,
/// MUST-NOT clauses), never free-text edits.
enum SpecMutationOperator {
  /// Weaken a Then clause: strip its assertion-bearing specifics
  /// (quoted/backticked literals become `something`, numbers become
  /// `a number`).
  weaken,

  /// Drop an edge-case scenario block (the scenario whose text matches
  /// the edge-case vocabulary).
  drop,

  /// Swap one declared literal / route / key / number in a Then or FR
  /// statement (strings get `-swapped` appended, numbers bump by one).
  swapLiteral,

  /// Widen a declared numeric range or bound (`N..M` -> `N~/2..M*2`,
  /// `at most N` -> `N*2`, `at least N` -> `N~/2`).
  widen,

  /// Drop a `MUST NOT` clause from an FR statement (to the sentence
  /// boundary).
  dropMustNot;

  /// The CLI token (`--operators weaken,drop,swap-literal,...`).
  String get label => switch (this) {
    SpecMutationOperator.weaken => 'weaken',
    SpecMutationOperator.drop => 'drop',
    SpecMutationOperator.swapLiteral => 'swap-literal',
    SpecMutationOperator.widen => 'widen',
    SpecMutationOperator.dropMustNot => 'drop-must-not',
  };

  /// One-line human description of what the operator does.
  String get summary => switch (this) {
    SpecMutationOperator.weaken =>
      'weaken a Then clause (strip literals and numbers)',
    SpecMutationOperator.drop => 'drop an edge-case scenario',
    SpecMutationOperator.swapLiteral =>
      'swap a declared literal / route / key / number',
    SpecMutationOperator.widen => 'widen a declared numeric range/bound',
    SpecMutationOperator.dropMustNot => 'drop a MUST NOT clause',
  };

  static const Set<SpecMutationOperator> all = {
    weaken,
    drop,
    swapLiteral,
    widen,
    dropMustNot,
  };

  /// Parse a comma-separated operator list. Unknown labels raise a
  /// [FormatException] naming the offender and the valid labels.
  /// Duplicate labels are rejected explicitly to surface typos.
  static Set<SpecMutationOperator> parseList(String raw) {
    final out = <SpecMutationOperator>{};
    for (final token in raw.split(',')) {
      final name = token.trim();
      if (name.isEmpty) continue;
      final match = all.where((op) => op.label == name).toList();
      if (match.isEmpty) {
        throw FormatException(
          'unknown spec-mutation operator "$name" — valid operators: '
          '${all.map((op) => op.label).join(', ')}',
        );
      }
      if (out.any((op) => op.label == name)) {
        throw FormatException(
          'duplicate spec-mutation operator "$name" in --operators list',
        );
      }
      out.add(match.single);
    }
    return out;
  }
}

/// One addressable mutation of one contract element.
class SpecMutationCandidate {
  const SpecMutationCandidate({
    required this.mutationId,
    required this.operator,
    required this.specLine,
    required this.element,
    required this.behaviorId,
    required this.originalValues,
    required this.targetToken,
    required this.description,
  });

  /// `SM-001` — document order of the parsed contract element.
  final String mutationId;

  final SpecMutationOperator operator;

  /// 1-based line number in `spec.md` of the mutated element (the
  /// scenario header for `drop`).
  final int specLine;

  /// The element address, e.g. `AC-1:Then`, `AC-2:scenario`,
  /// `AC-1:Then:literal:'Hello'`, `FR-001:literal:42`,
  /// `FR-003:range:0..100`, `FR-002:MUST-NOT`.
  final String element;

  /// The behavior the mutation affects (`A1`/`U2`); null is impossible
  /// today (every element belongs to a behavior).
  final String? behaviorId;

  /// The original values the P3 assertion-pin scan looks for (literals,
  /// numbers, routes, keys, range bounds, clause values).
  final List<String> originalValues;

  /// The exact matched token in the statement text (the apply step
  /// replaces it deterministically).
  final String targetToken;

  /// Human one-liner for reports.
  final String description;

  Map<String, dynamic> toJson() => {
    'mutation_id': mutationId,
    'operator': operator.label,
    'spec_line': specLine,
    'element': element,
    'behavior': behaviorId,
    'original_values': originalValues,
    'description': description,
  };
}

/// The per-mutant verdict.
enum SpecFuzzVerdict { killed, survived, notAssessed }

/// The result of applying the spec gate chain (P1) to a mutated spec —
/// `validateSpecContract` in `spec_mutator.dart` produces these.
class SpecGateCheck {
  const SpecGateCheck({required this.accepted, this.refusal});

  final bool accepted;

  /// The rejecting gate + line (null when accepted).
  final String? refusal;
}

/// One judged mutant: the candidate, its verdict, the pins that fired,
/// and deterministic evidence.
class SpecMutationOutcome {
  const SpecMutationOutcome({
    required this.candidate,
    required this.verdict,
    required this.evidence,
    required this.pins,
  });

  final SpecMutationCandidate candidate;
  final SpecFuzzVerdict verdict;

  /// Deterministic evidence line (names the pin that fired, or the pins
  /// that were checked and stayed silent for a survivor).
  final String evidence;

  /// The fired pins: `P1:plan-gate`, `P2:loop-red`, `P3:assertion`.
  final List<String> pins;

  Map<String, dynamic> toJson() => {
    'mutation_id': candidate.mutationId,
    'spec_line': candidate.specLine,
    'operator': candidate.operator.label,
    'element': candidate.element,
    'behavior': candidate.behaviorId,
    'verdict': verdict.name,
    'evidence': evidence,
    'pins': pins,
  };
}

/// The round gate — precedence mirrors `MutationGateDecision`:
/// notAssessed > preflightRed > failSurvived > pass.
enum SpecFuzzGateDecision { pass, failSurvived, preflightRed, notAssessed }

/// Decides the round gate from the tallies (the precedence contract).
SpecFuzzGateDecision decideSpecFuzzGate({
  required int survivedCount,
  required int notAssessedCount,
  required bool preflightRed,
}) {
  if (notAssessedCount > 0) return SpecFuzzGateDecision.notAssessed;
  if (preflightRed) return SpecFuzzGateDecision.preflightRed;
  if (survivedCount > 0) return SpecFuzzGateDecision.failSurvived;
  return SpecFuzzGateDecision.pass;
}

/// The machine-readable weakness report (written to
/// `specs/<feature>/tdd/spec-fuzz.json`, markdown twin `spec-fuzz.md`).
class SpecFuzzReport {
  const SpecFuzzReport({
    required this.feature,
    required this.gate,
    required this.seed,
    required this.budget,
    required this.candidateCount,
    required this.operators,
    required this.outcomes,
    required this.restorationVerified,
    required this.mutationWasRun,
    this.notAssessedReason,
    this.specHash,
    this.ledgerEntryIds = const <String>[],
    this.restorationScope = const <String>[],
  });

  final String feature;
  final SpecFuzzGateDecision gate;
  final int seed;
  final int budget;
  final int candidateCount;
  final List<String> operators;
  final List<SpecMutationOutcome> outcomes;
  final bool restorationVerified;
  final bool mutationWasRun;
  final String? notAssessedReason;

  /// sha256 of the ORIGINAL spec.md bytes — the evidence binding (bug
  /// #837 pattern).
  final String? specHash;

  /// The gap-ledger entry ids appended for survivors (empty when the
  /// ledger is disabled or nothing survived).
  final List<String> ledgerEntryIds;

  final List<String> restorationScope;

  int get killedCount =>
      outcomes.where((o) => o.verdict == SpecFuzzVerdict.killed).length;

  int get survivedCount =>
      outcomes.where((o) => o.verdict == SpecFuzzVerdict.survived).length;

  int get notAssessedCount =>
      outcomes.where((o) => o.verdict == SpecFuzzVerdict.notAssessed).length;

  /// `certified=true` only when the fuzz ran, generated at least one
  /// mutation, and killed every one — a vacuous or unrunnable round is
  /// never certified (presence counts cannot fake the kill rate).
  bool get certified =>
      mutationWasRun && outcomes.isNotEmpty && survivedCount == 0;

  /// The machine summary line — the CI contract (the `mutation:` line's
  /// sibling).
  String summaryLine() =>
      'spec-fuzz: feature=$feature mutations=${outcomes.length} '
      'killed=$killedCount survived=$survivedCount '
      'not_assessed=$notAssessedCount budget=$budget seed=$seed '
      'fuzz_was_run=$mutationWasRun certified=$certified';

  Map<String, dynamic> toJsonMap() => {
    'schema': 'spec-fuzz.v1',
    'feature': feature,
    'gate': gate.name,
    'certified': certified,
    if (notAssessedReason != null) 'not_assessed_reason': notAssessedReason,
    'seed': seed,
    'budget': budget,
    'candidate_count': candidateCount,
    'operators': operators,
    'mutations': [for (final o in outcomes) o.toJson()],
    'summary': {
      'mutations': outcomes.length,
      'killed': killedCount,
      'survived': survivedCount,
      'not_assessed': notAssessedCount,
    },
    'ledger_entry_ids': ledgerEntryIds,
    'restoration': {'verified': restorationVerified, 'scope': restorationScope},
    if (specHash != null) 'spec_hash': 'sha256:$specHash',
  };

  String toJson() => const JsonEncoder.withIndent('  ').convert(toJsonMap());

  String toMarkdown() {
    final buf = StringBuffer()
      ..writeln('# Spec Fuzz — feature `$feature`')
      ..writeln()
      ..writeln(
        'Mutation testing for intent (spec 0967, VISION §7): the '
        'referee round. Every mutation below was applied to `spec.md`, '
        'the loop\'s pins were re-run, and the verdict records whether '
        'anything in the harness detects the mutation. A survived '
        'mutant is a proven spec weakness — the test suite does not '
        'pin the intent.',
      )
      ..writeln()
      ..writeln('<!-- spec-fuzz')
      ..writeln('schema: spec-fuzz.v1')
      ..writeln('feature: $feature')
      ..writeln('gate: ${gate.name}')
      ..writeln('certified: $certified')
      ..writeln('mutations: ${outcomes.length}')
      ..writeln('killed: $killedCount')
      ..writeln('survived: $survivedCount')
      ..writeln('not_assessed: $notAssessedCount')
      ..writeln('seed: $seed')
      ..writeln('budget: $budget')
      ..writeln('restoration_verified: $restorationVerified')
      ..writeln('-->')
      ..writeln()
      ..writeln('## Gate')
      ..writeln()
      ..writeln('- gate: `${gate.name}`')
      ..writeln('- certified: `$certified`');
    if (notAssessedReason != null) {
      buf
        ..writeln('- reason: $notAssessedReason')
        ..writeln('  --> fix: $reason');
    }
    buf
      ..writeln()
      ..writeln('## Round')
      ..writeln()
      ..writeln('- seed: $seed')
      ..writeln('- budget: $budget')
      ..writeln('- candidates: $candidateCount')
      ..writeln('- operators: ${operators.join(', ')}')
      ..writeln('- fuzz_was_run: $mutationWasRun')
      ..writeln()
      ..writeln('## Mutations')
      ..writeln()
      ..writeln(
        '| mutation_id | spec_line | operator | element | verdict | evidence |',
      )
      ..writeln('| --- | --- | --- | --- | --- | --- |');
    for (final o in outcomes) {
      buf.writeln(
        '| ${o.candidate.mutationId} | ${o.candidate.specLine} | '
        '${o.candidate.operator.label} | ${_cell(o.candidate.element)} | '
        '${o.verdict.name} | ${_cell(o.evidence)} |',
      );
    }
    buf
      ..writeln()
      ..writeln('## Survived mutations (spec weaknesses)')
      ..writeln();
    final survivors = outcomes
        .where((o) => o.verdict == SpecFuzzVerdict.survived)
        .toList();
    if (survivors.isEmpty) {
      buf
        ..writeln('None — every generated mutation was killed.')
        ..writeln();
    } else {
      for (final o in survivors) {
        buf
          ..writeln(
            '- `${o.candidate.mutationId}` — ${o.candidate.element} '
            '(spec line ${o.candidate.specLine})',
          )
          ..writeln(
            '  --> fix: pin the intent — assert the original value(s) '
            '${o.candidate.originalValues.join(', ')} in the feature\'s '
            'tests, or tighten the statement so the loop re-derives a '
            'stronger assertion.',
          );
      }
      buf.writeln();
    }
    buf
      ..writeln('## Restoration')
      ..writeln()
      ..writeln('- verified: `$restorationVerified`')
      ..writeln('- scope: ${restorationScope.length} file(s)')
      ..writeln()
      ..writeln('## Ledger')
      ..writeln()
      ..writeln(
        ledgerEntryIds.isEmpty
            ? '- none (no survivors, or the ledger integration is off)'
            : '- ${ledgerEntryIds.join(', ')}',
      )
      ..writeln();
    if (specHash != null) {
      buf
        ..writeln('## Evidence binding')
        ..writeln()
        ..writeln('- spec_hash: `sha256:$specHash`')
        ..writeln();
    }
    return buf.toString();
  }

  /// The not_assessed remediation for the report.
  String get reason => switch (gate) {
    SpecFuzzGateDecision.pass => 'every generated mutation was killed',
    SpecFuzzGateDecision.failSurvived =>
      'survived mutants are spec '
          'weaknesses — pin them in the tests (see the survived rows)',
    SpecFuzzGateDecision.preflightRed =>
      'the feature suite is red — the '
          'fuzz refuses to grade a red loop; re-run `zfa tdd run <feature>`',
    SpecFuzzGateDecision.notAssessed => notAssessedReason ?? 'not assessed',
  };

  static String _cell(String text) =>
      text.replaceAll('|', r'\|').replaceAll('\n', ' ');
}
