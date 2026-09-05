/// `zfa tdd view <behavior-id>` — the deterministic view-builder generator
/// surface for widget-kind behaviors (issue #939).
///
/// Bug #939: the widget lane (bug #830) drives a UI behavior to an honest
/// RED and then DEAD-ENDS — `zfa tdd make` reports `unexpressible` for
/// every widget-kind behavior because the planner is description-keyed
/// (by design) and UI prose never maps to `entity create`/`make`/`build`,
/// while the composition fallback gated on acceptance-kind rows only. A
/// UI-rich spec could never complete the loop: it always stopped at
/// `<id>:make` on the first widget behavior.
///
/// This command is the missing widget make path, scoped to the tdd plugin
/// for the same reason `zfa tdd func`/`tdd wire` are (bug #610 design
/// decision): the subject contract (`SubjectWriter` stubs, registry
/// artifacts, test lists) is owned by the tdd plugin, and a core command
/// would need a core→plugin dependency the architecture forbids.
///
/// The command:
///   1. Resolves the behavior's registry record (same resolution rules
///      as `func`/`wire`/`make`) and its `subject_path` artifact.
///   2. Parses the gen'd view-builder stub — the exact
///      `Widget <name>() => throw UnimplementedError(...);` shape
///      SubjectWriter emits for widget-kind rows (bug #830).
///   3. Derives the minimal view composition from two DECLARED sources,
///      never from the test (044 ownership contract):
///        - the behavior description's scenario assertions (issue #964
///          finder-kind taxonomy — the same classification
///          `behavior_test_writer.dart` uses for the paired test's
///          verb-matched assertions): presence literals render one
///          `Text` each so the paired test can actually flip green;
///          route/enabled-state literals render a labeled button
///          affordance; absence literals render nothing;
///        - the spec's declared Presentation layer contract (the
///          zuraffa-1.0 template's `### Layer Contracts → **Presentation**`
///          section, read back through `TestListReader.readLayerContracts`,
///          the same information `zfa make --with=vpc` uses for
///          presenters): each declared component token maps to a
///          deterministic always-compiling core-Flutter stand-in.
///   4. Replaces ONLY the stub declaration with the minimal view: a
///      private-ish `StatelessWidget` skeleton plus the view-builder
///      returning it. Scenario-specific behavior inside the view
///      (navigation, validation, state) is the sanctioned handcraft seam
///      — the loop only needs to REACH green through a generated
///      skeleton, exactly as func subjects do (issue #939 remediation).
///   5. Is idempotent: a subject with no `UnimplementedError` left is
///      reported `already-implemented` and exits 0, so a resumed
///      pipeline re-running the step stays green.
///
/// Determinism: the same registry record + test list + stub always render
/// the same bytes (no timestamps, no ordering hazards — component tokens
/// are de-duplicated order-preservingly). This is a hard constraint of
/// the widget make path (VISION §4 determinism, issue #939).
///
/// The machine contract is the summary line
/// `view: behavior=<id> outcome=<label> feature=<feature>` as the final
/// stdout line on every code path; exit 0 means exactly "scaffolded (or
/// already implemented)".
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/behavior_test_writer.dart' show BehaviorTestWriter;
import '../services/finder_taxonomy.dart';
import '../services/nuance_receipts.dart';
import '../services/tdd_generation_receipt.dart';
import '../services/test_list_reader.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

/// Outcome labels for the machine-readable summary line.
enum ViewOutcome {
  scaffolded('scaffolded'),
  alreadyImplemented('already-implemented'),
  runnerError('runner-error');

  const ViewOutcome(this.label);
  final String label;
}

class ViewCommand extends Command<void> {
  ViewCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 002-login). Restricts target resolution '
          'to specs/<feature>/tdd/artifacts.json. When omitted, every '
          'feature registry is scanned.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, '
          'the current working directory is used.',
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'view';

  @override
  String get description =>
      'Generate the deterministic minimal view for a widget-kind behavior '
      'from its declared Presentation layer contract and scenario literals '
      '— the view-builder generation surface of the pipeline (issue #939).';

  @override
  String get invocation =>
      'zfa tdd view <behavior-id> [--feature <name>] [--project <path>]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    if (behaviorId == null || behaviorId.isEmpty) {
      print('zfa tdd view: behavior id is required. Usage: $invocation');
      _printSummary(
        behavior: '-',
        outcome: ViewOutcome.runnerError,
        feature: 'unknown',
      );
      exitCode = 1;
      return;
    }
    final featureFlag = argResults?['feature'] as String?;
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    // -------------------------------------------------------------
    // 1. Resolve the behavior's registry record (FR-001/FR-002 shape).
    // -------------------------------------------------------------
    _Resolved? resolved;
    try {
      resolved = await _resolve(cwd, behaviorId, featureFlag);
    } on _ViewResolutionError catch (e) {
      print('zfa tdd view: ${e.message}');
      _printSummary(
        behavior: behaviorId,
        outcome: ViewOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    if (resolved == null) {
      print(
        'zfa tdd view: unknown behavior id "$behaviorId". No matching '
        'record in any specs/<feature>/tdd/artifacts.json'
        '${featureFlag != null && featureFlag.isNotEmpty ? ' for feature $featureFlag' : ''}. Run `zfa tdd gen $behaviorId` first.',
      );
      _printSummary(
        behavior: behaviorId,
        outcome: ViewOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = resolved.record;
    final description = record.descriptionSegment;
    print('zfa tdd view: behavior ${record.behaviorId}');
    print('   feature: ${resolved.featureName}');
    print('   description: $description');

    // -------------------------------------------------------------
    // 2. The subject artifact must exist (gen wrote it).
    // -------------------------------------------------------------
    final recordedSubject = record.subjectPath;
    final normalizedCwd = p.normalize(p.absolute(cwd));
    final subjectPath = p.normalize(
      p.isAbsolute(recordedSubject)
          ? recordedSubject
          : p.join(normalizedCwd, recordedSubject),
    );
    if (!p.equals(normalizedCwd, subjectPath) &&
        !p.isWithin(normalizedCwd, subjectPath)) {
      print(
        'zfa tdd view: the registry record for behavior '
        '"${record.behaviorId}" points outside the project root at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ViewOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) {
      print(
        'zfa tdd view: the registry record for behavior '
        '"${record.behaviorId}" points to a missing subject file at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ViewOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    // -------------------------------------------------------------
    // 3. Parse the stub and gather the declared composition inputs.
    // -------------------------------------------------------------
    final raw = await subjectFile.readAsString();
    final stub = _stubSignature.firstMatch(raw);
    if (stub == null) {
      final hasUnimplementedError = raw.contains('UnimplementedError');
      if (hasUnimplementedError) {
        print(
          'zfa tdd view: subject at "$recordedSubject" carries an '
          'UnimplementedError in an unrecognized shape — refusing to '
          'rewrite a file this command did not generate.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: ViewOutcome.runnerError,
          feature: resolved.featureName,
        );
        exitCode = 1;
      } else {
        // Idempotent re-run (resumed pipeline): nothing to do.
        print(
          'zfa tdd view: subject at "$recordedSubject" is already '
          'implemented — nothing to scaffold.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: ViewOutcome.alreadyImplemented,
          feature: resolved.featureName,
        );
      }
      return;
    }
    // The stub's function NAME is preserved: the paired (immutable)
    // test calls `subject.<name>()` and must keep compiling against
    // the scaffolded signature (044 ownership contract).
    final functionName = stub.group(2)!;

    // Declared source 1 — the scenario assertions the paired widget test
    // emits (issue #964 finder-kind taxonomy: the same classification
    // behavior_test_writer applies when deriving the test's assertions,
    // issue #912 defect 3). Presence literals render as Text; route
    // literals render as a navigation affordance (never the route name
    // as on-screen text — that was the certified lie of issue #964);
    // absence literals render nothing.
    final analysis = FinderTaxonomy.analyze(description);

    // Declared source 2 — the Presentation layer contract (the
    // zuraffa-1.0 template's `### Layer Contracts → **Presentation**`
    // section, written by plan into the test list).
    final featureDir = p.join(normalizedCwd, 'specs', resolved.featureName);
    final components = await _presentationComponents(featureDir);
    if (components.isEmpty) {
      print(
        '   contract: no Presentation layer contract declared — '
        'composing the scenario literals only',
      );
    } else {
      print('   contract: ${components.join(', ')}');
    }

    // -------------------------------------------------------------
    // 4. Emit the deterministic minimal view (issue #939 remediation).
    // -------------------------------------------------------------
    final viewClass = _viewClassName(record.behaviorId);
    final scaffolded = _renderView(
      behaviorId: record.behaviorId,
      criterion: record.sourceCriterion,
      description: description,
      functionName: functionName,
      viewClass: viewClass,
      analysis: analysis,
      components: components,
    );
    // The gen'd stub carries a doc-comment block immediately above the
    // declaration ("Throws [UnimplementedError] until the real
    // implementation lands.", the bug #830 shape). It documents the
    // STUB, not the implementation — include it in the replacement so
    // the scaffolded file neither keeps a stale throw-contract nor
    // trips the idempotency probe on a resumed pipeline's re-run.
    var blockStart = stub.start;
    while (true) {
      final lineStart = raw.lastIndexOf('\n', blockStart - 2) + 1;
      final line = raw.substring(lineStart, blockStart);
      if (RegExp(r'^\s*///').hasMatch(line)) {
        blockStart = lineStart;
      } else {
        break;
      }
    }
    final updated = raw.replaceRange(blockStart, stub.end, scaffolded);
    await subjectFile.writeAsString(updated);
    // Issue #969 T003: the scaffolded subject becomes self-certifying.
    await TddGenerationReceipts.writeBestEffort(
      projectRoot: normalizedCwd,
      command: 'tdd view',
      target: record.behaviorId,
      feature: resolved.featureName,
      files: {subjectPath: 'update'},
    );
    // #807 receipt: record the scaffolded file for the provenance
    // ledger so `zfa proof check` recognises it.
    try {
      final receipts = NuanceReceipts(
        featureDir: p.join(normalizedCwd, 'specs', resolved.featureName),
        projectRoot: normalizedCwd,
      );
      await receipts.record(
        file: p.relative(subjectPath, from: normalizedCwd),
        reason: 'generated by zfa tdd view',
        adapter: 'view',
      );
    } catch (_) {
      // receipt recording is best-effort; don't break the main flow
    }
    print('   scaffolded: $recordedSubject (view: $viewClass)');
    _printSummary(
      behavior: record.behaviorId,
      outcome: ViewOutcome.scaffolded,
      feature: resolved.featureName,
    );
  }

  // -------------------------------------------------------------------
  // Resolution + rendering helpers (mirror func_command.dart).
  // -------------------------------------------------------------------

  /// The gen'd widget-stub shape SubjectWriter emits for widget-kind
  /// rows (bug #830): `Widget <name>() => throw UnimplementedError(...);`
  static final RegExp _stubSignature = RegExp(
    r'^(Widget)[ \t]+([A-Za-z_][A-Za-z0-9_]*)\(\)[ \t]*=>[ \t]*'
    r'throw[ \t]+UnimplementedError\([^;\r\n]*\);[ \t]*$',
    multiLine: true,
  );

  /// The declared component tokens of the feature's Presentation layer
  /// contract, de-duplicated order-preservingly. Empty when the feature's
  /// test list declares no `Presentation` section (the view then composes
  /// the scenario assertions only — still deterministic).
  static Future<List<String>> _presentationComponents(String featureDir) async {
    try {
      final contracts = await TestListReader(featureDir).readLayerContracts();
      final tokens = <String>[];
      for (final contract in contracts) {
        if (!contract.layer.toLowerCase().contains('presentation')) continue;
        for (final method in contract.methods) {
          final token = method.trim();
          if (token.isEmpty) continue;
          if (!tokens.contains(token)) tokens.add(token);
        }
      }
      return tokens;
    } on TestListReadException {
      // An unreadable list degrades to the literal-only composition —
      // the same fail-open note discipline _rowKind applies to kinds
      // (the kind/contract is an optimization over the deterministic
      // default; other steps re-surface malformation honestly).
      return const [];
    }
  }

  /// The deterministic view class name for a behavior id: the id's
  /// alphanumeric characters, Pascal-cased, suffixed `View` (e.g.
  /// `A1` → `A1View`, `B-042` → `B042View`). A leading digit prefixes
  /// `Behavior` so the identifier always compiles.
  static String _viewClassName(String behaviorId) {
    final sanitized = behaviorId.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    if (sanitized.isEmpty) return 'BehaviorView';
    final first = sanitized.substring(0, 1).toUpperCase();
    final rest = sanitized.substring(1);
    final pascal = RegExp(r'^[0-9]').hasMatch(sanitized)
        ? 'Behavior$first$rest'
        : '$first$rest';
    return '${pascal}View';
  }

  /// Render the view-builder implementation that replaces the stub
  /// declaration (issue #939 remediation 1). The composition is:
  ///   1. one surface per scenario assertion (issue #964 finder-kind
  ///      taxonomy): a presence literal renders a `Text` (satisfying the
  ///      paired test's presence assertions); a route or enabled-state
  ///      literal renders a labeled `ElevatedButton` affordance — never
  ///      the route name as on-screen text, which was the certified lie
  ///      of issue #964; an absence literal renders nothing (rendering
  ///      it would honestly fail the paired absence assertion);
  ///   2. one deterministic stand-in per declared Presentation component
  ///      (composes the declared contract; unknown components render as
  ///      labeled placeholders — never invented semantics).
  ///
  /// A view with NEITHER assertions nor components carries the behavior
  /// id as a traceable marker text. Scenario-specific behavior
  /// (navigation, validation, state) is the sanctioned handcraft seam —
  /// the header comment names it, the loop only certifies compile +
  /// verb-matched assertions.
  static String _renderView({
    required String behaviorId,
    required String criterion,
    required String description,
    required String functionName,
    required String viewClass,
    required ScenarioAnalysis analysis,
    required List<String> components,
  }) {
    final children = <String>[
      for (final assertion in analysis.assertions)
        if (assertion.assertionClass == ScenarioAssertionClass.presence)
          "            Text('${BehaviorTestWriter.escapeDartString(assertion.literal)}'),"
        else if (assertion.assertionClass != ScenarioAssertionClass.absence)
          '            ElevatedButton(\n'
              '              onPressed: () {},\n'
              "              child: Text('${BehaviorTestWriter.escapeDartString(assertion.literal)}'),\n"
              '            ),',
      for (final component in components) _standIn(component),
    ];
    if (children.isEmpty) {
      children.add(
        "            Text('${BehaviorTestWriter.escapeDartString(behaviorId)}'),",
      );
    }
    final body = children.join('\n');
    final header = _commentSafe(description);
    return '''
/// View-builder subject for behavior $behaviorId (issue #939): returns
/// the deterministic minimal view composed from the declared Presentation
/// layer contract and the scenario assertions of the behavior description
/// (issue #964 finder-kind taxonomy: presence literals render as Text,
/// route/enabled-state literals as a labeled affordance, absence literals
/// render nothing). Scenario-specific behavior (navigation, validation,
/// state) is the sanctioned handcraft seam — implement it in [$viewClass].
Widget $functionName() => $viewClass();

/// The minimal view for behavior $behaviorId (issue #939 skeleton).
///
/// $header
class $viewClass extends StatelessWidget {
  const $viewClass({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
$body
      ],
    );
  }
}''';
  }

  /// The deterministic always-compiling core-Flutter stand-in for a
  /// declared Presentation component token (issue #939: the same
  /// information `zfa make --with=vpc` uses for presenters, composed
  /// into a compiling skeleton). Mapping table on the lowercased token;
  /// unknown tokens render as a labeled placeholder so every declared
  /// component surfaces in the skeleton without inventing semantics.
  static String _standIn(String component) {
    final label = BehaviorTestWriter.escapeDartString(component);
    final lower = component.toLowerCase();
    // NOTE: stand-ins are deliberately NON-const — the callback shapes
    // carry closures, which cannot sit inside a const list.
    if (lower.contains('input') || lower.contains('field')) {
      return '            TextField(),';
    }
    if (lower.contains('button')) {
      return "            ElevatedButton(onPressed: () {}, child: Text('$label')),";
    }
    if (lower.contains('checkbox')) {
      return '            Checkbox(value: false, onChanged: (_) {}),';
    }
    if (lower.contains('switch')) {
      return '            Switch(value: false, onChanged: (_) {}),';
    }
    if (lower.contains('slider')) {
      return '            Slider(value: 0, onChanged: (_) {}),';
    }
    if (lower.contains('progress') ||
        lower.contains('indicator') ||
        lower.contains('loading')) {
      return '            SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),';
    }
    if (lower.contains('image') || lower.contains('avatar')) {
      return '            CircleAvatar(child: Icon(Icons.person)),';
    }
    if (lower.contains('icon')) {
      return '            Icon(Icons.circle),';
    }
    // Unknown component: a labeled placeholder (deterministic, compiling).
    return "            Text('$label'),";
  }

  /// Strip newlines from a description for safe single-line comment use.
  static String _commentSafe(String description) =>
      description.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  Future<_Resolved?> _resolve(
    String cwd,
    String behaviorId,
    String? featureFlag,
  ) async {
    final matches = <_Resolved>[];
    for (final entry in await _scanRegistries(cwd, featureFlag)) {
      final record = await entry.registry.findRecord(behaviorId);
      if (record != null) {
        matches.add(_Resolved(record, entry.featureName));
      }
    }
    if (matches.length > 1) {
      final list = matches.map((m) => m.featureName).join(', ');
      throw _ViewResolutionError(
        'ambiguous behavior id "$behaviorId" registered in multiple '
        'features: $list. Use --feature to disambiguate.',
      );
    }
    return matches.isEmpty ? null : matches.single;
  }

  Future<List<_RegistryEntry>> _scanRegistries(
    String cwd,
    String? featureFlag,
  ) async {
    if (featureFlag != null && featureFlag.isNotEmpty) {
      final featureDir = p.join(cwd, 'specs', featureFlag);
      return [
        _RegistryEntry(featureFlag, ArtifactRegistry(featureDir: featureDir)),
      ];
    }
    final specsDir = Directory(p.join(cwd, 'specs'));
    if (!await specsDir.exists()) return const [];
    final dirs = specsDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final entries = <_RegistryEntry>[];
    for (final dir in dirs) {
      final registryFile = File(p.join(dir.path, 'tdd', 'artifacts.json'));
      if (await registryFile.exists()) {
        entries.add(
          _RegistryEntry(
            p.basename(dir.path),
            ArtifactRegistry(featureDir: dir.path),
          ),
        );
      }
    }
    return entries;
  }

  void _printSummary({
    required String behavior,
    required ViewOutcome outcome,
    required String feature,
  }) {
    print('view: behavior=$behavior outcome=${outcome.label} feature=$feature');
    // Issue #969: the outcome label IS the exit class.
    _verdict
      ..exitClass = outcome.label
      ..outcome = switch (outcome) {
        ViewOutcome.scaffolded => VerdictOutcome.pass,
        ViewOutcome.alreadyImplemented => VerdictOutcome.stopped,
        ViewOutcome.runnerError => VerdictOutcome.fail,
      }
      ..details['behavior'] = behavior
      ..feature = feature == 'unknown' ? null : feature;
  }
}

class _ViewResolutionError implements Exception {
  _ViewResolutionError(this.message);
  final String message;
  @override
  String toString() => message;
}

class _RegistryEntry {
  const _RegistryEntry(this.featureName, this.registry);
  final String featureName;
  final ArtifactRegistry registry;
}

class _Resolved {
  const _Resolved(this.record, this.featureName);
  final ArtifactRecord record;
  final String featureName;
}
