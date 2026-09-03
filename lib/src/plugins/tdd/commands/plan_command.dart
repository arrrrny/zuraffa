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
        : ProjectRoot.find(anchorDir: 'specs');
    final specPath = '$repoRoot/specs/$feature/spec.md';
    final specFile = File(specPath);
    if (!await specFile.exists()) {
      stderr.writeln('zfa tdd plan: spec not found at $specPath');
      throw StateError('zfa tdd plan: spec not found');
    }
    final specMd = await specFile.readAsString();

    // Bug #919: the Template Version marker is the treaty pin. Missing or
    // unknown version = contract drift: exit 3 with a fix line, no
    // artifacts, BEFORE any parsing — a spec whose grammar we cannot
    // trust must not drive a plan (and must never hit the coverage gate,
    // whose messages would mislead on an unpinned spec).
    final templateVersion = const SpecParser().parseTemplateVersion(specMd);
    if (templateVersion == null ||
        !SpecParser.knownTemplateVersions.contains(templateVersion)) {
      final drift = templateVersion == null
          ? 'missing `**Template Version**` marker'
          : 'template version `$templateVersion` is not a known zuraffa '
                'template version (known: '
                '${SpecParser.knownTemplateVersions.join(', ')})';
      print(
        'zfa tdd plan: contract drift — $drift (spec: $specPath). '
        'No test list was written.',
      );
      print(
        '  --> fix: author the spec from the zuraffa spec template (zuraffa '
        'speckit extension) so it pins a known template version; re-run '
        '`zfa tdd plan`.',
      );
      exitCode = 3;
      return;
    }

    final List<Behavior> behaviors;
    try {
      behaviors = const SpecParser().parse(feature, specMd);
    } on StateError catch (e) {
      stderr.writeln('zfa tdd plan: $e');
      throw StateError('zfa tdd plan: cannot derive behaviors');
    }

    // Bug #829: extract the spec's Key Entities so the loop can create
    // and wire them (run phase 0 + the entity pipeline routing read
    // this section back through TestListReader.readEntities).
    final entities = const SpecParser().parseKeyEntities(specMd);

    // Bug #919: extract the zuraffa-1.0 template's declared dependencies
    // and layer contracts into the plan artifact, so the mock-first make
    // path (#909) and interface generation can consume them.
    final dependencies = const SpecParser().parseDependencies(specMd);
    final layerContracts = const SpecParser().parseLayerContracts(specMd);

    // Coverage gate (bug #846): every FR/AC requirement statement must
    // map to a behavior row or to a valid `(manual: owner)` declaration.
    // Any gap = exit 2, no artifacts, offending line + fix instruction.
    final scan = const RequirementScanner().scan(specMd);
    final gaps = const CoverageGate().evaluate(scan, behaviors);
    if (gaps.isNotEmpty) {
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

    // Bug #919: undeclared-dependency lint. The template declares what a
    // spec may reach for: a requirement statement referencing a known
    // external dependency that the External Dependencies & Contracts
    // table does not declare is a spec contract violation = exit 2,
    // naming the dependency with a fix line, no artifacts.
    final declaredDependencies = dependencies.map((d) => d.dependency).toSet();
    final undeclared = <RequirementStatement, List<String>>{};
    for (final statement in scan.statements) {
      final found = SpecParser.knownExternalDependencies
          .where(
            (name) =>
                RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(statement.line),
          )
          .where((name) => !declaredDependencies.contains(name))
          .toList();
      if (found.isNotEmpty) undeclared[statement] = found;
    }
    if (undeclared.isNotEmpty) {
      print(
        'zfa tdd plan: undeclared dependencies — ${undeclared.length} '
        'requirement statement(s) reference external dependencies not '
        'declared in the External Dependencies & Contracts table (spec: '
        '$specPath). No test list was written; declare each dependency '
        'or remove the reference, then re-run `zfa tdd plan`.',
      );
      undeclared.forEach((statement, names) {
        print(
          '  ${statement.id} (line ${statement.lineNo}): '
          '${statement.line}',
        );
        print(
          '    --> fix: add ${names.join(', ')} to the External '
          'Dependencies & Contracts table (or drop the reference).',
        );
      });
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

    // The completeness proof (bug #846): behavior <-> FR/AC matrix with
    // the spec-contract hash, re-checked by verify/corpus for drift.
    final matrix = const TraceabilityMatrix().render(
      feature: feature,
      scan: scan,
      behaviors: reconciled,
    );
    await File(p.join(outDir.path, 'traceability.md')).writeAsString(matrix);
    // Bug #835: hand-written ffi (native-boundary) rows survive
    // re-planning. Plan derives only acceptance/unit behaviors from
    // spec.md, so an ffi row would otherwise be silently re-homed as a
    // plain unit row (or dropped) on the next plan run — the native
    // boundary declaration is hand-authored and must be preserved
    // verbatim. An ffi row whose traces match a spec-derived criterion
    // WINS: the spec-derived behavior for that criterion is suppressed
    // (the explicit native declaration is the more specific contract).
    final preservedFfi = <BehaviorRow>[];
    try {
      for (final row in await TestListReader(
        '$repoRoot/specs/$feature',
      ).read()) {
        if (row.kind == BehaviorKind.ffi) preservedFfi.add(row);
      }
    } on TestListReadException catch (e) {
      stderr.writeln(
        'zfa tdd plan: note: prior test list unreadable, ffi rows not '
        'preserved (${e.message})',
      );
    }
    final ffiCriteria = preservedFfi.map((r) => r.traces).toSet();
    final expressible = reconciled
        .where((b) => !ffiCriteria.contains(b.sourceCriterion))
        .toList();

    await outDir.create(recursive: true);
    await outFile.writeAsString(
      _render(
        feature,
        expressible,
        entities,
        dependencies,
        layerContracts,
        preservedFfi,
      ),
    );

    final aCount = expressible
        .where((b) => b.kind == BehaviorKind.acceptance)
        .length;
    final uCount = expressible.where((b) => b.kind == BehaviorKind.unit).length;
    final fCount = preservedFfi.length;
    final total = expressible.length + fCount;
    stdout.writeln(
      fCount > 0
          ? 'zfa tdd plan: wrote $outFile with $aCount acceptance + $uCount '
                'unit + $fCount ffi behaviors ($total total).'
          : 'zfa tdd plan: wrote $outFile with $aCount acceptance + $uCount '
                'unit behaviors (${expressible.length} total).',
    );
    if (entities.isNotEmpty) {
      stdout.writeln(
        'zfa tdd plan: extracted ${entities.length} Key Entity('
        'ies): ${entities.map((e) => e.name).join(', ')}.',
      );
    }
  }

  String _render(
    String feature,
    List<Behavior> behaviors,
    List<SpecEntity> entities,
    List<SpecDependency> dependencies,
    List<LayerContract> layerContracts,
    List<BehaviorRow> preservedFfi,
  ) {
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
    // Bug #829: the spec's Key Entities, extracted for the loop's
    // entity orchestration (run phase 0 + the make entity pipeline).
    // The reader skips this section when resolving behavior rows.
    // Bug #919: a third `purpose` column when any entity declares one
    // (the zuraffa-1.0 template's table form). Purpose-less sections keep
    // the 2-column shape so every pre-919 artifact reads back identically.
    if (entities.isNotEmpty) {
      final hasPurpose = entities.any((e) => e.purpose.isNotEmpty);
      buf
        ..writeln()
        ..writeln('## Key entities')
        ..writeln();
      if (hasPurpose) {
        buf
          ..writeln('| entity | fields | purpose |')
          ..writeln('| ------ | ------ | ------- |');
        for (final e in entities) {
          buf.writeln(
            '| ${e.name} | '
            '${e.fields.map((f) => '${f.name}: ${f.type}').join(', ')}'
            ' | ${e.purpose} |',
          );
        }
      } else {
        buf
          ..writeln('| entity | fields |')
          ..writeln('| ------ | ------ |');
        for (final e in entities) {
          buf.writeln(
            '| ${e.name} | '
            '${e.fields.map((f) => '${f.name}: ${f.type}').join(', ')} |',
          );
        }
      }
    }
    if (dependencies.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## External dependencies')
        ..writeln()
        ..writeln('| dependency | type | contract | mock priority |')
        ..writeln('| ---------- | ---- | -------- | ------------- |');
      for (final d in dependencies) {
        buf.writeln(
          '| ${d.dependency} | ${d.type} | ${d.contract} '
          '| ${d.mockPriority} |',
        );
      }
    }
    if (layerContracts.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Layer contracts')
        ..writeln();
      final byLayer = <String, List<LayerContract>>{};
      for (final c in layerContracts) {
        byLayer.putIfAbsent(c.layer, () => []).add(c);
      }
      for (final entry in byLayer.entries) {
        buf
          ..writeln('### ${entry.key}')
          ..writeln();
        for (final c in entry.value) {
          buf.writeln('- `${c.interfaceName}`: ${c.methods.join(', ')}');
        }
      }
    }
    if (preservedFfi.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Native loop: ffi behaviors')
        ..writeln()
        ..writeln(
          'Native-boundary behaviors (bug #835) — preserved verbatim '
          'from the prior test list; plan derives acceptance/unit '
          'behaviors only, so these rows are hand-declared and survive '
          're-planning. gen scaffolds the binding-contract harness + '
          'golden fixture lane for them.',
        )
        ..writeln()
        ..writeln('| id | behavior | traces | state |')
        ..writeln('| -- | -------- | ------ | ----- |');
      for (final row in preservedFfi) {
        buf.writeln(
          '| ${row.id} | ${row.description} | ${row.traces} | '
          '${row.state.name.toUpperCase()} |',
        );
      }
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
