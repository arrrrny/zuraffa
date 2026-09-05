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

import '../models/lane.dart';
import '../models/routing.dart';
import '../services/lane_split.dart';
import '../services/routing_resolver.dart';
import '../services/requirement_scan.dart';
import '../services/spec_migrator.dart';
import '../services/spec_parser.dart';
import '../services/test_list_reader.dart';
import '../services/tdd_generation_receipt.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';
import '../../../utils/framework_export_surface.dart';

class PlanCommand extends Command<void> {
  PlanCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addFlag(
      'strict-routing',
      help:
          'Refuse undeclared routing intent instead of falling back to the '
          'legacy keyword classifiers. Undeclared behaviors exit 1 with the '
          'spec line and the declaration to add (feature 071, issue #951).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/<feature>/spec.md. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
    argParser.addFlag(
      'migrate-spec',
      help:
          'Migrate the spec to the latest known template version (issue '
          '#990): inject a missing **Template Version** marker, or refresh '
          'a stale/unknown one in place, then continue planning. Without '
          'this flag a missing/unknown marker stays contract drift (exit '
          '3) and the spec is never touched.',
      negatable: false,
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'plan';

  @override
  String get description =>
      'Read specs/<feature>/spec.md and emit '
      'specs/<feature>/tdd/test-list.md (one behavior per criterion).';

  @override
  String get invocation => 'zfa tdd plan <feature>';

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, featureFromRest: true);

  Future<void> _run() async {
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
    var specMd = await specFile.readAsString();

    // Issue #990: the migration path. `--migrate-spec` gives a
    // non-conformant spec an escape hatch that changes ONE thing — the
    // `**Template Version**` pin — and then lets the normal plan flow
    // proceed (the gate below re-checks the migrated content, so a
    // migration can never smuggle an unknown grammar past it). Without
    // the flag the spec is never mutated: drift stays drift (exit 3).
    if (argResults?['migrate-spec'] as bool? ?? false) {
      final migration = const SpecMigrator().migrate(specMd);
      if (migration.migrated) {
        await specFile.writeAsString(migration.content);
        final verb = migration.action == SpecMigrationAction.inserted
            ? 'inserted'
            : 'refreshed';
        print(
          'zfa tdd plan: migrated spec — $verb `**Template Version**: '
          '`${SpecParser.latestTemplateVersion}`'
          '${migration.previousVersion == null ? '' : ' (was: ${migration.previousVersion})'} '
          '(spec: $specPath). Re-run `zfa tdd plan` without the flag any '
          'time; the marker is persisted.',
        );
      }
      specMd = migration.content;
    }

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
        '  --> fix: run `zfa tdd plan --migrate-spec` to inject the latest '
        'template version marker into this spec (issue #990), or author '
        'the spec from the zuraffa spec template (zuraffa speckit '
        'extension) so it pins a known template version; re-run '
        '`zfa tdd plan`.',
      );
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'contract-drift'
        ..fix =
            'author the spec from the zuraffa spec template so it pins '
            'a known template version; re-run zfa tdd plan'
        ..details['spec'] = specPath;
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
    // path (#909) and interface generation can consume them. The Layer
    // Contracts also drive the contract:<id> rows (issue #1007) — derived
    // after the prior test list is read, so ids reconcile by traces.
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
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'coverage-gate'
        ..fix =
            'map every requirement statement to a behavior row or a '
            '(manual: owner) declaration, then re-run zfa tdd plan'
        ..details['gaps'] = gaps.length;
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
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'undeclared-dependency'
        ..fix =
            'add the referenced dependencies to the External '
            'Dependencies & Contracts table (or drop the references), '
            'then re-run zfa tdd plan'
        ..details['undeclared'] = undeclared.length;
      exitCode = 2;
      return;
    }

    // Bug #993: entity/zuraffa-export clash gate. The spec's Key
    // Entities become phase-0 `entity create` spawns at run time; a name
    // that matches a zuraffa export (e.g. `AgentState`) is refused there
    // by the #942 preflight and the run stops before any behavior is
    // driven. Plan catches the clash HERE — before any artifact is
    // written — with the same `--> fix:` rename contract the run-time
    // preflight carries. The run-time detection itself is untouched:
    // this gate reuses the SAME export surface (FrameworkExportSurface,
    // fail-open), so it is an earlier net, never a weaker one — an
    // unresolvable surface skips the gate silently and can never
    // produce a false refusal.
    final surface = FrameworkExportSurface.tryResolve(projectRoot: repoRoot);
    if (surface != null && entities.isNotEmpty) {
      final clashes = <(SpecEntity, String)>[];
      for (final entity in entities) {
        final source = surface.lookup(entity.name);
        if (source != null) clashes.add((entity, source));
      }
      if (clashes.isNotEmpty) {
        print(
          'zfa tdd plan: entity/export clash — ${clashes.length} Key '
          'Entity(ies) collide with zuraffa framework exports (spec: '
          '$specPath). No test list was written; phase-0 `entity create` '
          'would refuse these names at run time and stop the loop before '
          'any behavior is driven.',
        );
        for (final (entity, source) in clashes) {
          print(
            '  ${entity.name} collides with the zuraffa export '
            '"${entity.name}" ($source).',
          );
          print(
            "    --> fix: rename the entity in the spec's Key Entities "
            'section, e.g. `${entity.name}Entity` — pick a name that does '
            'not match a zuraffa export; re-run `zfa tdd plan`.',
          );
        }
        exitCode = 2;
        return;
      }
    }

    final outDir = Directory('$repoRoot/specs/$feature/tdd');
    final outFile = File('${outDir.path}/test-list.md');
    final existing = <String, Behavior>{};
    if (await outFile.exists()) {
      var raw = await outFile.readAsString();
      // Issue #1000: a prior lane split carries its rows in the lane
      // plans the meta-index points at — reconcile against those so
      // re-planning a split feature keeps its id assignment.
      final split = LaneSplitFiles.find(raw);
      if (split != null) {
        final combined = StringBuffer();
        for (final name in [split.engine, split.skin]) {
          final laneFile = File(p.join(outDir.path, name));
          if (await laneFile.exists()) {
            combined.writeln(await laneFile.readAsString());
          }
        }
        raw = combined.toString();
      }
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

    // Bug #835: hand-written ffi (native-boundary) rows survive
    // re-planning. Plan derives only acceptance/unit behaviors from
    // spec.md, so an ffi row would otherwise be silently re-homed as a
    // plain unit row (or dropped) on the next plan run — the native
    // boundary declaration is hand-authored and must be preserved
    // verbatim. An ffi row whose traces match a spec-derived criterion
    // WINS: the spec-derived behavior for that criterion is suppressed
    // (the explicit native declaration is the more specific contract).
    //
    // Issue #1007: the same pass harvests the prior CONTRACT rows — their
    // (id, state) pairs reconcile the freshly derived contract behaviors
    // by traces so `contract:<id>` ids stay stable across re-plans and a
    // BLOCKED/DONE contract row keeps its recorded state.
    final preservedFfi = <BehaviorRow>[];
    final priorContract = <String, (String, BehaviorState)>{};
    try {
      for (final row in await TestListReader(
        '$repoRoot/specs/$feature',
      ).read()) {
        if (row.kind == BehaviorKind.ffi) preservedFfi.add(row);
        if (row.kind == BehaviorKind.contract) {
          priorContract[row.traces] = (row.id, row.state);
        }
      }
    } on TestListReadException catch (e) {
      stderr.writeln(
        'zfa tdd plan: note: prior test list unreadable, ffi rows not '
        'preserved (${e.message})',
      );
    }
    final contractBehaviors = _reconcileContractBehaviors(
      _deriveContractBehaviors(
        feature,
        layerContracts,
        entities.map((e) => e.name).toSet(),
      ),
      priorContract,
    );
    final ffiCriteria = preservedFfi.map((r) => r.traces).toSet();
    final expressible = reconciled
        .where((b) => !ffiCriteria.contains(b.sourceCriterion))
        .toList();

    // Feature 071 (issue #951): per-behavior routing provenance — the
    // resolver consults the parsed declarations; undeclared behaviors
    // render their LABELED legacy fallback (migration window).
    //
    // Round-2 review fix 3a: declarations parse BEFORE any artifact is
    // written — a malformed Function signature is a refusal naming the
    // row (`--> fix:`), and a strict refusal must leave the feature
    // directory untouched (traceability.md included).
    final strict = argResults?['strict-routing'] as bool? ?? false;
    final Map<String, ScenarioDeclaration> scenarioMarkers;
    final SpecDeclarations declarations;
    final Map<String, List<String>> frTraces;
    try {
      scenarioMarkers = SpecParser.parseScenarioTypeMarkers(specMd);
      declarations = SpecDeclarations(
        scenarios: scenarioMarkers,
        contractRows: {
          for (final r in const SpecParser().parseContractRows(specMd))
            r.name: r,
        },
        persistence: SpecParser.parsePersistenceDeclarations(specMd),
      );
      frTraces = SpecParser.parseFrContractTraces(specMd);
    } on StateError catch (e) {
      print('zfa tdd plan: declaration refused — ${e.message}');
      print('  no artifacts were written.');
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'declaration-refused'
        ..fix =
            'fix the malformed declaration named above, then re-run '
            'zfa tdd plan'
        ..details['reason'] = e.message;
      exitCode = 2;
      return;
    }
    final provenance = _provenanceLines(
      expressible,
      preservedFfi,
      declarations,
      frTraces,
      scenarioMarkers,
      strict: strict,
    );
    // Strict gate (feature 071): a refusal writes no artifact.
    if (strict && provenance.containsKey('__refused__')) {
      for (final line in provenance.remove('__refused__')!) {
        print(line);
      }
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'routing-refused'
        ..fix =
            'declare the routing intent (Type marker / contract trace) '
            'for every refused behavior, then re-run zfa tdd plan --strict-routing'
        ..details['strict'] = true;
      exitCode = 1;
      return;
    }

    // Issue #1000: lane resolution. A spec declaring `## Lanes` plans
    // into the split files (04-ENGINE.md / 04-SKIN.md / 04-CONTRACT.md
    // + the meta-index); the lane guards refuse BEFORE any artifact —
    // an incomplete split never leaves a half-written lane plan.
    final lanes = const SpecParser().parseLanes(specMd);
    final laneResult = lanes.isEmpty
        ? null
        : _resolveLanes(lanes, expressible, preservedFfi);
    if (laneResult != null && laneResult.refusals.isNotEmpty) {
      print(
        'zfa tdd plan: lane contract FAILED — ${laneResult.refusals.length} '
        'lane violation(s) (spec: $specPath). No test list was written; '
        'fix the ## Lanes section and re-run `zfa tdd plan`.',
      );
      for (final refusal in laneResult.refusals) {
        print('  $refusal');
      }
      exitCode = 2;
      return;
    }

    // Issue #1007: contract rows carry their own declared lane in the
    // provenance artifact (they are spec-DECLARED through the Layer
    // Contracts section, like the ffi lane's native-loop declaration).
    for (final b in contractBehaviors) {
      provenance.putIfAbsent(
        b.id,
        () => [
          'route: ${b.id} -> contract lane '
              '[declared: layer contracts section]',
        ],
      );
    }

    await outDir.create(recursive: true);
    // The completeness proof (bug #846): behavior <-> FR/AC matrix with
    // the spec-contract hash, re-checked by verify/corpus for drift.
    // Written only AFTER the declarations parse and the strict gate
    // pass (round-2 review fix 3a).
    final matrix = const TraceabilityMatrix().render(
      feature: feature,
      scan: scan,
      behaviors: reconciled,
    );
    await File(p.join(outDir.path, 'traceability.md')).writeAsString(matrix);

    if (laneResult != null) {
      // Issue #1000: the lane split — engine plan + skin plan + the
      // engine/skin contract, with the legacy filename demoted to the
      // meta-index. TestListReader resolves the rows from the split
      // files, so gen/make/run semantics are unchanged.
      final engineRows = <LaneRow>[
        for (final b in expressible)
          ..._derivedLaneRows(b, laneResult, declarations.persistence),
        ..._ffiLaneRows(preservedFfi, laneResult),
        ...laneResult.handRows,
      ].where((r) => r.lane.destinedForEngine).toList();
      final skinRows = <LaneRow>[
        for (final b in expressible)
          ..._derivedLaneRows(b, laneResult, declarations.persistence),
        ..._ffiLaneRows(preservedFfi, laneResult),
        ...laneResult.handRows,
      ].where((r) => r.lane.destinedForSkin).toList();
      final adaptiveSlots = lanes
          .expand((l) => l.adaptiveSlots)
          .toSet()
          .toList();

      final engineProvenance = <String, List<String>>{};
      final skinProvenance = <String, List<String>>{};
      provenance.forEach((id, lines) {
        // Ffi rows and any unclassified id default engine-side (the
        // native boundary + routing bookkeeping are engine-owned).
        final lane = laneResult.classification[id] ?? Lane.core;
        if (lane.destinedForEngine) engineProvenance[id] = lines;
        if (lane.destinedForSkin) skinProvenance[id] = lines;
      });

      final engineMd = renderEnginePlan(
        feature: feature,
        rows: engineRows,
        entities: entities,
        dependencies: dependencies,
        layerContracts: layerContracts,
        provenance: engineProvenance,
      );
      final skinMd = renderSkinPlan(
        feature: feature,
        rows: skinRows,
        adaptiveSlots: adaptiveSlots,
        provenance: skinProvenance,
      );
      final contractMd = renderContractPlan(
        feature: feature,
        adaptiveSlots: adaptiveSlots,
        bothRows: engineRows.where((r) => r.lane == Lane.both).toList(),
      );
      final metaMd = renderMetaIndex(
        feature: feature,
        lanes: lanes,
        classification: laneResult.classification,
      );
      await File(
        p.join(outDir.path, LaneSplitFiles.engine),
      ).writeAsString(engineMd);
      await File(
        p.join(outDir.path, LaneSplitFiles.skin),
      ).writeAsString(skinMd);
      await File(
        p.join(outDir.path, LaneSplitFiles.contract),
      ).writeAsString(contractMd);
      await outFile.writeAsString(metaMd);
      for (final line in provenance.values.expand((l) => l)) {
        print('   $line');
      }
      stdout.writeln(
        'zfa tdd plan: wrote ${p.join(outDir.path, LaneSplitFiles.engine)} '
        '(${engineRows.where((r) => r.lane == Lane.core).length} CORE '
        'behaviors), ${p.join(outDir.path, LaneSplitFiles.skin)} '
        '(${skinRows.where((r) => r.lane == Lane.skin).length} SKIN '
        'behaviors), ${p.join(outDir.path, LaneSplitFiles.contract)}; '
        'test-list.md is the lane meta-index '
        '(${laneResult.classification.length} behaviors, '
        '${engineRows.where((r) => r.lane == Lane.both).length} BOTH).',
      );
      if (entities.isNotEmpty) {
        stdout.writeln(
          'zfa tdd plan: extracted ${entities.length} Key Entity('
          'ies): ${entities.map((e) => e.name).join(', ')}.',
        );
      }
      return;
    }

    await outFile.writeAsString(
      _render(
        feature,
        expressible,
        contractBehaviors,
        entities,
        dependencies,
        layerContracts,
        preservedFfi,
        declarations.persistence,
        provenance,
      ),
    );
    // Issue #969 T003: the plan's artifacts become self-certifying —
    // digest-bound receipts so the preflight gate can catch hand-edits.
    await TddGenerationReceipts.writeBestEffort(
      projectRoot: repoRoot,
      command: 'tdd plan',
      target: feature,
      feature: feature,
      files: {
        outFile.path: 'update',
        p.join(outDir.path, 'traceability.md'): 'update',
      },
    );
    for (final line in provenance.values.expand((l) => l)) {
      // print (not stdout.writeln): the observable-CLI convention the
      // tdd command suites assert on (runCapturing intercepts print).
      print('   $line');
    }

    final aCount = expressible
        .where((b) => b.kind == BehaviorKind.acceptance)
        .length;
    final uCount = expressible.where((b) => b.kind == BehaviorKind.unit).length;
    final cCount = contractBehaviors.length;
    final fCount = preservedFfi.length;
    final total = expressible.length + cCount + fCount;
    final laneList = [
      '$aCount acceptance',
      '$uCount unit',
      if (cCount > 0) '$cCount contract',
      if (fCount > 0) '$fCount ffi',
    ].join(' + ');
    stdout.writeln(
      'zfa tdd plan: wrote $outFile with $laneList behaviors ($total total).',
    );
    if (entities.isNotEmpty) {
      stdout.writeln(
        'zfa tdd plan: extracted ${entities.length} Key Entity('
        'ies): ${entities.map((e) => e.name).join(', ')}.',
      );
    }
    _verdict
      ..details['acceptance'] = aCount
      ..details['unit'] = uCount
      ..details['ffi'] = fCount
      ..details['behaviors'] = total
      ..details['test_list'] = outFile.path;
  }

  String _render(
    String feature,
    List<Behavior> behaviors,
    List<Behavior> contractBehaviors,
    List<SpecEntity> entities,
    List<SpecDependency> dependencies,
    List<LayerContract> layerContracts,
    List<BehaviorRow> preservedFfi,
    Map<String, PersistenceDeclaration> persistenceDeclarations,
    Map<String, List<String>> provenanceLines,
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
        '| ${b.id} | ${_marked(b, persistenceDeclarations)} | ${b.sourceCriterion} | PENDING |',
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
        '| ${b.id} | ${_marked(b, persistenceDeclarations)} | ${b.sourceCriterion} | PENDING |',
      );
    }
    // Issue #1007: the CONTRACT lane — one row per declared entity
    // method, controller method and usecase of the spec's Layer
    // Contracts section. Gen's pair for these rows is a contract test
    // scaffold + contract seam (NOT an implementation test), and a
    // failing contract test is BLOCKED (never RED) — the row's state
    // column carries BLOCKED until the implementation satisfies the
    // declared contract.
    if (contractBehaviors.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Contract loop: contract behaviors')
        ..writeln()
        ..writeln(
          'One per declared entity method, controller method and usecase '
          'in `spec.md` Layer Contracts (issue #1007). A contract test '
          'proves the implementation satisfies the DECLARED contract — '
          'a failing contract test is BLOCKED (never RED) and blocks the '
          'cycle from proceeding to GREEN.',
        )
        ..writeln()
        ..writeln('| id | behavior | traces | state |')
        ..writeln('| -- | -------- | ------ | ----- |');
      for (final b in contractBehaviors) {
        buf.writeln(
          '| ${b.id} | ${b.description} | ${b.sourceCriterion} | '
          '${b.state.name.toUpperCase()} |',
        );
      }
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
    // Feature 071: the durable provenance artifact.
    if (provenanceLines.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Routing provenance')
        ..writeln()
        ..writeln(
          'Per-behavior routing decisions (issue #951): what each '
          'decision consulted — a declared marker/contract row, or the '
          'labeled legacy fallback to migrate.',
        )
        ..writeln();
      for (final lines in provenanceLines.values) {
        for (final line in lines) {
          buf.writeln(line);
        }
      }
    }
    buf.writeln();
    return buf.toString();
  }

  /// Feature 071 (issue #951): the per-behavior routing provenance —
  /// the resolver consults the parsed declarations; undeclared
  /// behaviors render their LABELED legacy fallback (migration window;
  /// strict mode turns these into refusals).
  Map<String, List<String>> _provenanceLines(
    List<Behavior> behaviors,
    List<BehaviorRow> preservedFfi,
    SpecDeclarations declarations,
    Map<String, List<String>> frTraces,
    Map<String, ScenarioDeclaration> scenarioMarkers, {
    bool strict = false,
  }) {
    const resolver = RoutingResolver();
    final lines = <String, List<String>>{};
    String lane(BehaviorKind kind) => switch (kind) {
      BehaviorKind.acceptance => 'acceptance lane',
      BehaviorKind.widget => 'widget lane',
      BehaviorKind.unit => 'unit lane',
      BehaviorKind.ffi => 'ffi lane',
      BehaviorKind.platform => 'platform lane',
      BehaviorKind.theme => 'theme lane',
      BehaviorKind.contract => 'contract lane',
    };

    void record(String id, List<String> entry) => lines[id] = entry;

    for (final b in behaviors) {
      // Rung-3 kind for spec-parsed behaviors is DECLARED only via the
      // `**Type**` marker — the parse-time sniffer kind is precisely the
      // legacy fallback being labeled, so it is NOT passed as declared.
      final result = resolver.resolve(
        row: RoutingRow(
          behaviorId: b.id,
          kind: scenarioMarkers[b.id]?.declaredType,
          traces: frTraces[b.id] ?? const [],
        ),
        declarations: declarations,
        strict: strict,
      );
      final decision = b.kind;
      if (result is RoutingDecision) {
        final first = result.provenance.firstOrNull;
        final extras = <String>[
          if (result.surface == GenerationSurface.plainFunction)
            'func surface'
          else if (result.surface == GenerationSurface.entityPipeline &&
              result.entityName != null)
            'entity pipeline: ${result.entityName}'
          else if (result.surface == GenerationSurface.viewGeneration)
            'view generation',
        ];
        final detail = extras.isEmpty ? '' : ' (${extras.join(', ')})';
        record(b.id, [
          'route: ${b.id} -> ${lane(decision)}$detail '
              '[declared: ${first?.detail ?? 'declaration'}'
              '${first?.specLine == null ? '' : ', spec line ${first!.specLine}'}]',
        ]);
        continue;
      }
      if (result is RoutingFailure) {
        if (strict) {
          // Append: several behaviors may refuse; every refusal must
          // survive (a shared fixed key would overwrite earlier ones —
          // caught by the quickstart run, feature 071).
          lines.putIfAbsent('__refused__', () => <String>[]).addAll([
            'zfa tdd plan: ${result.code.name} for behavior '
                '"${b.id}" (strict mode).',
            ...result.message.split('\n'),
          ]);
          continue;
        }
        record(b.id, [
          'route: ${b.id} -> refused [${result.code.name}: '
              '${result.message.split('\n').first}]',
        ]);
        continue;
      }
      // RoutingUndeclared — the labeled legacy fallback.
      final hint = decision == BehaviorKind.widget
          ? 'add `**Type**: widget` to the scenario'
          : decision == BehaviorKind.acceptance
          ? 'add `**Type**: acceptance` to the scenario'
          : 'trace FR to a declared contract row';
      record(b.id, [
        'route: ${b.id} -> ${lane(decision)} '
            '[fallback: legacy description classifier matched — $hint]',
      ]);
    }
    for (final row in preservedFfi) {
      record(row.id, [
        'route: ${row.id} -> ffi lane '
            '[declared: native loop section]',
      ]);
    }
    return lines;
  }

  /// Bug #833: the plan MARKS the behavior persistence-kind — the
  /// ` [persistence]` tag makes `zfa tdd gen` generate the
  /// harness-backed test. Idempotent.
  ///
  /// Feature 071 (issue #951): the trigger is DECLARED — a `[persistent]`
  /// FR tag or a trace to a `storage:` dependency row (FR-006). The
  /// #833 keyword sniffing is retired entirely (spec AC2: storage
  /// vocabulary without a declaration stays unmarked — the keyword
  /// trigger was false-positive-prone by construction).
  String _marked(
    Behavior b,
    Map<String, PersistenceDeclaration> persistenceDeclarations,
  ) => persistenceDeclarations.containsKey(b.id)
      ? PersistenceMarker.mark(b.description)
      : b.description;

  /// Issue #1007: derive one CONTRACT behavior per declared method of
  /// the spec's Layer Contracts section — every entity method,
  /// controller method and usecase the spec declares (plus any other
  /// declared layer interface: a declared contract is a declared
  /// contract, whatever its layer label).
  ///
  /// The row's description is the STRUCTURED contract carrier the
  /// contract writers parse:
  ///
  ///     <Interface>.<method>(<params>) -> <Return> (<category>)
  ///
  /// and the traces column is the interface-qualified method name
  /// (`User.validateEmail`) — unique per declared method, stable across
  /// re-plans, and the reconciliation key for `contract:<id>` ids.
  List<Behavior> _deriveContractBehaviors(
    String feature,
    List<LayerContract> layerContracts,
    Set<String> entityNames,
  ) {
    final behaviors = <Behavior>[];
    for (final contract in layerContracts) {
      final category = _contractCategory(contract, entityNames);
      for (final method in contract.methods) {
        final methodName = _methodNameOf(method);
        if (methodName.isEmpty) continue;
        final traces = '${contract.interfaceName}.$methodName';
        behaviors.add(
          Behavior(
            id: 'contract:A${behaviors.length + 1}',
            feature: feature,
            kind: BehaviorKind.contract,
            description:
                '${contract.interfaceName}.$method ($category contract)',
            sourceCriterion: traces,
            target: TestListReader.resolveDefaultTarget(
              'contract:A${behaviors.length + 1}',
            ),
          ),
        );
      }
    }
    return behaviors;
  }

  /// The contract category for a declared layer interface: the layer
  /// label classifies it (Entities/Entity, Presentation/Controller,
  /// Domain/UseCase), with a declared Key Entity name winning for
  /// interfaces declared under another label. Everything else is a
  /// generic interface contract — still derived, still a contract row.
  String _contractCategory(LayerContract contract, Set<String> entityNames) {
    final layer = contract.layer.toLowerCase();
    if (layer.contains('entit')) return 'entity method';
    if (layer.contains('presentation') || layer.contains('controller')) {
      return 'controller method';
    }
    if (layer.contains('domain') ||
        layer.contains('usecase') ||
        layer.contains('use case')) {
      return 'usecase';
    }
    if (entityNames.contains(contract.interfaceName)) return 'entity method';
    return 'interface method';
  }

  /// The method name of a declared signature (`validateEmail(String) ->
  /// bool` -> `validateEmail`); empty when the declaration carries no
  /// callable name.
  static String _methodNameOf(String signature) {
    final idx = signature.indexOf('(');
    if (idx <= 0) return '';
    return signature.substring(0, idx).trim();
  }

  /// Issue #1007: reconcile freshly derived contract behaviors against
  /// the prior test list by TRACES — an unchanged spec keeps its
  /// `contract:<id>` ids stable (and a BLOCKED/DONE row keeps its
  /// recorded state), while new declarations take the next free id.
  List<Behavior> _reconcileContractBehaviors(
    List<Behavior> derived,
    Map<String, (String, BehaviorState)> prior,
  ) {
    final taken = prior.values.map((v) => v.$1).toSet();
    var counter = 1;
    String nextId() {
      while (taken.contains('contract:A$counter')) {
        counter++;
      }
      final id = 'contract:A$counter';
      taken.add(id);
      counter++;
      return id;
    }

    return [
      for (final b in derived)
        () {
          final match = prior[b.sourceCriterion];
          final id = match?.$1 ?? nextId();
          return Behavior(
            id: id,
            feature: b.feature,
            kind: b.kind,
            description: b.description,
            sourceCriterion: b.sourceCriterion,
            target: TestListReader.resolveDefaultTarget(id),
          )..state = match?.$2 ?? BehaviorState.pending;
        }(),
    ];
  }

  /// The lane resolution result (issue #1000): every behavior's lane,
  /// the hand-declared lane rows (ids the declarations carry but the
  /// spec prose does not derive), and the refusals (unknown lane names,
  /// undeclared derived behaviors, noFlutter violations).
  ///
  /// The refusals are surfaced by the caller BEFORE any artifact is
  /// written — an incomplete split never leaves a half-written lane
  /// plan.
  static const _flutterReference =
      'package:fl'
      'utter';

  _LaneResult _resolveLanes(
    List<LaneDeclaration> lanes,
    List<Behavior> expressible,
    List<BehaviorRow> preservedFfi,
  ) {
    final classification = <String, Lane>{};
    final annotations = <String, String>{};
    final refusals = <String>[];

    // Unknown lane names: the grammar is CORE/SKIN/BOTH.
    for (final lane in lanes) {
      final parsed = Lane.parse(lane.lane);
      if (parsed == null) {
        refusals.add(
          'lane "${lane.lane}" is not a known lane '
          '(CORE, SKIN, BOTH).',
        );
        continue;
      }
      for (final id in lane.behaviorIds) {
        // A later declaration for the same id wins (the last word is
        // the author's current intent).
        classification[id] = parsed;
        final note = lane.annotations[id];
        if (note != null) annotations[id] = note;
      }
    }

    // Undeclared derived behaviors: declarations win, gaps refuse —
    // never a silent default.
    final declaredHandIds = classification.keys.toSet();
    for (final b in expressible) {
      final lane = classification[b.id];
      if (lane == null) {
        refusals.add(
          'behavior "${b.id}" (${b.sourceCriterion}: '
          '"${b.description}") is declared in NO lane — every '
          'spec-derived behavior must appear in a `behaviors:` list.',
        );
        continue;
      }
      // noFlutter guard (issue #1000): a behavior destined for the
      // ENGINE plan may not reference Flutter — its row text lands in
      // 04-ENGINE.md, which is pure Dart by construction.
      final rowText = '${b.description} ${b.sourceCriterion}';
      if (lane.destinedForEngine && rowText.contains(_flutterReference)) {
        refusals.add(
          'noFlutter guard: behavior "${b.id}" (${b.sourceCriterion}) is '
          'lane ${lane.label} but references $_flutterReference — the '
          'engine lane is pure Dart. --> fix: move the behavior to the '
          'SKIN lane or drop the Flutter reference.',
        );
      }
      // A Flutter-only subject kind cannot be CORE: its gen pair
      // (testWidgets + view builder) imports Flutter.
      if (lane == Lane.core &&
          (b.kind == BehaviorKind.widget || b.kind == BehaviorKind.theme)) {
        refusals.add(
          'noFlutter guard: behavior "${b.id}" (${b.sourceCriterion}) is '
          'routed ${b.kind.name}-kind (a Flutter-only subject whose gen '
          'pair imports Flutter) but declared CORE. --> fix: declare it '
          'SKIN (or BOTH), or add `**Type**: acceptance` to the scenario.',
        );
      }
    }

    // Ffi rows default engine-side (the native boundary is engine
    // territory) unless a lane declares otherwise.
    for (final row in preservedFfi) {
      classification.putIfAbsent(row.id, () => Lane.core);
    }

    // Hand rows: ids the declarations carry but neither the spec prose
    // nor the prior list derives — the lane's own reservation (the
    // `W1-W4` skin slots), described by the lane annotation when the
    // author wrote one.
    final handRows = <LaneRow>[];
    final derivedIds = {
      ...expressible.map((b) => b.id),
      ...preservedFfi.map((r) => r.id),
    };
    for (final id in declaredHandIds.difference(derivedIds).toList()..sort()) {
      final lane = classification[id]!;
      final note = annotations[id];
      handRows.add(
        LaneRow(
          id: id,
          description: note == null || note.isEmpty
              ? '${lane.label.toLowerCase()} behavior declared in '
                    '`## Lanes`'
              : note,
          traces: 'LANE:${lane.label}',
          state: 'PENDING',
          // Hand rows take the lane's natural section: SKIN/BOTH hand
          // rows are widget-kind skin slots; CORE hand rows are
          // engine units; (a BOTH hand row renders under the widget
          // section — the seam's skin half is the visible half).
          kind: lane == Lane.core ? BehaviorKind.unit : BehaviorKind.widget,
          lane: lane,
        ),
      );
      classification[id] = lane;
    }

    return _LaneResult(
      classification: classification,
      handRows: handRows,
      refusals: refusals,
    );
  }

  /// The engine/skin plan row pair for a spec-derived behavior (issue
  /// #1000): CORE rows carry the persistence mark exactly like the
  /// legacy single-file plan; BOTH rows appear in both files (the
  /// reader dedupes by id, engine copy first).
  List<LaneRow> _derivedLaneRows(
    Behavior b,
    _LaneResult laneResult,
    Map<String, PersistenceDeclaration> persistenceDeclarations,
  ) {
    final lane = laneResult.classification[b.id];
    if (lane == null) return const [];
    return [
      LaneRow(
        id: b.id,
        description: _marked(b, persistenceDeclarations),
        traces: b.sourceCriterion,
        state: 'PENDING',
        kind: b.kind,
        lane: lane,
      ),
    ];
  }

  /// The preserved ffi rows as lane rows (default CORE — the native
  /// boundary is engine territory).
  List<LaneRow> _ffiLaneRows(
    List<BehaviorRow> preservedFfi,
    _LaneResult laneResult,
  ) => [
    for (final row in preservedFfi)
      LaneRow(
        id: row.id,
        description: row.description,
        traces: row.traces,
        state: row.state.name.toUpperCase(),
        kind: row.kind,
        lane: laneResult.classification[row.id] ?? Lane.core,
      ),
  ];
}

/// The plan-time lane resolution (issue #1000) — see
/// [PlanCommand._resolveLanes].
class _LaneResult {
  const _LaneResult({
    required this.classification,
    required this.handRows,
    required this.refusals,
  });

  /// Every behavior id -> its lane (derived + ffi + hand rows).
  final Map<String, Lane> classification;

  /// The hand-declared lane rows (ids the `## Lanes` section reserves
  /// that the spec prose does not derive).
  final List<LaneRow> handRows;

  /// The lane contract violations (unknown lane, undeclared behavior,
  /// noFlutter) — non-empty refuses the plan (exit 2, no artifacts).
  final List<String> refusals;
}
