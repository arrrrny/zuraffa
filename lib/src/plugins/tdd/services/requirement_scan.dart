/// Strict TUPEC requirement scan + coverage gate + contract hash (bug
/// #846 — the completeness proof behind the 100% TDD claim).
///
/// TUPEC vocabulary: requirement statements carry an explicit id
/// (`FR-xxx`, `AC-n`) and a normative `MUST`/`SHALL` sentence. The
/// scanner recognizes a statement ONLY in a defining position — a line
/// that (after list / table / heading / bold / numbering markers) BEGINS
/// with the id — so prose cross-references ("see FR-012") never count.
/// A requirement statement that produces no behavior row is a silent
/// spec gap today; this scanner is what makes it exit 2 instead.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../models/behavior.dart';

/// One recognized requirement statement in the spec contract.
class RequirementStatement {
  const RequirementStatement({
    required this.id,
    required this.isFunctional,
    required this.lineNo,
    required this.line,
    this.manualOwner,
  });

  /// `FR-001` / `AC-2` (as written in the spec).
  final String id;

  /// True for `FR-xxx` (unit loop), false for `AC-n` (outer loop).
  final bool isFunctional;

  /// 1-based line number in `spec.md` (printed with every gap).
  final int lineNo;

  /// The trimmed offending/statement line.
  final String line;

  /// Non-null when the statement carries `(manual: <owner>)` — the
  /// explicit non-automatable declaration (owner may be empty, which the
  /// gate rejects).
  final String? manualOwner;

  bool get isManual => manualOwner != null;
}

/// A requirement statement that produced no behavior row (and is not
/// validly declared manual). Printing the offending line + fix is the
/// whole point of the gate (issue #846).
class CoverageGap {
  const CoverageGap(this.statement, this.fix);

  final RequirementStatement statement;
  final String fix;
}

/// The result of scanning a spec contract.
class RequirementScan {
  const RequirementScan({required this.statements, required this.duplicates});

  /// Every requirement statement, in document order.
  final List<RequirementStatement> statements;

  /// Requirement ids defined by more than one acceptance statement — an
  /// ambiguous contract (exit 2; TUPEC acceptance ids must be
  /// unambiguous). FR restatements (mapping tables) are not flagged.
  final List<RequirementStatement> duplicates;

  bool get hasDuplicates => duplicates.isNotEmpty;
}

/// Raised by the coverage gate on any incomplete coverage. The message
/// names every offending spec line with its fix instruction.
class CoverageGapException implements Exception {
  CoverageGapException(this.gaps, this.duplicateGaps);

  final List<CoverageGap> gaps;
  final List<CoverageGap> duplicateGaps;

  List<CoverageGap> get all => [...duplicateGaps, ...gaps];

  @override
  String toString() =>
      'coverage gate: ${all.length} requirement statement(s) with no '
      'behavior row';
}

class RequirementScanner {
  const RequirementScanner();

  /// A strict acceptance scenario header: `1. **Given** ...` — the ONLY
  /// form the behavior-row parser accepts.
  static final RegExp _scenarioHeader = RegExp(r'^\s*(\d+)\.\s*\*\*Given\*\*');

  /// Statement position: the id must come first after optional list
  /// (`-`, `*`, `+`, `>`), heading (`#`), table (`|`), bold (`**`), and
  /// numbering (`1.`) markers. Mid-sentence references never match.
  static final RegExp _statementPrefix = RegExp(
    r'^\s*(?:[-*+>]\s*)?(?:#{1,6}\s*)?(?:\|\s*)?(?:\*\*|__)?'
    r'(?:(FR)|(AC))-(\d{1,4})(?:\*\*|__)?\s*[:\-—]?\s*(.*)$',
  );

  /// The inline non-automatable declaration: `(manual: <owner>)`.
  static final RegExp _manualMarker = RegExp(r'\(manual:\s*([^)]*)\)');

  /// Scan [specMd] into requirement statements.
  ///
  /// Acceptance scenarios numbered `1. **Given**` are statements too:
  /// their AC id is the document-wide sequential number (AC-1, AC-2, …
  /// across user stories — scenario numbers restart per story, and
  /// duplicate criterion ids would make any traceability proof
  /// ambiguous). A scenario line carrying `(manual: <owner>)` is the
  /// explicit non-automatable declaration.
  RequirementScan scan(String specMd) {
    final statements = <RequirementStatement>[];
    final seen = <String, RequirementStatement>{};
    final duplicates = <RequirementStatement>[];
    var scenarioIndex = 0;
    final lines = specMd.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final manual = _manualMarker.firstMatch(line);
      final manualOwner = manual?.group(1)?.trim();

      final header = _scenarioHeader.firstMatch(lines[i]);
      if (header != null) {
        scenarioIndex += 1;
        final statement = RequirementStatement(
          id: 'AC-$scenarioIndex',
          isFunctional: false,
          lineNo: i + 1,
          line: line,
          manualOwner: manualOwner,
        );
        _record(statement, statements, seen, duplicates);
        continue;
      }

      final m = _statementPrefix.firstMatch(line);
      if (m == null) continue;
      final isFunctional = m.group(1) != null;
      final id = '${isFunctional ? 'FR' : 'AC'}-${m.group(3)}';
      final statement = RequirementStatement(
        id: id,
        isFunctional: isFunctional,
        lineNo: i + 1,
        line: line,
        manualOwner: manualOwner,
      );
      _record(statement, statements, seen, duplicates);
    }
    return RequirementScan(statements: statements, duplicates: duplicates);
  }

  void _record(
    RequirementStatement statement,
    List<RequirementStatement> statements,
    Map<String, RequirementStatement> seen,
    List<RequirementStatement> duplicates,
  ) {
    statements.add(statement);
    // FR ids legitimately restate themselves in mapping tables; an AC id
    // defined twice WOULD make the acceptance proof ambiguous, so only
    // duplicate AC ids are flagged.
    if (statement.isFunctional) return;
    final prior = seen[statement.id];
    if (prior != null) {
      duplicates.add(statement);
    } else {
      seen[statement.id] = statement;
    }
  }
}

/// The coverage gate: prove every requirement statement maps to a
/// behavior row (or to a valid manual declaration).
class CoverageGate {
  const CoverageGate();

  /// Returns every gap. An empty list = complete coverage.
  List<CoverageGap> evaluate(RequirementScan scan, List<Behavior> behaviors) {
    final tracedIds = behaviors.map((b) => b.sourceCriterion).toSet();
    final gaps = <CoverageGap>[];
    final duplicateGaps = <CoverageGap>[];
    for (final statement in scan.duplicates) {
      duplicateGaps.add(
        CoverageGap(
          statement,
          'fix: requirement id "${statement.id}" is defined more than once '
          '(line ${statement.lineNo}) — TUPEC ids must be unambiguous; '
          'merge the duplicates or renumber, then re-run '
          '`zfa tdd plan`.',
        ),
      );
    }
    for (final statement in scan.statements) {
      final id = statement.id;
      final digits = id.split('-').last;
      final wellFormed = digits.length == 3;
      if (statement.isFunctional) {
        if (tracedIds.contains(id)) continue;
        gaps.add(
          CoverageGap(
            statement,
            wellFormed
                ? 'fix: write the requirement as a TUPEC bullet '
                      '`- **$id**: The system MUST ...` (one requirement per '
                      'bullet, normative MUST/SHALL sentence) so it produces a '
                      'unit behavior, or merge it into an existing FR; then '
                      're-run `zfa tdd plan`.'
                : 'fix: requirement ids must be the TUPEC 3-digit form '
                      '($id -> FR-${digits.padLeft(3, '0')}); rename the id and '
                      're-run `zfa tdd plan`.',
          ),
        );
        continue;
      }
      if (statement.isManual) {
        if (statement.manualOwner!.isEmpty) {
          gaps.add(
            CoverageGap(
              statement,
              'fix: a manual acceptance criterion must name an owner — '
              'write `(manual: @handle)` on the scenario line; then '
              're-run `zfa tdd plan`.',
            ),
          );
        }
        continue;
      }
      if (tracedIds.contains(id)) continue;
      gaps.add(
        CoverageGap(
          statement,
          'fix: the acceptance criterion produces no behavior row — write '
          'it as a numbered scenario '
          '(`1. **Given** ... **When** ... **Then** ...`) or, if it is '
          'inherently non-automatable, declare it on the scenario line '
          'with `(manual: @handle)`; then re-run `zfa tdd plan`.',
        ),
      );
    }
    return [...duplicateGaps, ...gaps];
  }
}

/// The lightweight spec-contract hash: sha256 over the scanned
/// requirement statement lines only (normalized content, NOT line
/// numbers — an inserted prose paragraph must not fire drift; a contract
/// edit does). verify/corpus re-check it and report drift (exit 3).
class SpecContractHash {
  const SpecContractHash._();

  static String compute(RequirementScan scan) {
    final digest = crypto.sha256.convert(
      utf8.encode(scan.statements.map((s) => s.line).join('\n')),
    );
    return digest.toString();
  }
}

/// Renders `specs/<feature>/tdd/traceability.md` — the plan artifact
/// that carries the behavior <-> FR/AC matrix and its hash (the
/// completeness proof verify/corpus re-check).
class TraceabilityMatrix {
  const TraceabilityMatrix();

  String render({
    required String feature,
    required RequirementScan scan,
    required List<Behavior> behaviors,
  }) {
    final hash = SpecContractHash.compute(scan);
    final byCriterion = <String, List<Behavior>>{};
    for (final b in behaviors) {
      byCriterion.putIfAbsent(b.sourceCriterion, () => []).add(b);
    }
    final manualCount = scan.statements.where((s) => s.isManual).length;

    final buf = StringBuffer()
      ..writeln('# Traceability: $feature')
      ..writeln()
      ..writeln(
        'Coverage proof for `zfa tdd plan` (bug #846): every FR/AC '
        'requirement statement maps to a behavior row or an explicit '
        'manual declaration. Verify re-checks the hash — a spec edited '
        'after plan is drift (exit 3, re-plan required).',
      )
      ..writeln()
      ..writeln('<!-- tdd:traceability')
      ..writeln('spec-hash: sha256:$hash')
      ..writeln('statements: ${scan.statements.length}')
      ..writeln('automated: ${scan.statements.length - manualCount}')
      ..writeln('manual: $manualCount')
      ..writeln('open-gaps: 0')
      ..writeln('-->')
      ..writeln()
      ..writeln('| requirement | line | statement | behavior | status |')
      ..writeln('| --- | --- | --- | --- | --- |');
    for (final statement in scan.statements) {
      final rows = byCriterion[statement.id] ?? const <Behavior>[];
      final behaviorCell = rows.isEmpty || statement.isManual
          ? '—'
          : rows.map((b) => b.id).join(', ');
      final status = statement.isManual
          ? 'manual (owner: ${statement.manualOwner})'
          : rows.isEmpty
          ? 'GAP'
          : 'automated';
      buf.writeln(
        '| ${statement.id} | ${statement.lineNo} | '
        '${_escapeCell(statement.line)} | $behaviorCell | $status |',
      );
    }
    buf.writeln();
    return buf.toString();
  }

  /// The machine block is the only thing downstream steps parse; keep it
  /// extractable here so verify and the renderer share one format.
  static final RegExp specHashPattern = RegExp(
    r'spec-hash:\s*sha256:([0-9a-f]{64})',
  );

  static String? extractSpecHash(String traceabilityMd) =>
      specHashPattern.firstMatch(traceabilityMd)?.group(1);

  /// Table cells must not break the row shape.
  static String _escapeCell(String text) =>
      text.replaceAll('|', r'\|').replaceAll('\n', ' ');
}
