/// `zfa tdd ingest <feature> --draft <path>` — the draft validation gate
/// of the dream loop (spec 1010-zfa-dream-one-command-app, FR-002).
///
/// Ingest validates a DRAFT spec through the same parser/gate chain
/// `zfa tdd plan` uses — the template-version treaty pin (bug #919),
/// behavior derivation, the coverage gate (bug #846), the undeclared-
/// dependency lint (bug #919), and the declaration refusal (feature
/// 071) — with the SAME verdicts (exit 3 / exit 2, `--> fix:` lines, no
/// artifacts), plus the dream-specific gates:
///
/// - **entity name collision** — an entity named twice in the Key
///   Entities table, or an entity colliding with the framework export
///   surface (the bug #942 trap: `FrameworkExportSurface`), refused with
///   the `--> fix: rename the entity` suggestion the dream loop's
///   re-prompt consumes;
/// - **contract ambiguity** — a Layer Contracts interface declared under
///   two layers, or a dependency row whose Contract cell is empty.
///
/// On success the draft becomes `specs/<feature>/spec.md` (an existing
/// spec.md is refused unless `--force` — dream passes `--force` from its
/// second attempt on, so a re-ingest replaces dream's own draft without
/// ever clobbering a hand-authored spec silently). Nothing else is
/// written: the plan artifacts still come from the REAL `zfa tdd plan`
/// (dream is an orchestrator over existing commands, not a rewriter).
///
/// Machine contract: exit 0 on acceptance, 3 on template drift, 2 on
/// every other refusal, 1 on a missing draft; the summary line
/// `ingest: feature=<f> result=accepted entities=<n> dependencies=<n>
/// contracts=<n>` (result=refused on failure); `--json` emits the
/// verdict.v1 envelope.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../../../utils/framework_export_surface.dart';
import '../models/verdict_envelope.dart';
import '../services/requirement_scan.dart';
import '../services/spec_parser.dart';
import '../tdd_plugin.dart';

/// Exit code for a missing draft file.
const int kIngestMissingDraftExit = 1;

/// Exit code for template-version drift (the plan command's class).
const int kIngestDriftExit = 3;

/// Exit code for every validation refusal (the plan command's class).
const int kIngestRefusedExit = 2;

class IngestCommand extends Command<void> {
  IngestCommand(this.plugin) {
    argParser.addOption(
      'draft',
      help:
          'Path to the draft spec file (the dream loop writes '
          'specs/<feature>/tdd/draft-spec.md and passes it here).',
    );
    argParser.addFlag(
      'force',
      help:
          'Replace an existing specs/<feature>/spec.md (a dream re-ingest '
          'replaces its own draft; without this flag an existing spec is '
          'never silently overwritten).',
      negatable: false,
    );
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root the spec belongs to. When omitted, the nearest '
          'specs/ anchor walk-up from the current directory is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'ingest';

  @override
  String get description =>
      'Validate a draft spec through the plan gates (+ entity-collision '
      'and contract-ambiguity gates) and place it as '
      'specs/<feature>/spec.md — the dream loop\'s ingestion step.';

  @override
  String get invocation =>
      'zfa tdd ingest <feature> --draft <path> [--force] [--project <dir>]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Feature name is required: $invocation');
    }
    final feature = rest.first;
    final draftPath = argResults?['draft'] as String?;
    if (draftPath == null || draftPath.isEmpty) {
      usageException('Draft path is required: $invocation');
    }
    final projectFlag = argResults?['project'] as String?;
    final force = (argResults?['force'] as bool?) ?? false;
    final json = (argResults?['json'] as bool?) ?? false;

    exitCode = await _ingest(
      feature: feature,
      draftPath: draftPath,
      projectFlag: projectFlag,
      force: force,
      json: json,
    );
  }

  Future<int> _ingest({
    required String feature,
    required String draftPath,
    required String? projectFlag,
    required bool force,
    required bool json,
  }) async {
    void emit(String line) => print(line);
    final label = 'zfa tdd ingest';
    final repoRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final draftFile = File(draftPath);
    if (!await draftFile.exists()) {
      emit('$label: draft not found at $draftPath');
      return kIngestMissingDraftExit;
    }
    final specMd = await draftFile.readAsString();
    final specPath = '$repoRoot/specs/$feature/spec.md';

    // The overwrite guard: an existing spec.md is a hand-authored (or
    // already-ingested) contract — dream re-ingests pass --force, a
    // stray invocation must not silently replace it.
    final specFile = File(specPath);
    if (await specFile.exists() && !force) {
      emit(
        '$label: $specPath already exists — pass --force to replace it '
        '(a dream re-ingest replaces its own draft; a hand-authored spec '
        'is never silently overwritten).',
      );
      emit('  --> fix: pass --force, or target a different feature.');
      _emitSummary(emit, feature, 'refused', json: json);
      return kIngestRefusedExit;
    }

    // ---- Gate 1: the template-version treaty pin (bug #919) ----
    final templateVersion = const SpecParser().parseTemplateVersion(specMd);
    if (templateVersion == null ||
        !SpecParser.knownTemplateVersions.contains(templateVersion)) {
      final drift = templateVersion == null
          ? 'missing `**Template Version**` marker'
          : 'template version `$templateVersion` is not a known zuraffa '
                'template version (known: '
                '${SpecParser.knownTemplateVersions.join(', ')})';
      emit(
        '$label: contract drift — $drift (draft: $draftPath). No spec was '
        'written.',
      );
      emit(
        '  --> fix: pin `**Template Version**: `zuraffa-1.0`` and re-run '
        '`zfa tdd ingest`.',
      );
      _emitSummary(emit, feature, 'refused', json: json);
      return kIngestDriftExit;
    }

    // ---- Gate 2: behavior derivation (the plan command's parser) ----
    final List<Behavior> behaviors;
    final List<SpecEntity> entities;
    final List<SpecDependency> dependencies;
    final List<LayerContract> layerContracts;
    try {
      behaviors = const SpecParser().parse(feature, specMd);
      entities = const SpecParser().parseKeyEntities(specMd);
      dependencies = const SpecParser().parseDependencies(specMd);
      layerContracts = const SpecParser().parseLayerContracts(specMd);
    } on StateError catch (e) {
      emit('$label: cannot derive behaviors — ${e.message}');
      emit('  no spec was written.');
      _emitSummary(emit, feature, 'refused', json: json);
      return kIngestRefusedExit;
    }

    // ---- Gate 3: the coverage gate (bug #846) ----
    final scan = const RequirementScanner().scan(specMd);
    final gaps = const CoverageGate().evaluate(scan, behaviors);
    if (gaps.isNotEmpty) {
      emit(
        '$label: coverage gate FAILED — ${gaps.length} requirement '
        'statement(s) produce no behavior row (draft: $draftPath). No '
        'spec was written; fix the draft and re-run.',
      );
      for (final gap in gaps) {
        emit(
          '  ${gap.statement.id} (line ${gap.statement.lineNo}): '
          '${gap.statement.line}',
        );
        emit('    ${gap.fix}');
      }
      _emitSummary(emit, feature, 'refused', json: json);
      return kIngestRefusedExit;
    }

    // ---- Gate 4: the undeclared-dependency lint (bug #919) ----
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
      emit(
        '$label: undeclared dependencies — ${undeclared.length} '
        'requirement statement(s) reference external dependencies not '
        'declared in the External Dependencies & Contracts table (draft: '
        '$draftPath). No spec was written; declare each dependency or '
        'remove the reference, then re-run.',
      );
      undeclared.forEach((statement, names) {
        emit(
          '  ${statement.id} (line ${statement.lineNo}): '
          '${statement.line}',
        );
        emit(
          '    --> fix: add ${names.join(', ')} to the External '
          'Dependencies & Contracts table (or drop the reference).',
        );
      });
      _emitSummary(emit, feature, 'refused', json: json);
      return kIngestRefusedExit;
    }

    // ---- Gate 5: the declaration refusal (feature 071) ----
    try {
      SpecParser.parseScenarioTypeMarkers(specMd);
      const SpecParser().parseContractRows(specMd);
      SpecParser.parsePersistenceDeclarations(specMd);
      SpecParser.parseFrContractTraces(specMd);
    } on StateError catch (e) {
      emit('$label: declaration refused — ${e.message}');
      emit('  no spec was written.');
      _emitSummary(emit, feature, 'refused', json: json);
      return kIngestRefusedExit;
    }

    // ---- Gate 6: entity name collisions (the dream gates) ----
    final refusal = _entityCollisionRefusals(
      entities: entities,
      repoRoot: repoRoot,
    );
    if (refusal != null) {
      emit(refusal.message);
      emit(
        '  --> fix: rename the entity, e.g. `${refusal.rename}Entity` — '
        'pick a name that does not collide.',
      );
      _emitSummary(emit, feature, 'refused', json: json);
      return kIngestRefusedExit;
    }

    // ---- Gate 7: contract ambiguity (the dream gates) ----
    final ambiguity = _contractAmbiguityRefusals(
      specMd: specMd,
      layerContracts: layerContracts,
    );
    if (ambiguity != null) {
      emit(ambiguity);
      emit(
        '  --> fix: declare each contract exactly once, with a '
        'complete signature.',
      );
      _emitSummary(emit, feature, 'refused', json: json);
      return kIngestRefusedExit;
    }

    // ---- Accepted: the draft becomes the spec ----
    await File(specPath).parent.create(recursive: true);
    await specFile.writeAsString(specMd);
    emit(
      '$label: validated $draftPath -> $specPath '
      '(${entities.length} entities, ${dependencies.length} dependencies, '
      '${layerContracts.length} layer contracts)',
    );
    _emitSummary(
      emit,
      feature,
      'accepted',
      entities: entities.length,
      dependencies: dependencies.length,
      contracts: layerContracts.length,
      json: json,
    );
    return 0;
  }

  void _emitSummary(
    void Function(String line) emit,
    String feature,
    String result, {
    int entities = 0,
    int dependencies = 0,
    int contracts = 0,
    bool json = false,
  }) {
    emit(
      'ingest: feature=$feature result=$result entities=$entities '
      'dependencies=$dependencies contracts=$contracts',
    );
    if (json) {
      VerdictEnvelope.emit(
        command: 'ingest',
        outcome: result == 'accepted'
            ? VerdictOutcome.pass
            : VerdictOutcome.fail,
        details: {
          'entities': entities,
          'dependencies': dependencies,
          'contracts': contracts,
        },
        feature: feature,
      );
    }
  }
}

/// The first entity-collision refusal, or null when the draft's
/// entities are clean.
class _EntityRefusal {
  const _EntityRefusal(this.message, this.rename);

  /// The refusal line (the re-prompt payload the dream loop feeds back
  /// to the draft tool).
  final String message;

  /// The colliding entity name — the base of the rename suggestion.
  final String rename;
}

_EntityRefusal? _entityCollisionRefusals({
  required List<SpecEntity> entities,
  required String repoRoot,
}) {
  // Intra-draft duplicates.
  final seen = <String>{};
  for (final e in entities) {
    if (!seen.add(e.name)) {
      return _EntityRefusal(
        'zfa tdd ingest: entity name collision — ${e.name} is declared '
        'more than once in the Key Entities table (an entity must be '
        'declared exactly once).',
        e.name,
      );
    }
  }
  // The framework export surface (bug #942): fail-open when the surface
  // cannot be resolved — a null surface never refuses.
  final surface = FrameworkExportSurface.tryResolve(projectRoot: repoRoot);
  if (surface != null) {
    for (final e in entities) {
      final source = surface.lookup(e.name);
      if (source != null) {
        return _EntityRefusal(
          'zfa tdd ingest: entity name collision — ${e.name} collides '
          'with the zuraffa framework export ${e.name} ($source): the '
          'generated datasources, mocks, repositories, use cases and '
          'providers import the entity file AND the framework barrel '
          'unprefixed, so every generated file would fail to compile '
          'with ambiguous_import errors (issue #942).',
          e.name,
        );
      }
    }
  }
  // A project-local entity file is REUSE, not a collision (the run
  // command's phase-0 "reuse (never overwrite)" contract) — locateEntity
  // is deliberately not a refusal here.
  return null;
}

/// The first contract-ambiguity refusal, or null when clean.
///
/// The empty-Contract-cell scan is deliberately TEXT-level: the spec
/// parser's `_splitCells` drops empty cells, so a row like
/// `| Hive | storage |  | P1 |` vanishes from the parsed dependency
/// list entirely — the ambiguity (a dependency with no contract) is
/// only visible in the raw table.
String? _contractAmbiguityRefusals({
  required String specMd,
  required List<LayerContract> layerContracts,
}) {
  // A dependency row whose Contract cell is empty is ambiguous (the
  // parser drops the row; the raw table still names the dependency).
  final depHeading = RegExp(
    r'^#{1,6}\s*External Dependencies',
    caseSensitive: false,
  );
  var inDeps = false;
  for (final line in specMd.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('#')) {
      inDeps = depHeading.hasMatch(trimmed);
      continue;
    }
    if (!inDeps || !trimmed.startsWith('|')) continue;
    final raw = trimmed.split('|').map((c) => c.trim()).toList();
    // ['', dep, type, contract, priority, ''] — header/separator skip.
    if (raw.length < 5) continue;
    final dep = raw[1];
    if (dep.isEmpty ||
        dep.toLowerCase() == 'dependency' ||
        RegExp(r'^-+$').hasMatch(dep)) {
      continue;
    }
    if (raw[3].isEmpty) {
      return 'zfa tdd ingest: contract ambiguity — the dependency '
          '$dep declares an empty Contract cell; the mock-first make '
          'path cannot know what to fake (and the plan parser drops the '
          'row entirely, so the declaration would be lost silently).';
    }
  }
  // An interface declared under two layers is ambiguous.
  final layersByInterface = <String, Set<String>>{};
  for (final c in layerContracts) {
    layersByInterface.putIfAbsent(c.interfaceName, () => {}).add(c.layer);
  }
  for (final entry in layersByInterface.entries) {
    if (entry.value.length > 1) {
      return 'zfa tdd ingest: contract ambiguity — the interface '
          '${entry.key} is declared under two layers '
          '(${entry.value.join(', ')}); a consumer cannot know which '
          'contract governs it.';
    }
  }
  return null;
}
