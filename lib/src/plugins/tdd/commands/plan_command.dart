/// `zfa tdd plan <feature>` — read `spec.md`, emit `tdd/test-list.md`.
///
/// Bug #846 (coverage gate): plan PROVES every FR/AC requirement
/// statement maps to a behavior row (or to an explicit `(manual:
/// owner)` declaration) before anything is written. A requirement that
/// produces no behavior row = exit 2 with the offending spec line and a
/// fix instruction — and NO artifacts (an incomplete plan never emits a
/// test list that would silently claim completeness). On success the
/// plan artifact carries the traceability matrix plus the spec-contract
/// hash (`tdd/traceability.md`); verify/corpus re-check that hash and
/// report drift (exit 3) when the spec is edited after planning.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/requirement_scan.dart';
import '../services/spec_parser.dart';
import '../services/test_list_reader.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class PlanCommand extends Command<void> {
  PlanCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/<feature>/spec.md. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'plan';

  @override
  String get description =>
      'Read specs/<feature>/spec.md and emit '
      'specs/<feature>/tdd/test-list.md (one behavior per criterion).';

  @override
  String get invocation => 'zfa tdd plan <feature>';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Feature name is required: zfa tdd plan <feature>');
    }
    final feature = rest.first;
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults?['project'] as String?;
    final repoRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find();
    final specPath = '$repoRoot/specs/$feature/spec.md';
    final specFile = File(specPath);
    if (!await specFile.exists()) {
      stderr.writeln('zfa tdd plan: spec not found at $specPath');
      throw StateError('zfa tdd plan: spec not found');
    }
    final specMd = await specFile.readAsString();

    final List<Behavior> behaviors;
    try {
      behaviors = const SpecParser().parse(feature, specMd);
    } on StateError catch (e) {
      stderr.writeln('zfa tdd plan: $e');
      throw StateError('zfa tdd plan: cannot derive behaviors');
    }

    // Coverage gate (bug #846): every FR/AC requirement statement must
    // map to a behavior row or to a valid `(manual: owner)` declaration.
    // Any gap = exit 2, no artifacts, offending line + fix instruction.
    final scan = const RequirementScanner().scan(specMd);
    final gaps = const CoverageGate().evaluate(scan, behaviors);
    if (gaps.isNotEmpty) {
      // The gate decision goes through print() — the machine-readable
      // channel corpus/CI parse (same convention as the corpus
      // commands' summary lines).
      print(
        'zfa tdd plan: coverage gate FAILED — ${gaps.length} requirement '
        'statement(s) produce no behavior row (spec: $specPath). No test '
        'list was written; fix the spec and re-run `zfa tdd plan`.',
      );
      for (final gap in gaps) {
        print(
          '  ${gap.statement.id} (line ${gap.statement.lineNo}): '
          '${gap.statement.line}',
        );
        print('    ${gap.fix}');
      }
      exitCode = 2;
      return;
    }

    final outDir = Directory('$repoRoot/specs/$feature/tdd');
    final outFile = File('${outDir.path}/test-list.md');
    final existing = <String, Behavior>{};
    if (await outFile.exists()) {
      final raw = await outFile.readAsString();
      for (final line in raw.split('\n')) {
        final m = RegExp(
          r'^\|\s*([A|U]\d+)\s*\|.*?\|\s*([A-Z0-9\-, ]+)\s*\|',
        ).firstMatch(line);
        if (m != null) {
          final id = m.group(1)!;
          final traces = m.group(2)!.trim();
          existing[traces] = Behavior(
            id: id,
            feature: feature,
            kind: id.startsWith('A')
                ? BehaviorKind.acceptance
                : BehaviorKind.unit,
            description: '',
            sourceCriterion: traces,
            target: '',
          );
        }
      }
    }

    final reconciled = <Behavior>[];
    for (final b in behaviors) {
      final prior = existing[b.sourceCriterion];
      if (prior != null && prior.kind == b.kind) {
        reconciled.add(
          Behavior(
            id: prior.id,
            feature: b.feature,
            kind: b.kind,
            description: b.description,
            sourceCriterion: b.sourceCriterion,
            target: b.target,
          ),
        );
      } else {
        reconciled.add(b);
      }
    }

    await outDir.create(recursive: true);
    await outFile.writeAsString(_render(feature, reconciled));

    // The completeness proof (bug #846): behavior <-> FR/AC matrix with
    // the spec-contract hash, re-checked by verify/corpus for drift.
    final matrix = const TraceabilityMatrix().render(
      feature: feature,
      scan: scan,
      behaviors: reconciled,
    );
    await File(p.join(outDir.path, 'traceability.md')).writeAsString(matrix);

    final aCount = reconciled
        .where((b) => b.kind == BehaviorKind.acceptance)
        .length;
    final wCount = reconciled
        .where((b) => b.kind == BehaviorKind.widget)
        .length;
    final uCount = reconciled.where((b) => b.kind == BehaviorKind.unit).length;
    stdout.writeln(
      'zfa tdd plan: wrote $outFile with $aCount acceptance + $wCount widget '
      '+ $uCount unit behaviors (${reconciled.length} total).',
    );
  }

  String _render(String feature, List<Behavior> behaviors) {
    final acceptance = behaviors
        .where((b) => b.kind == BehaviorKind.acceptance)
        .toList();
    // Bug #830: widget-kind acceptance scenarios (UI-observable prose)
    // get their own outer-loop section so gen resolves their rows as
    // widget kind and emits the testWidgets pair.
    final widget = behaviors
        .where((b) => b.kind == BehaviorKind.widget)
        .toList();
    final unit = behaviors.where((b) => b.kind == BehaviorKind.unit).toList();

    final buf = StringBuffer()
      ..writeln('# Test List: $feature')
      ..writeln()
      ..writeln('## Outer loop: acceptance behaviors')
      ..writeln()
      ..writeln('One per acceptance criterion in `spec.md`.')
      ..writeln()
      ..writeln('| id | behavior | traces | state |')
      ..writeln('| -- | -------- | ------ | ----- |');
    for (final b in acceptance) {
      buf.writeln(
        '| ${b.id} | ${_marked(b)} | ${b.sourceCriterion} | PENDING |',
      );
    }
    buf
      ..writeln()
      ..writeln('## Outer loop: widget behaviors')
      ..writeln()
      ..writeln(
        'UI acceptance scenarios (bug #830): asserted through a testWidgets '
        'pair — a view-builder subject stub plus a widget test that pumps '
        'the view and asserts the scenario.',
      )
      ..writeln()
      ..writeln('| id | behavior | traces | state |')
      ..writeln('| -- | -------- | ------ | ----- |');
    for (final b in widget) {
      buf.writeln(
        '| ${b.id} | ${b.description} | ${b.sourceCriterion} | PENDING |',
      );
    }
    buf
      ..writeln()
      ..writeln('## Inner loop: unit behaviors')
      ..writeln()
      ..writeln('One per functional requirement in `spec.md`.')
      ..writeln()
      ..writeln('| id | behavior | traces | state |')
      ..writeln('| -- | -------- | ------ | ----- |');
    for (final b in unit) {
      buf.writeln(
        '| ${b.id} | ${_marked(b)} | ${b.sourceCriterion} | PENDING |',
      );
    }
    buf.writeln();
    return buf.toString();
  }

  /// Bug #833: the plan MARKS the behavior persistence-kind — a behavior
  /// whose prose names a persistence concern (Hive, cache, TTL, offline,
  /// corruption, registrar, persistence) gets the ` [persistence]` tag, and
  /// `zfa tdd gen` generates the harness-backed test for it. Idempotent.
  String _marked(Behavior b) => PersistenceMarker.matchesKeywords(b.description)
      ? PersistenceMarker.mark(b.description)
      : b.description;
}
