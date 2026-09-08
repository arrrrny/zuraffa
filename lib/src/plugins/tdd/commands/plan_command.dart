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

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/lane.dart';
import '../models/routing.dart';
import '../services/finder_taxonomy.dart';
import '../services/feature_path_resolver.dart';
import '../services/i18n_key_contract.dart';
import '../services/explain_emitter.dart';
import '../services/lane_split.dart';
import '../services/routing_resolver.dart';
import '../services/requirement_scan.dart';
import '../services/spec_marker_emitter.dart';
import '../services/spec_migrator.dart';
import '../services/spec_parser.dart';
import '../services/platform_layout_contract.dart';
import '../services/platform_coverage_ledger.dart';
import '../services/test_list_reader.dart';
import '../services/tdd_generation_receipt.dart';
import '../services/ui_ledger_projection.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../services/skin_contract_emit.dart';
import '../../../tdd/services/ui_ledger_builder.dart';
import '../../../skin/contract/adaptive_skin_contract.dart';
import '../../../skin/contract/adaptive_skin_contract_parser.dart';
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
    argParser.addFlag('explain', help: kExplainFlagHelp, negatable: false);
    argParser.addFlag(
      'strict-routing',
      help:
          'Refuse undeclared routing intent instead of falling back to the '
          'legacy keyword classifiers. Undeclared behaviors exit 1 with the '
          'spec line and the declaration to add (feature 071, issue #951). '
          'Run a plain `zfa tdd plan` first (issue #1186): it emits the '
          'classified `**Type**` markers into the spec, so the strict gate '
          'passes on the re-run.',
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
    argParser.addFlag(
      'emit-markers',
      help:
          'Emit the classified `**Type**` lane markers back into the spec '
          'after a successful plan (issue #1186): the legacy classifier '
          'fallback becomes a one-time migration instead of a per-run '
          'warning, and `--strict-routing` becomes usable on '
          'speckit-authored specs. Pass `--no-emit-markers` to leave the '
          'spec untouched.',
      defaultsTo: true,
      negatable: true,
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'plan';

  @override
  String get description =>
      'Read <feature>/spec.md and emit <feature>/tdd/test-list.md (one '
      'behavior per criterion). <feature> is a plain specs/ feature name, '
      'a specs/<feature> path, a .specify/bugs/<slug> bug directory, or '
      'an absolute path (issue #1182).';

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
    final rawRef = rest.first;
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults?['project'] as String?;
    final repoRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    // Issue #1182: route the feature reference through the single TDD
    // feature resolver — a plain name keeps the legacy specs/ location, a
    // `specs/<name>`, `.specify/bugs/<slug>` or absolute reference resolves
    // to that directory directly (no symlink bridge needed). Artifacts
    // land BESIDE the resolved spec, and the "spec not found" error names
    // the resolved path.
    final resolved = TddFeaturePaths.resolve(
      projectRoot: repoRoot,
      featureRef: rawRef,
    );
    final feature = resolved.name;
    final featureDir = resolved.dir;
    final specPath = p.join(featureDir, 'spec.md');
    final specFile = File(specPath);
    if (!await specFile.exists()) {
      stderr.writeln('zfa tdd plan: spec not found at $specPath');
      // Issue #1182: the envelope carries the RESOLVED path — a tool
      // reading the verdict must see the path the command actually
      // referenced, not a specs/-relative guess.
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'spec-not-found'
        ..details['spec'] = specPath;
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

    // Issue #1141 (extending #965): the spec's i18n key contract is a
    // DECLARED contract — a malformed `key:` token refuses the plan
    // before any artifact is written (errors-are-an-API, the same
    // refusal gen/view apply), with the row named and the fix line.
    final I18nKeyTable i18nKeys;
    try {
      i18nKeys = I18nKeyTable.fromLayerContracts(layerContracts);
    } on I18nKeyContractParseException catch (error) {
      print('zfa tdd plan: i18n contract refused — ${error.message}');
      print('   no artifacts were written.');
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'i18n-contract'
        ..fix =
            'fix the malformed `key:` token in the Presentation layer '
            'contract, then re-run zfa tdd plan'
        ..details['spec'] = specPath;
      exitCode = 2;
      return;
    }

    // Issue #1142 (extending #1004/#1102): the platform layout contract
    // is a DECLARED contract — the Presentation table's
    // `adaptive_layouts` bullet. A malformed slot name refuses the plan
    // before any artifact is written (the same errors-are-an-API
    // discipline the i18n contract applies above).
    List<String> layoutSlots = const [];
    try {
      layoutSlots =
          PlatformLayoutContract.fromContracts(layerContracts)?.slots ??
          const [];
    } on PlatformLayoutContractException catch (error) {
      print('zfa tdd plan: layout contract refused — ${error.message}');
      print('   no artifacts were written.');
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'layout-contract'
        ..fix =
            'fix the malformed slot name in the `adaptive_layouts` '
            'Presentation bullet, then re-run zfa tdd plan'
        ..details['spec'] = specPath;
      exitCode = 2;
      return;
    }

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
      // Issue #1125: the refusal's explain block — the per-gap fix lines
      // the gate printed, and the honest no-artifacts receipt section.
      _verdict.explain = TddExplain(
        command: 'plan',
        features: [feature],
        lane: 'none — plan does not drive the engine/skin lanes',
        fixHints: [for (final gap in gaps) gap.fix],
        summary:
            'Plan refused $feature at the coverage gate (bug #846): '
            '${gaps.length} requirement statement(s) produce no '
            'behavior row (spec: '
            '${p.relative(specPath, from: repoRoot)}). No test list '
            'was written — an incomplete plan never emits an artifact '
            'that would silently claim completeness. Fix the named '
            'statements and re-run `zfa tdd plan`.',
      );
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

    final outDir = Directory(p.join(featureDir, 'tdd'));
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
        // Issue #1310: positional cell parse — the traces cell is the
        // second-to-last cell (the state cell is last) in both row
        // dialects this read serves: the 4-column
        // `| id | behavior | traces | state |` and the 5-column widget
        // dialect `| id | behavior | kind | traces | state |`. The key
        // is the cell's LEADING criterion token: the #1310 cell carries
        // the full trace set (`FR-001, TodoRepository.create`) while
        // the lookup below is by the behavior's sourceCriterion
        // (`FR-001`). A criterion-only cell (every pre-#1310 list)
        // keys identically, so old lists reconcile unchanged.
        final m = RegExp(r'^\|\s*([A|U]\d+)\s*\|(.+)\|\s*$').firstMatch(line);
        if (m == null) continue;
        final cells = m.group(2)!.split('|').map((c) => c.trim()).toList();
        if (cells.length < 3) continue; // id + traces + state minimum
        final id = m.group(1)!;
        final criterion = cells[cells.length - 2].split(',').first.trim();
        if (criterion.isEmpty) continue;
        existing[criterion] = Behavior(
          id: id,
          feature: feature,
          kind: id.startsWith('A')
              ? BehaviorKind.acceptance
              : BehaviorKind.unit,
          description: '',
          sourceCriterion: criterion,
          target: '',
        );
      }
    }

    // The rendered row may keep its historical test-list id, but spec
    // declarations and marker emission remain keyed by the parser's current
    // id. Preserve both through provenance resolution.
    final reconciledEntries = <({Behavior behavior, String currentId})>[];
    for (final b in behaviors) {
      final prior = existing[b.sourceCriterion];
      if (prior != null && prior.kind == b.kind) {
        reconciledEntries.add((
          behavior: Behavior(
            id: prior.id,
            feature: b.feature,
            kind: b.kind,
            description: b.description,
            sourceCriterion: b.sourceCriterion,
            target: b.target,
          ),
          currentId: b.id,
        ));
      } else {
        reconciledEntries.add((behavior: b, currentId: b.id));
      }
    }
    final reconciled = [for (final entry in reconciledEntries) entry.behavior];

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
      for (final row in await TestListReader(featureDir).read()) {
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
    final expressibleEntries = reconciledEntries
        .where((entry) => !ffiCriteria.contains(entry.behavior.sourceCriterion))
        .toList();
    final expressible = expressibleEntries
        .map((entry) => entry.behavior)
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
      expressibleEntries,
      preservedFfi,
      declarations,
      frTraces,
      scenarioMarkers,
      strict: strict,
    );
    // Issue #1310: the behavior's resolved contract-row names, keyed by
    // the emitted row id. frTraces is keyed by the parser's current
    // unit id; id reconciliation may have kept a historical row id, so
    // the pairing rides expressibleEntries (behavior <-> currentId).
    // The writers emit these names after the criterion id so the cell
    // carries the full trace set the declared-signature resolution
    // (DeclaredRouting.declaredSignatureFor, issue #1259) reads back.
    final contractTraces = <String, List<String>>{};
    for (final entry in expressibleEntries) {
      final tokens = frTraces[entry.currentId];
      if (tokens != null && tokens.isNotEmpty) {
        contractTraces[entry.behavior.id] = tokens;
      }
    }
    final provenanceLines = provenance.lines;
    // Strict gate (feature 071): a refusal writes no artifact.
    if (strict && provenanceLines.containsKey('__refused__')) {
      for (final line in provenanceLines.remove('__refused__')!) {
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
    // Bug #1261: the SKIN lanes' golden declarations resolved to behavior
    // ids — the set the plan marks onto the SKIN lane rows (the ` [golden]`
    // tag gen reads). Non-SKIN lanes' golden declarations refuse below.
    final goldenIds = <String>{
      for (final lane in lanes)
        if (Lane.parse(lane.lane) == Lane.skin) ...lane.goldenIds,
    };
    // Issue #1309: stale-split detection. A feature migrated by `zfa
    // tdd split` carries `tdd/split-receipt.json`; when its spec
    // declares NO `## Lanes`, the legacy single-file path below would
    // rewrite only test-list.md (demoting the meta-index) and leave
    // the lane plans stale — ghost behaviors (deleted FRs) run, new
    // FRs are missed — while `zfa tdd split` refuses with "already
    // split". The two commands' guidance deadlocked. When a receipt
    // exists, plan keeps the split shape: the lane plans are
    // REGENERATED from the current behavior set through the same kind
    // heuristic the split applies, and a spec changed since the receipt
    // was written (digest, or mtime for legacy receipts) is reported
    // as a stale split before the regenerated files are written.
    final receiptFile = File(p.join(outDir.path, LaneSplitFiles.receipt));
    final splitReceiptExists = await receiptFile.exists();
    final splitReceipt = splitReceiptExists
        ? await _readSplitReceipt(receiptFile)
        : null;
    final splitStale =
        splitReceiptExists &&
        lanes.isEmpty &&
        await _splitReceiptIsStale(
          receipt: splitReceipt,
          receiptFile: receiptFile,
          specFile: specFile,
          specMd: specMd,
        );
    final declaredBehaviorIds = <String>{
      for (final entry in expressibleEntries)
        if (scenarioMarkers.containsKey(entry.currentId)) entry.behavior.id,
    };
    final laneResult = lanes.isEmpty
        ? (splitReceiptExists
              ? _heuristicLaneResolution(expressible, preservedFfi)
              : null)
        : _resolveLanes(
            lanes,
            expressible,
            preservedFfi,
            goldenIds,
            // Issue #1318: the guard's fix message distinguishes a
            // CLASSIFIER-routed kind (a prose guess — the marker remedy
            // leads) from a DECLARED kind (the author's word — the
            // lane-move remedy stands). Match declarations by the parser's
            // current ids, then pass the reconciled behavior ids consumed by
            // the lane resolver.
            declaredBehaviorIds: declaredBehaviorIds,
          );
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

    // Issue #1004: the skin contract. A spec declaring the adaptive
    // `## Skin Contract` section (yaml body) gets typed contract rows
    // in 04-SKIN.md: the platform matrix, the state machine, the
    // routes — plus the machine JSON contract. The parse is strict
    // (an unknown key is contract drift, not future proofing) and a
    // declaration without the lane split refuses: the contract rides
    // the SKIN lane, and a legacy single-file plan has no skin file
    // to referee against.
    final adaptiveSkinContract = _resolveSkinContract(specMd, lanes, specPath);
    if (identical(adaptiveSkinContract, _skinContractRefused)) {
      return;
    }

    // Bug #1261: the visual-contract guidance. A SKIN lane with
    // widget-kind behaviors but no adaptive_slots gets the slot
    // PROPOSAL (the spec stays the source of truth — plan proposes,
    // the author declares); a lane with neither slots nor goldens
    // warns that the skin has no visual contract — the silent
    // fall-through the bug closes, surfaced instead. Guidance only:
    // the artifacts still write and the exit stays 0.
    if (laneResult != null) {
      _emitVisualContractGuidance(
        lanes: lanes,
        laneResult: laneResult,
        expressible: expressible,
      );
    }

    // Issue #1007: contract rows carry their own declared lane in the
    // provenance artifact (they are spec-DECLARED through the Layer
    // Contracts section, like the ffi lane's native-loop declaration).
    for (final b in contractBehaviors) {
      provenanceLines.putIfAbsent(
        b.id,
        () => [
          'route: ${b.id} -> contract lane '
              '[declared: layer contracts section]',
        ],
      );
    }

    // Issue #1186: the one-time routing migration. Every behavior that
    // routed via the labeled legacy fallback had its lane classified by
    // the (accurate) description classifier — emitting the classified
    // `**Type**` marker back into the spec turns the per-run fallback
    // warning into a one-time migration, and makes `--strict-routing`
    // usable on speckit-authored specs (whose templates never carried
    // the markers). The emitted content stays in memory until every plan
    // artifact has been written successfully, so an output failure never
    // leaves spec.md migrated ahead of an incomplete plan. The operation is
    // idempotent (a declared scenario is never re-declared) and is skipped
    // entirely under `--no-emit-markers`.
    final markerEmission = argResults?['emit-markers'] as bool? ?? true
        ? const SpecMarkerEmitter().emit(specMd, provenance.fallbackKinds)
        : null;

    Future<void> persistMarkerEmission() async {
      final emission = markerEmission;
      if (emission == null || !emission.migrated) return;
      await specFile.writeAsString(emission.content);
      print(
        'zfa tdd plan: emitted ${emission.emitted.length} `**Type**` '
        'marker(s) into the spec — one-time routing migration (issue '
        '#1186) for ${emission.emitted.keys.join(', ')} (spec: '
        '$specPath). Re-run `zfa tdd plan`; the migrated scenarios now '
        'carry their declared lane.',
      );
      _verdict.details['markers_emitted'] = emission.emitted.length;
    }

    await outDir.create(recursive: true);
    // Issue #1164: a spec declaring `## Skin Contract:` also emits the
    // model-generated `04-skin-contract.schema.json` beside the lane
    // plan — generated FROM the typed model so the two cannot drift.
    // A spec without the section writes nothing.
    final emittedSchema = await emitSkinContractSchema(
      specMarkdown: specMd,
      outDir: outDir,
    );
    if (emittedSchema != null) {
      print(
        'zfa tdd plan: wrote File: ${p.absolute(emittedSchema)} '
        '(skin contract schema — issue #1164)',
      );
    }
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
      // Issue #1309: the stale-split report. Printed only when the plan
      // actually proceeds to write artifacts (every gate has passed),
      // so a refused plan never claims it refreshed anything.
      if (splitStale) {
        print(
          'zfa tdd plan: stale lane split detected — spec.md changed '
          'since ${p.relative(receiptFile.path, from: repoRoot)} was '
          'written; regenerating the lane plans from the current '
          'behavior set (issue #1309).',
        );
        _verdict.details['stale_split'] = true;
      }
      // Issue #1000: the lane split — engine plan + skin plan + the
      // engine/skin contract, with the legacy filename demoted to the
      // meta-index. TestListReader resolves the rows from the split
      // files, so gen/make/run semantics are unchanged.
      final engineRows = <LaneRow>[
        for (final b in expressible)
          ..._derivedLaneRows(
            b,
            laneResult,
            declarations.persistence,
            goldenIds,
            contractTraces,
          ),
        ..._ffiLaneRows(preservedFfi, laneResult),
        ...laneResult.handRows,
      ].where((r) => r.lane.destinedForEngine).toList();
      final skinRows = <LaneRow>[
        for (final b in expressible)
          ..._derivedLaneRows(
            b,
            laneResult,
            declarations.persistence,
            goldenIds,
            contractTraces,
          ),
        ..._ffiLaneRows(preservedFfi, laneResult),
        ...laneResult.handRows,
      ].where((r) => r.lane.destinedForSkin).toList();
      final adaptiveSlots = lanes
          .expand((l) => l.adaptiveSlots)
          .toSet()
          .toList();

      final engineProvenance = <String, List<String>>{};
      final skinProvenance = <String, List<String>>{};
      provenanceLines.forEach((id, lines) {
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
        skinContract: adaptiveSkinContract,
      );
      final contractMd = renderContractPlan(
        feature: feature,
        adaptiveSlots: adaptiveSlots,
        bothRows: engineRows.where((r) => r.lane == Lane.both).toList(),
      );
      final metaLanes = lanes.isNotEmpty
          ? lanes
          : [
              // Issue #1309: a no-Lanes regeneration synthesizes the
              // meta-index declarations from the derived rows — the
              // same shape `zfa tdd split` writes when the spec
              // declares no lanes (the heuristic split is CORE for the
              // engine rows, SKIN for the skin rows, and the heuristic
              // never yields BOTH).
              LaneDeclaration(
                lane: Lane.core.label,
                behaviorIds: engineRows
                    .where((r) => r.lane == Lane.core)
                    .map((r) => r.id)
                    .toList(),
                flutterAllowed: 'false',
              ),
              LaneDeclaration(
                lane: Lane.skin.label,
                behaviorIds: skinRows
                    .where((r) => r.lane == Lane.skin)
                    .map((r) => r.id)
                    .toList(),
                flutterAllowed: 'true',
              ),
            ];
      final metaMd = renderMetaIndex(
        feature: feature,
        lanes: metaLanes,
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
      for (final line in provenanceLines.values.expand((l) => l)) {
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
      // Issue #1141: the UI surface ledger artifact — one row per
      // declared surface, `t.<key>` key rows traced per row (both lanes'
      // rows feed the single feature-wide derivation).
      await _writeUiLedger(
        outDir,
        behaviors: [
          for (final row in [...engineRows, ...skinRows])
            LedgerBehaviorInput(id: row.id, description: row.description),
        ],
        componentTokens: UiLedgerProjection.componentTokensOf(layerContracts),
        keys: i18nKeys,
        layoutSlots: layoutSlots,
      );
      await persistMarkerEmission();
      if (splitReceiptExists) {
        // Issue #1309: refresh only after every generated artifact and
        // marker emission succeeded. Hash and mtime come from the final
        // on-disk spec, so marker migration cannot make the repaired
        // receipt immediately stale. A malformed existing receipt is
        // rebuilt with the current heuristic classification instead of
        // demoting this run to the legacy single-file plan.
        final finalSpecMd = await specFile.readAsString();
        final refreshed = splitReceipt == null
            ? <String, dynamic>{
                'feature': feature,
                'source': 'tdd/test-list.md',
                'rows': laneResult.classification.length,
                'classification': {
                  for (final entry in laneResult.classification.entries)
                    entry.key: entry.value.label,
                },
              }
            : <String, dynamic>{...splitReceipt};
        refreshed
          ..['spec_hash'] = sha256.convert(utf8.encode(finalSpecMd)).toString()
          ..['spec_mtime'] = (await specFile.lastModified())
              .toUtc()
              .toIso8601String()
          ..['refreshed_at'] = DateTime.now().toUtc().toIso8601String()
          ..['refreshed_by'] = 'zfa tdd plan'
          ..['refreshed_rows'] = laneResult.classification.length;
        await receiptFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(refreshed),
        );
      }
      // Issue #1125: the laned plan's explain block — the lane split is
      // the artifact set here, the summary names exactly what was written.
      _verdict.explain = TddExplain(
        command: 'plan',
        features: [feature],
        lane: 'none — plan does not drive the engine/skin lanes',
        summary:
            'Plan parsed ${p.relative(specPath, from: repoRoot)} (template '
            '$templateVersion), proved the coverage gate, and split the '
            'plan into lanes: '
            '${p.relative(p.join(outDir.path, LaneSplitFiles.engine), from: repoRoot)} '
            '(${engineRows.where((r) => r.lane == Lane.core).length} CORE '
            'behaviors), '
            '${p.relative(p.join(outDir.path, LaneSplitFiles.skin), from: repoRoot)} '
            '(${skinRows.where((r) => r.lane == Lane.skin).length} SKIN '
            'behaviors), the engine/skin contract plan, and the '
            'meta-index test-list.md '
            '(${laneResult.classification.length} behaviors, '
            '${engineRows.where((r) => r.lane == Lane.both).length} BOTH), '
            'with the traceability matrix beside them. Next: '
            '`zfa tdd run $feature` drives the engine lane first.',
      );
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
        provenanceLines,
        contractTraces,
      ),
    );
    // Issue #1141: the UI surface ledger artifact (the legacy single-file
    // plan path derives from the same row set the test list carries).
    final ledgerFiles = await _writeUiLedger(
      outDir,
      behaviors: [
        for (final b in [...expressible, ...contractBehaviors])
          LedgerBehaviorInput(id: b.id, description: b.description),
        for (final row in preservedFfi)
          LedgerBehaviorInput(id: row.id, description: row.description),
      ],
      componentTokens: UiLedgerProjection.componentTokensOf(layerContracts),
      keys: i18nKeys,
      layoutSlots: layoutSlots,
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
        ...ledgerFiles,
      },
    );
    await persistMarkerEmission();
    for (final line in provenanceLines.values.expand((l) => l)) {
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
    // Issue #1125: the plan's explain block — the sections reuse the
    // receipt record the verb just wrote (TddGenerationReceipts) and the
    // artifacts the summary line names, never fresh facts.
    _verdict.explain = TddExplain(
      command: 'plan',
      features: [feature],
      lane: 'none — plan does not drive the engine/skin lanes',
      receipts: [
        '1 proof.v1 generation receipt for tdd plan (under '
            '.zfa/receipts/, best effort)',
      ],
      summary:
          'Plan parsed ${p.relative(specPath, from: repoRoot)} (template '
          '$templateVersion), proved the coverage gate — every '
          'requirement statement maps to a behavior row — and wrote '
          '${p.relative(outFile.path, from: repoRoot)} with $laneList '
          'behaviors ($total total) plus the traceability matrix '
          '(tdd/traceability.md). Next: `zfa tdd run $feature` drives '
          'the behaviors red → green.',
    );
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
    Map<String, List<String>> contractTraces,
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
        '| ${b.id} | ${_marked(b, persistenceDeclarations)} | '
        '${_tracesCell(b, contractTraces)} | PENDING |',
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
      ..writeln(
        'The `kind` cell is the finder-kind taxonomy (issue #1140): the '
        'scenario verbs\' predicted assertion classes — presence, absence, '
        'route-outcome, enabled-state, sequence — or `none` when no finder '
        'is derivable. `zfa tdd gen` selects the assertion template by it '
        'and refuses a row whose kind column drifted from the scenario '
        'prose; verify-red\'s kind gate (issue #959/#964) certifies on the '
        'same vocabulary.',
      )
      ..writeln()
      ..writeln('| id | behavior | kind | traces | state |')
      ..writeln('| -- | -------- | ---- | ------ | ----- |');
    for (final b in widget) {
      // Issue #1140: the finder-kind column — the plan's prediction of
      // the assertion classes gen will emit, derived from the same
      // taxonomy the writer and the verify-red gate speak.
      final kindCell = FinderTaxonomy.kindCellFor(b.description);
      buf.writeln(
        '| ${b.id} | ${b.description} | $kindCell | '
        '${_tracesCell(b, contractTraces)} | PENDING |',
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
        '| ${b.id} | ${_marked(b, persistenceDeclarations)} | '
        '${_tracesCell(b, contractTraces)} | PENDING |',
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
          // Bug #919 (fixed by #1141): every method stays BACKTICKED so
          // TestListReader.readLayerContracts round-trips the contract —
          // the reader's extraction is backtick-based, and the unbackticked
          // rendering dropped the whole contract (components + key: tokens)
          // on the plan → test-list leg of the loop.
          buf.writeln(
            '- `${c.interfaceName}`: '
            '${c.methods.map((m) => '`$m`').join(', ')}',
          );
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

  /// Issue #1141: derive and write the UI surface ledger artifact pair
  /// (`tdd/ui-ledger.md` + `tdd/ui-ledger.json`) — one row per declared
  /// surface: text/route/affordance rows from the behavior scenarios and
  /// the Presentation component tokens, `t.<key>` key rows whose provers
  /// are the behaviors quoting the anchor. Planned provers are NOT-DONE
  /// at plan time (state recomputes on read — a stored state is a cache,
  /// never the truth). Issue #1142: when the Presentation contract
  /// declares platform layout slots, the ledger additionally renders the
  /// PER-PLATFORM coverage (surfaces × slots, plan-time evidence empty ⇒
  /// every per-slot row NOT-DONE — visible, never omitted) and the
  /// per-platform kind-coverage heatmap. Returns the written paths (for
  /// the plan's digest-bound receipts).
  Future<Map<String, String>> _writeUiLedger(
    Directory outDir, {
    required List<LedgerBehaviorInput> behaviors,
    required List<String> componentTokens,
    required I18nKeyTable keys,
    List<String> layoutSlots = const [],
  }) async {
    final rows = UiLedgerProjection.rows(
      behaviors: behaviors,
      keys: keys,
      componentTokens: componentTokens,
    );
    final mdBody = UiLedgerBuilder.toMarkdown(rows);
    final platformRows = layoutSlots.isEmpty
        ? const <PlatformSurfaceRow>[]
        : PlatformCoverageLedger.derive(aggregate: rows, slots: layoutSlots);
    final md = layoutSlots.isEmpty
        ? mdBody
        : '$mdBody\n${PlatformCoverageLedger.toMarkdown(platformRows)}';
    final json = layoutSlots.isEmpty
        ? UiLedgerBuilder.toJson(rows)
        : jsonEncode([
            ...jsonDecode(UiLedgerBuilder.toJson(rows)) as List<dynamic>,
            ...jsonDecode(PlatformCoverageLedger.toJson(platformRows))
                as List<dynamic>,
          ]);
    final mdPath = p.join(outDir.path, 'ui-ledger.md');
    final jsonPath = p.join(outDir.path, 'ui-ledger.json');
    await File(mdPath).writeAsString(md);
    await File(jsonPath).writeAsString(json);
    final keyRows = rows.where((r) => r.kind == UiSurfaceKind.key).length;
    final platformNote = layoutSlots.isEmpty
        ? ''
        : ', ${layoutSlots.length} platform slot(s) heatmap (issue #1142)';
    print(
      'zfa tdd plan: wrote $mdPath (${rows.length} row(s), '
      '$keyRows key row(s)$platformNote) — the UI surface ledger '
      '(issue #1141)',
    );
    return {mdPath: 'update', jsonPath: 'update'};
  }

  /// Bug #1261: the visual-contract guidance, printed per SKIN lane
  /// after the lane contract resolves. Widget-kind behaviors without
  /// adaptive_slots get the slot PROPOSAL (plan proposes — the spec
  /// stays the source of truth); a lane with neither slots nor goldens
  /// additionally warns that the skin has no visual contract — the
  /// silent generic-path fall-through issue #1261 closes. Guidance
  /// never refuses: the plan artifacts still write, exit stays 0.
  void _emitVisualContractGuidance({
    required List<LaneDeclaration> lanes,
    required _LaneResult laneResult,
    required List<Behavior> expressible,
  }) {
    final widgetIds = <String>{
      for (final b in expressible)
        if (b.kind == BehaviorKind.widget) b.id,
      for (final row in laneResult.handRows)
        if (row.kind == BehaviorKind.widget) row.id,
    };
    for (final lane in lanes) {
      if (Lane.parse(lane.lane) != Lane.skin) continue;
      final widgetInLane = lane.behaviorIds.where(widgetIds.contains).toList();
      if (widgetInLane.isEmpty) continue;
      if (lane.adaptiveSlots.isEmpty) {
        print(
          'zfa tdd plan: SKIN lane declares widget behaviors '
          '(${widgetInLane.join(', ')}) without adaptive_slots — '
          'proposing adaptive_slots: [mobile, ios, android, macos] '
          '(declare them in the `## Lanes` SKIN row; the hand-skin '
          'conformance cycle, spec 1005, engages when slots are '
          'declared).',
        );
      }
      if (lane.adaptiveSlots.isEmpty && lane.goldenIds.isEmpty) {
        print(
          'zfa tdd plan: WARNING — this skin has no visual contract: '
          'the SKIN lane\'s widget behaviors '
          '(${widgetInLane.join(', ')}) declare neither adaptive_slots '
          'nor golden. Visual parity is unrepresentable and run-skin '
          'falls through to the generic path. --> fix: declare '
          '`adaptive_slots: [...]` or `golden: true` in the `## Lanes` '
          'SKIN row.',
        );
      }
    }
  }

  /// The refusal sentinel [_resolveSkinContract] returns when the
  /// skin contract refused the plan (the command already printed the
  /// fix lines and set the exit code — the caller just returns).
  static const AdaptiveSkinContract _skinContractRefused = AdaptiveSkinContract(
    adaptiveSlots: <String>[],
    platformOverrides: <String, Map<String, String>>{},
    states: <String>[],
    routeNames: <String>[],
  );

  /// Issue #1004: resolves the spec's adaptive `## Skin Contract`
  /// declaration. Returns the parsed contract (null when the spec
  /// declares none — including the json-fenced skin-contract.v1 form,
  /// issue #1164, which the schema emitter owns), or the
  /// [_skinContractRefused] sentinel after printing a refusal (exit 2,
  /// no artifacts — errors are an API, the fix line names the drift).
  AdaptiveSkinContract? _resolveSkinContract(
    String specMd,
    List<LaneDeclaration> lanes,
    String specPath,
  ) {
    final AdaptiveSkinContract? parsed;
    try {
      parsed = parseAdaptiveSkinContract(specMd);
    } on AdaptiveSkinContractParseException catch (e) {
      print('zfa tdd plan: skin contract refused — ${e.message}');
      print('  (spec: $specPath). No test list was written.');
      print(
        '  --> fix: correct the `## Skin Contract` yaml section named '
        'above, then re-run `zfa tdd plan`.',
      );
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'skin-contract-refused'
        ..fix =
            'fix the `## Skin Contract` section named in the refusal, '
            'then re-run zfa tdd plan'
        ..details['reason'] = e.message;
      exitCode = 2;
      return _skinContractRefused;
    }
    if (parsed == null) return null;
    final contract = parsed;

    // The contract rides the SKIN lane: a declaration without the
    // lane split has no skin plan to referee against.
    if (lanes.isEmpty) {
      print(
        'zfa tdd plan: skin contract refused — the `## Skin Contract` '
        'section declares a skin contract, but the spec declares no '
        '`## Lanes` section (spec: $specPath). The contract rides the '
        'SKIN lane: without the lane split there is no 04-SKIN.md to '
        'referee. No test list was written.',
      );
      print(
        '  --> fix: declare `## Lanes` (CORE/SKIN/BOTH) alongside the '
        'Skin Contract, or drop the `## Skin Contract` section; re-run '
        '`zfa tdd plan`.',
      );
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'skin-contract-without-lanes'
        ..fix =
            'declare `## Lanes` alongside `## Skin Contract`, then '
            're-run zfa tdd plan'
        ..details['lanes'] = 0;
      exitCode = 2;
      return _skinContractRefused;
    }

    // The adaptive_slots cross-check (issue #1004): the contract's
    // platform matrix and the SKIN lane's declared slots are the SAME
    // declaration in two places — a disagreement is drift naming both
    // sides, never a silent winner.
    final laneSlots = lanes
        .where((l) => l.lane.toUpperCase() == 'SKIN')
        .expand((l) => l.adaptiveSlots)
        .toSet();
    if (laneSlots.isNotEmpty) {
      final contractSlots = contract.adaptiveSlots.toSet();
      final drift =
          laneSlots.length != contractSlots.length ||
          !laneSlots.containsAll(contractSlots);
      if (drift) {
        print(
          'zfa tdd plan: skin contract refused — adaptive_slots drift: '
          'the `## Skin Contract` declares '
          '[${contract.adaptiveSlots.join(', ')}] but the SKIN lane '
          'declares [${laneSlots.join(', ')}] (spec: $specPath). The '
          'contract and the lane must declare the same platform '
          'matrix. No test list was written.',
        );
        print(
          '  --> fix: align `adaptive_slots` in `## Skin Contract` and '
          'the SKIN lane\'s `adaptive_slots`; re-run `zfa tdd plan`.',
        );
        _verdict
          ..outcome = VerdictOutcome.fail
          ..exitClass = 'skin-contract-slot-drift'
          ..fix =
              'align adaptive_slots between `## Skin Contract` and the '
              'SKIN lane, then re-run zfa tdd plan'
          ..details['contract_slots'] = contract.adaptiveSlots.length
          ..details['lane_slots'] = laneSlots.length;
        exitCode = 2;
        return _skinContractRefused;
      }
    }
    return contract;
  }

  /// Feature 071 (issue #951): the per-behavior routing provenance —
  /// the resolver consults the parsed declarations; undeclared
  /// behaviors render their LABELED legacy fallback (migration window;
  /// strict mode turns these into refusals).
  ///
  /// Issue #1186: the fallback-routed behaviors' classified kinds also
  /// come back (`fallbackKinds`, id → kind) so the plan can MIGRATE the
  /// emittable ones (`**Type**` markers) into the spec post-derivation
  /// — the one-time migration that makes the per-run fallback noise (and
  /// the strict gate's refusal on speckit-authored specs) disappear.
  ({Map<String, List<String>> lines, Map<String, BehaviorKind> fallbackKinds})
  _provenanceLines(
    List<({Behavior behavior, String currentId})> behaviors,
    List<BehaviorRow> preservedFfi,
    SpecDeclarations declarations,
    Map<String, List<String>> frTraces,
    Map<String, ScenarioDeclaration> scenarioMarkers, {
    bool strict = false,
  }) {
    const resolver = RoutingResolver();
    final lines = <String, List<String>>{};
    final fallbackKinds = <String, BehaviorKind>{};
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

    for (final entry in behaviors) {
      final b = entry.behavior;
      final currentId = entry.currentId;
      // Rung-3 kind for spec-parsed behaviors is DECLARED only via the
      // `**Type**` marker — the parse-time sniffer kind is precisely the
      // legacy fallback being labeled, so it is NOT passed as declared.
      final result = resolver.resolve(
        row: RoutingRow(
          behaviorId: currentId,
          kind: scenarioMarkers[currentId]?.declaredType,
          traces: frTraces[currentId] ?? const [],
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
      fallbackKinds[currentId] = decision;
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
    return (lines: lines, fallbackKinds: fallbackKinds);
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
    Set<String> goldenIds, {
    Set<String> declaredBehaviorIds = const {},
  }) {
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

    // Bug #1261: the golden gate is a SKIN-lane, widget-only surface.
    // Drift refuses at plan time — the same fail-fast the noFlutter
    // guard applies to the engine boundary (declarations win, inert
    // declarations are never silently carried).
    final derivedKinds = {for (final b in expressible) b.id: b.kind};
    for (final lane in lanes) {
      final parsed = Lane.parse(lane.lane);
      if (parsed == null || lane.goldenIds.isEmpty) continue;
      if (parsed != Lane.skin) {
        refusals.add(
          'lane ${parsed.label} declares golden: '
          '[${lane.goldenIds.join(', ')}] — the golden gate is a SKIN '
          'lane declaration (a golden hook in an engine-side test is '
          'nonsense). --> fix: move the `golden:` declaration to the '
          'SKIN lane row.',
        );
        continue;
      }
      final undeclared = lane.goldenIds
          .where((id) => !lane.behaviorIds.contains(id))
          .toList();
      if (undeclared.isNotEmpty) {
        refusals.add(
          'golden drift: the SKIN lane declares golden: '
          '[${undeclared.join(', ')}] but those ids are not in the '
          'lane\'s `behaviors:` list. --> fix: name only behaviors the '
          'SKIN lane declares, or use `golden: true`.',
        );
      }
      for (final id in lane.goldenIds) {
        // A hand-declared id (no derived kind) is widget-kind by
        // construction (SKIN hand rows render the widget section).
        final kind = derivedKinds[id];
        if (kind != null && kind != BehaviorKind.widget) {
          refusals.add(
            'golden: "$id" is ${kind.name}-kind — the golden gate is '
            'widget-only (bug #830: a golden hook in a plain-function '
            'test is nonsense). --> fix: declare `golden:` only for '
            'widget-kind behaviors (use the list form `golden: [W1, '
            'W2]` when the lane mixes kinds).',
          );
        }
      }
    }

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
        // Issue #1318: a CLASSIFIER-routed kind is a prose guess, so the
        // remedy LEADS with the marker (pre-#1318 it was buried as the
        // third option). A DECLARED kind is the author's word — the
        // marker remedy would second-guess an explicit declaration, so
        // the lane-move remedy stands byte-for-byte.
        final classifierRouted = !declaredBehaviorIds.contains(b.id);
        refusals.add(
          classifierRouted
              ? 'noFlutter guard: behavior "${b.id}" '
                    '(${b.sourceCriterion}) is routed ${b.kind.name}-kind '
                    '(a Flutter-only subject whose gen pair imports '
                    'Flutter) but declared CORE. --> fix: add **Type**: '
                    'acceptance to the scenario (classifier guess, not a '
                    'declaration).'
              : 'noFlutter guard: behavior "${b.id}" '
                    '(${b.sourceCriterion}) is routed ${b.kind.name}-kind '
                    '(a Flutter-only subject whose gen pair imports '
                    'Flutter) but declared CORE. --> fix: declare it SKIN '
                    '(or BOTH), or add `**Type**: acceptance` to the '
                    'scenario.',
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
          // Bug #1261: a SKIN lane's golden declaration rides the hand
          // row too (hand SKIN rows are widget-kind by construction).
          golden: goldenIds.contains(id) && lane != Lane.core,
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

  /// Issue #1309: the split receipt JSON at [receiptFile], or null when
  /// the file carries no parseable JSON object. Callers track existence
  /// independently so a corrupt receipt still selects split recovery.
  static Future<Map<String, dynamic>?> _readSplitReceipt(
    File receiptFile,
  ) async {
    try {
      final decoded = jsonDecode(await receiptFile.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException catch (_) {
      return null;
    } on FileSystemException catch (_) {
      return null;
    }
  }

  /// Issue #1309: whether the spec changed since the split receipt was
  /// written. The recorded `spec_hash` is authoritative (content, not
  /// timestamps); a legacy receipt — written before #1309 added the
  /// hash fields — falls back to the spec mtime vs the receipt's
  /// `split_at` timestamp, then to the receipt file's own mtime. When
  /// no signal is available the receipt is treated as fresh (fail
  /// closed: the legacy path's meta-index demotion is exactly the
  /// behavior this detection exists to prevent).
  static Future<bool> _splitReceiptIsStale({
    required Map<String, dynamic>? receipt,
    required File receiptFile,
    required File specFile,
    required String specMd,
  }) async {
    final currentHash = sha256.convert(utf8.encode(specMd)).toString();
    final receiptHash = receipt?['spec_hash'];
    if (receiptHash is String && receiptHash.isNotEmpty) {
      return receiptHash != currentHash;
    }
    final specModified = await specFile.exists()
        ? await specFile.lastModified()
        : null;
    if (specModified == null) return false;
    final splitAt = DateTime.tryParse('${receipt?['split_at'] ?? ''}');
    if (splitAt != null) {
      return specModified.isAfter(splitAt.toUtc());
    }
    try {
      return specModified.isAfter((await receiptFile.lastModified()).toUtc());
    } on FileSystemException {
      return false;
    }
  }

  /// Issue #1309: the split kind heuristic — the SAME rule
  /// `SplitCommand._heuristic` applies — over the CURRENT spec
  /// derivation: widget/theme rows are SKIN (their gen pair imports
  /// Flutter), everything else CORE; the preserved ffi rows are
  /// engine-side (the native boundary is engine territory). No hand
  /// rows and no refusals: with no `## Lanes` declarations there is
  /// nothing hand-reserved and nothing to refuse.
  _LaneResult _heuristicLaneResolution(
    List<Behavior> expressible,
    List<BehaviorRow> preservedFfi,
  ) {
    final classification = <String, Lane>{
      for (final b in expressible)
        b.id: b.kind == BehaviorKind.widget || b.kind == BehaviorKind.theme
            ? Lane.skin
            : Lane.core,
      for (final row in preservedFfi) row.id: Lane.core,
    };
    return _LaneResult(
      classification: classification,
      handRows: const [],
      refusals: const [],
    );
  }

  /// Issue #1310: the full trace set for a behavior row's traces cell
  /// — the criterion id first, then the behavior's resolved
  /// contract-row names (`frTraces[currentId]`), comma-separated. A
  /// token equal to the criterion id is dropped (no self-duplicates),
  /// and a behavior with no resolved names keeps the criterion-only
  /// cell — the pre-#1310 shape, the fallback path acceptance
  /// criterion 4 pins. The shape is exactly what TestListReader reads
  /// positionally and what RoutingResolver / make tokenize via
  /// SpecParser.traceTokens (`FR-001, Formatter.format`).
  String _tracesCell(Behavior b, Map<String, List<String>> contractTraces) {
    final names = contractTraces[b.id] ?? const <String>[];
    final extra = names.where((t) => t.trim() != b.sourceCriterion).toList();
    if (extra.isEmpty) return b.sourceCriterion;
    return '${b.sourceCriterion}, ${extra.join(', ')}';
  }

  /// The engine/skin plan row pair for a spec-derived behavior (issue
  /// #1000): CORE rows carry the persistence mark exactly like the
  /// legacy single-file plan; BOTH rows appear in both files (the
  /// reader dedupes by id, engine copy first).
  List<LaneRow> _derivedLaneRows(
    Behavior b,
    _LaneResult laneResult,
    Map<String, PersistenceDeclaration> persistenceDeclarations,
    Set<String> goldenIds,
    Map<String, List<String>> contractTraces,
  ) {
    final lane = laneResult.classification[b.id];
    if (lane == null) return const [];
    return [
      LaneRow(
        id: b.id,
        description: _marked(b, persistenceDeclarations),
        // Issue #1310: the full trace set — criterion id + the resolved
        // contract-row names — so the lane plan carries the same shape
        // the test list does and the declared-signature path is
        // reachable from the split files too.
        traces: _tracesCell(b, contractTraces),
        state: 'PENDING',
        kind: b.kind,
        lane: lane,
        // Bug #1261: a SKIN lane's golden declaration marks the row —
        // the ` [golden]` tag gen reads. The gate is widget-only; the
        // non-widget drift already refused above.
        golden: goldenIds.contains(b.id) && b.kind == BehaviorKind.widget,
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
