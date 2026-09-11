/// `zfa tdd wire <behavior-id> --entity <Name>` — the subject-wiring
/// generation step of the entity pipeline (bug #610; epic 045
/// precondition 5, FR-003/FR-005; spec 047 FR-005 minimal generation).
///
/// Bug #610: the entity plan (`entity create` + `build`) never
/// implemented the gen'd subject stub (`lib/tdd/<id>_subject.dart`, an
/// `UnimplementedError` stub), so with the REAL pipeline green was
/// unreachable for any entity-bearing behavior — the target test stayed
/// red after a fully successful generation and `make` honestly stopped
/// with `generation-error`. Fake-zfa mocks hid the gap because THEY
/// wired the subject themselves.
///
/// This command is the missing pipeline step. It:
///   1. Resolves the behavior's registry record (same resolution rules
///      as `verify-red`/`make`) and its `subject_path` artifact.
///   2. Requires `--entity <Name>` — the generated entity the behavior
///      is being wired to (the planner passes the same name it emitted
///      to `entity create -n`). Misfire-stop when the entity file does
///      not exist yet: run `zfa entity create -n <Name>` first.
///   3. Replaces the subject's `UnimplementedError` stub body with the
///      minimal wired implementation (spec 047 FR-005): the generated
///      entity is imported and referenced as the implementation anchor.
///      The paired test file is never touched (044 ownership contract).
///   4. Is idempotent: a subject with no `UnimplementedError` left is
///      reported `already-wired` and exits 0, so a resumed pipeline
///      re-running the step stays green.
///
/// Design decision (recorded in the epic 045 harness spec, precondition
/// 5, and the #610 PR): subject wiring lives in the tdd plugin as a
/// dedicated subcommand rather than a `zfa make --with=tdd-subject`
/// flag, because the subject contract (`lib/tdd/<id>_subject.dart`,
/// SubjectWriter, registry artifacts) is owned by the tdd plugin; a
/// core command would need a core→plugin dependency the architecture
/// forbids (plugins depend on core, never the reverse), and a dedicated
/// invocation gives the 045 provenance audit a clean, self-describing
/// attribution record for the subject implementation.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/declared_routing.dart';
import '../services/entity_lookup.dart';
import '../services/subject_signature_deriver.dart';
import '../services/tdd_generation_receipt.dart';
import '../services/unit_contract_shape.dart';
import '../services/verdict_emitter.dart';
import '../models/routing.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

/// Outcome labels for the machine-readable summary line.
enum WireOutcome {
  wired('wired'),
  alreadyWired('already-wired'),
  runnerError('runner-error');

  const WireOutcome(this.label);
  final String label;
}

class WireCommand extends Command<void> {
  WireCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'entity',
      help:
          'The generated entity the behavior is wired to (same name the '
          'plan passed to `zfa entity create -n`). Required: wiring '
          'without an entity anchor would be hand-implementation, not '
          'generation.',
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 047-tdd-make). Restricts target resolution '
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
  String get name => 'wire';

  @override
  String get description =>
      'Wire a behavior\'s gen\'d subject stub to its generated entity — '
      'the subject-implementation step of the entity pipeline (bug #610, '
      'epic 045 precondition 5).';

  @override
  String get invocation =>
      'zfa tdd wire <behavior-id> --entity <Name> [--feature <name>] '
      '[--project <path>]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    if (behaviorId == null || behaviorId.isEmpty) {
      print('zfa tdd wire: behavior id is required. Usage: $invocation');
      _printSummary(
        behavior: '-',
        outcome: WireOutcome.runnerError,
        feature: 'unknown',
      );
      exitCode = 1;
      return;
    }
    final entityName = argResults?['entity'] as String?;
    if (entityName == null || entityName.isEmpty) {
      print(
        'zfa tdd wire: --entity <Name> is required — the subject must be '
        'wired to the generated entity (the planner passes the same name '
        'it gave `zfa entity create -n`).',
      );
      _printSummary(
        behavior: behaviorId,
        outcome: WireOutcome.runnerError,
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
    } on _WireResolutionError catch (e) {
      print('zfa tdd wire: ${e.message}');
      _printSummary(
        behavior: behaviorId,
        outcome: WireOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    if (resolved == null) {
      print(
        'zfa tdd wire: unknown behavior id "$behaviorId". No matching '
        'record in any specs/<feature>/tdd/artifacts.json'
        '${featureFlag != null && featureFlag.isNotEmpty ? ' for feature $featureFlag' : ''}. Run `zfa tdd gen $behaviorId` first.',
      );
      _printSummary(
        behavior: behaviorId,
        outcome: WireOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = resolved.record;
    print('zfa tdd wire: behavior ${record.behaviorId}');
    print('   feature: ${resolved.featureName}');
    print('   entity: $entityName');

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
    // macOS (and any symlinked temp root): the recorded path may come
    // through one side of a symlink (`/var/...`) while the project root
    // resolves through the other (`/private/var/...`). Compare CANONICAL
    // forms — an unresolved comparison misreads the project's own
    // subject as "outside the project root".
    String canonicalRoot;
    try {
      canonicalRoot = await Directory(normalizedCwd).resolveSymbolicLinks();
    } on FileSystemException {
      canonicalRoot = normalizedCwd;
    }
    String canonicalSubject;
    try {
      canonicalSubject = await File(subjectPath).resolveSymbolicLinks();
    } on FileSystemException {
      // A missing subject file (the U-W3 artifact case) has nothing to
      // resolve: canonicalize through its nearest EXISTING ancestor and
      // re-append the remaining segments. Taking the raw path here made
      // a symlinked temp root (`/var/folders` → `/private/var/folders`
      // on macOS) read the project's own recorded path as "outside the
      // project root" — the wrong refusal branch (pull/1516 review).
      canonicalSubject = await _canonicalizeMissingPath(subjectPath);
    }
    if (!p.equals(canonicalRoot, canonicalSubject) &&
        !p.isWithin(canonicalRoot, canonicalSubject)) {
      print(
        'zfa tdd wire: the registry record for behavior '
        '"${record.behaviorId}" points outside the project root at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: WireOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) {
      print(
        'zfa tdd wire: the registry record for behavior '
        '"${record.behaviorId}" points to a missing subject file at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: WireOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    // -------------------------------------------------------------
    // 3. The entity file must exist (the pipeline's `entity create`
    //    step ran first — plan order guarantees it; a manual run that
    //    skipped it is misfire-stopped here, not papered over).
    // -------------------------------------------------------------
    final entityFile = await locateEntityFile(cwd, entityName);
    if (entityFile == null) {
      print(
        'zfa tdd wire: no generated entity "$entityName" found under '
        '${p.join(cwd, 'lib', 'src', 'domain', 'entities')}. Run '
        '`zfa entity create -n $entityName` first (the plan orders the '
        'wire step after entity create).',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: WireOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    // -------------------------------------------------------------
    // 4. Parse the subject stub and emit the wired implementation.
    // -------------------------------------------------------------
    final raw = await subjectFile.readAsString();
    final stub = _stubSignature.firstMatch(raw);
    if (stub == null) {
      // Bug #829: classify by EXECUTABLE code, not raw text. The gen'd
      // stub header carries "Throws [UnimplementedError] until the real
      // implementation lands" — a doc comment `tdd func`'s scaffold
      // preserves — so a raw contains() misclassified every
      // pipeline-generated subject as "an unrecognized shape" and
      // refused it. Only an UnimplementedError thrown in CODE (a shape
      // this command did not generate — U-W5's hand-written class, for
      // example) is refused; a mention confined to comments means the
      // subject was already implemented by a pipeline step.
      if (_hasExecutableUnimplementedError(raw)) {
        print(
          'zfa tdd wire: subject at "$recordedSubject" carries an '
          'UnimplementedError in an unrecognized shape — refusing to '
          'rewrite a file this command did not generate.',
        );
        exitCode = 1;
      } else {
        // Idempotent re-run (resumed pipeline): nothing to do.
        print(
          'zfa tdd wire: subject at "$recordedSubject" is already '
          'implemented — nothing to wire.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: WireOutcome.alreadyWired,
          feature: resolved.featureName,
        );
        exitCode = 0;
      }
      return;
    }
    final stubReturnType = stub.group(1)!.trim();
    final functionName = stub.group(2)!;
    final stubParams = stub.group(3)!.trim();

    // -------------------------------------------------------------
    // 4b. Resolve the DECLARED signature the stub was derived from
    //     (issue #1500). A contract-derived subject (#1259) renders
    //     non-renderable declared types as `Object?` so the STUB
    //     compiles (FR-011) — that degradation is stub scaffolding,
    //     never the wired return. Wire resolves the declared return
    //     through the SAME machinery gen used (test-list traces →
    //     spec contract rows → UnitContractShape), falling back to the
    //     stub's own provenance header when the spec artifacts are
    //     absent. A MALFORMED declaration refuses (errors-are-an-API),
    //     matching gen's contract.
    // -------------------------------------------------------------
    UnitContractShape? declaredShape;
    try {
      final declared = await DeclaredRouting.declaredSignatureFor(
        cwd: cwd,
        featureName: resolved.featureName,
        featureDir: resolved.featureDir,
        behaviorId: record.behaviorId,
      );
      if (declared != null) declaredShape = UnitContractShape.of(declared);
    } on StateError catch (e) {
      print('zfa tdd wire: declaration refused — ${e.message}');
      _printSummary(
        behavior: record.behaviorId,
        outcome: WireOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }
    // Fallback: the SubjectWriter contract stub preserves the declared
    // signature in its provenance header (`//     create(String title)
    // -> Task`). When the registry's spec artifacts are pruned but the
    // stub remains, the header still names the declared shape — the
    // same source gen derived the stub from, never an invention.
    declaredShape ??= _declaredShapeFromStubHeader(raw);

    // The declared return wins whenever it is a plausible type token;
    // the plausibility gate keeps prose-adjacent header text from ever
    // rendering a non-type into the wired signature.
    final declaredReturn = declaredShape?.declaredReturn.trim();
    final derived = deriveSubjectSignature(
      _descriptionFor(record),
      forWire: true,
    );
    var effectiveReturnType =
        declaredReturn != null &&
            declaredReturn.isNotEmpty &&
            _isPlausibleTypeToken(declaredReturn)
        ? declaredReturn
        : (stubReturnType == 'void'
              ? 'void'
              : (derived.returnType.isNotEmpty
                    ? derived.returnType
                    : stubReturnType));

    // Issue #1500: an entity-shaped declared return binds to the mock
    // data the pipeline generated one step earlier (`zfa mock create
    // --name <E>` writes <E>MockData.sample<E>/.sampleList) — never a
    // `return null as Task;` runtime cast error. A missing mock-data
    // file is an honest misfire-stop naming the skipped step; the
    // subject is left untouched.
    //
    // Review finding 1 (pull/1516): the plan's `mock create` runs for
    // the entity it passed to `--entity` (the TRACED entity), never for
    // the declared return's entity. Hard-stopping on a mock the plan
    // will never create dead-ended the pipeline permanently (the
    // remediation named a step the plan does not run).
    //
    // Review finding 2 (pull/1516): the declared return's own class must
    // be imported when it differs from `--entity` — Dart imports are not
    // transitive, so an unimported declared token left the wired subject
    // uncompilable (the exact failure class #1500 set out to remove).
    //
    // The mismatch resolution therefore is: bind the declared entity's
    // OWN mock data when it exists (importing the declared class too),
    // otherwise fall back to the stub's renderable shape — a mismatch
    // never emits `return null as <Declared>;`, which `dart analyze`
    // flags as `cast_from_null_always_fails` (the crashing-cast class
    // review finding 3 names).
    final mockBinding = _mockBindingFor(effectiveReturnType);
    String? mockImport;
    String? mockReference;
    String? declaredEntityImport;
    if (mockBinding != null) {
      final mockFile = await _locateMockDataFile(cwd, mockBinding.entity);
      if (mockBinding.entity == entityName) {
        if (mockFile == null) {
          print(
            'zfa tdd wire: no generated mock data for entity '
            '"${mockBinding.entity}" found under '
            '${p.join(cwd, 'lib', 'src', 'data', 'mock')}. Run '
            '`zfa mock create --name ${mockBinding.entity}` first (the '
            'pipeline orders the wire step after mock create — the wired '
            'subject returns an ${mockBinding.entity}MockData sample, '
            'not a cast null).',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: WireOutcome.runnerError,
            feature: resolved.featureName,
          );
          exitCode = 1;
          return;
        }
        mockImport = _packageImportFor(cwd, mockFile);
        mockReference = '${mockBinding.entity}MockData.${mockBinding.accessor}';
      } else {
        final declaredEntityFile = await locateEntityFile(
          cwd,
          mockBinding.entity,
        );
        if (declaredEntityFile == null || mockFile == null) {
          // The declared return names a class the pipeline did not
          // generate (a repository/usecase type, or an entity the plan
          // never created), or one whose mock data the plan never
          // creates: keep the stub's own renderable shape (FR-011) — the
          // same degradation the subject stub carried — rather than
          // render an undefined class or a cast that always throws.
          effectiveReturnType = stubReturnType;
        } else {
          declaredEntityImport = _packageImportFor(cwd, declaredEntityFile);
          mockImport = _packageImportFor(cwd, mockFile);
          mockReference =
              '${mockBinding.entity}MockData.${mockBinding.accessor}';
        }
      }
    }

    final wired = _renderWired(
      record: record,
      derived: derived,
      effectiveReturnType: effectiveReturnType,
      functionName: functionName,
      stubParams: stubParams,
      entityName: entityName,
      entityImport: _packageImportFor(cwd, entityFile),
      declaredEntityImport: declaredEntityImport,
      mockImport: mockImport,
      mockReference: mockReference,
    );
    await subjectFile.writeAsString(wired);
    // Issue #969 T003: the wired subject becomes self-certifying.
    await TddGenerationReceipts.writeBestEffort(
      projectRoot: cwd,
      command: 'tdd wire',
      target: record.behaviorId,
      feature: resolved.featureName,
      files: {subjectFile.path: 'update'},
    );
    print('   wired: $recordedSubject -> entity $entityName');
    _printSummary(
      behavior: record.behaviorId,
      outcome: WireOutcome.wired,
      feature: resolved.featureName,
    );
    // Explicitly clear the process-global exit code on the success path.
    // `dart:io`'s `exitCode` is process-global and retains whatever the last
    // command set, so without this a successful wire inherits a non-zero
    // code from a prior command in the same runner — the exact failure that
    // made `zfa tdd wire` report `outcome=wired` with `exitCode=1` on the CI
    // runner (issue #652).
    exitCode = 0;
  }

  // -------------------------------------------------------------------
  // Resolution + rendering helpers.
  // -------------------------------------------------------------------

  /// Bug #1500: accepts every stub shape SubjectWriter emits — the
  /// legacy no-arg `int|void name() => throw UnimplementedError(` AND
  /// the contract-derived subjects of issue #1259 (`Object?
  /// subject_u2(String title) => throw ...`): ANY return type (scalar,
  /// entity, generic, nullable), ANY parameter list.
  ///
  /// The match stays pinned to the single-line arrow-throw form: a
  /// newline may not separate `=>` from `throw` (the FFI harness's
  /// wrapped seams are a hand-owned shape wire must keep refusing),
  /// and a block body `void run() {` never matches. Group 3 carries
  /// the declared parameter list verbatim so the wired signature keeps
  /// it (issue #1500 expected 5).
  static final RegExp _stubSignature = RegExp(
    r'^([A-Za-z_][A-Za-z0-9_]*(?:<[^()<>=]*(?:<[^()<>=]*>)?[^()<>=]*>)?' // type base + optional (nested) generics
    r'[ \t]*\??)' // optional nullability marker
    r'[ \t]+([A-Za-z_][A-Za-z0-9_]*)' // the subject name
    r'\(([^)]*)\)' // the declared parameter list, verbatim
    r'[ \t]*=>[ \t]*throw UnimplementedError\(',
    multiLine: true,
  );

  /// Whether [raw] carries an `UnimplementedError` in EXECUTABLE code —
  /// any line whose `//` comment suffix is stripped first (bug #829:
  /// doc-comment mentions are gen-stub residue, not a stub body).
  static bool _hasExecutableUnimplementedError(String raw) {
    for (final line in raw.split('\n')) {
      final commentIdx = line.indexOf('//');
      final code = commentIdx >= 0 ? line.substring(0, commentIdx) : line;
      if (code.contains('UnimplementedError')) return true;
    }
    return false;
  }

  /// The declared shape carried by the stub's own provenance header
  /// (bug #1500 fallback): the SubjectWriter contract stub preserves
  /// `//     create(String title) -> Task` — the exact declaration gen
  /// derived the stub from. Null when no header line parses to a
  /// signature; prose-adjacent matches are additionally filtered by
  /// the type-token plausibility gate at the use site.
  ///
  /// Tradeoff (pull/1516 review): a STALE stub's header outranks the
  /// current spec — there is no staleness comparison here, unlike gen's
  /// `SubjectWriter.render` diffing (bug #683). This path is a fallback
  /// only reached when the spec artifacts are absent/unreadable, so the
  /// drift window is a pruned-artifacts run; the next `zfa tdd gen`
  /// rewrites the header from the current declaration.
  static UnitContractShape? _declaredShapeFromStubHeader(String raw) {
    for (final line in raw.split('\n')) {
      final comment = RegExp(r'^\s*//\s*(.+?)\s*$').firstMatch(line);
      if (comment == null) continue;
      final text = comment.group(1)!;
      if (!text.contains(' -> ')) continue;
      // The header line must be the BARE signature, not prose that
      // happens to carry an arrow: a bare signature starts with the
      // method name immediately followed by its parameter list.
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*\s*\(').hasMatch(text)) {
        continue;
      }
      try {
        return UnitContractShape.of(Signature.parse(text));
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  /// Whether [type] is a plausible Dart type token for the wired
  /// signature (bug #1500 defense-in-depth): identifiers, one nesting
  /// level of generics and a nullability marker. Prose fragments
  /// (`Task works`) never pass, so a drifting header can never render
  /// a non-type into the wired file.
  static bool _isPlausibleTypeToken(String type) => RegExp(
    r'^[A-Za-z_][A-Za-z0-9_]*(<[^()]*(<[^()]*>)?[^()]*>)?[ \t]*\??$',
  ).hasMatch(type.trim());

  /// The core types that never bind to mock data (bug #1500): scalars,
  /// dynamic/object tops and DateTime have no `<E>MockData` surface.
  static const Set<String> _nonEntityBases = {
    'void',
    'Never',
    'dynamic',
    'Object',
    'bool',
    'String',
    'int',
    'double',
    'num',
    'DateTime',
  };

  static final RegExp _collectionType = RegExp(r'^(List|Set|Iterable)<(.+)>$');

  /// The MockData binding an entity-shaped declared [returnType] wires
  /// to (bug #1500): the base entity plus the type-correct accessor —
  /// `sample<E>` for `E`/`E?`, `sampleList` for `List<E>`/`Iterable<E>`,
  /// `sampleList.toSet()` for `Set<E>`. Null when the return needs no
  /// mock data (scalars, Map shapes).
  ///
  /// Review finding (pull/1516): the nullability marker is stripped
  /// BEFORE the collection unwrap, so a nullable collection
  /// (`List<Task>?`) binds too — a non-null `sampleList` is a valid
  /// `List<Task>?`, whereas the previous order left it unbound and
  /// rendered `return null as List<Task>?;`.
  static ({String entity, String accessor})? _mockBindingFor(
    String returnType,
  ) {
    var t = returnType.trim();
    if (t.endsWith('?')) t = t.substring(0, t.length - 1).trim();
    var collection = false;
    var setShaped = false;
    while (true) {
      final m = _collectionType.firstMatch(t);
      if (m == null) break;
      if (m.group(1) == 'Set') setShaped = true;
      t = m.group(2)!.trim();
      collection = true;
    }
    if (t.startsWith('Map<')) return null;
    if (_nonEntityBases.contains(t)) return null;
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(t)) return null;
    final accessor = !collection
        ? 'sample$t'
        : setShaped
        ? 'sampleList.toSet()'
        : 'sampleList';
    return (entity: t, accessor: accessor);
  }

  /// Where `zfa mock create --name <Entity>` wrote the entity's mock
  /// data: the canonical `<cwd>/lib/src/data/mock/<snake>_mock_data.dart`
  /// first, then a recursive search fallback (mirrors
  /// [locateEntityFile]'s leniency). Null when the pipeline's mock
  /// create step was skipped — the caller misfire-stops naming it.
  Future<String?> _locateMockDataFile(String cwd, String entityName) async {
    final snake = toSnakeCase(entityName);
    final mockRoot = Directory(p.join(cwd, 'lib', 'src', 'data', 'mock'));
    final canonical = File(p.join(mockRoot.path, '${snake}_mock_data.dart'));
    if (await canonical.exists()) return canonical.path;
    if (!await mockRoot.exists()) return null;
    final target = '${snake}_mock_data.dart';
    await for (final f in mockRoot.list(recursive: true)) {
      if (f is File && p.basename(f.path) == target) return f.path;
    }
    return null;
  }

  /// The behavior description the record carries — the record's own
  /// parsing contract ([ArtifactRecord.descriptionSegment]), shared with
  /// make/func/compose (bug #871: legacy `<id> — ` echoes stripped).
  static String _descriptionFor(ArtifactRecord record) =>
      record.descriptionSegment;

  String _renderWired({
    required ArtifactRecord record,
    required DerivedSignature derived,
    required String effectiveReturnType,
    required String functionName,
    required String stubParams,
    required String entityName,
    required String entityImport,
    String? declaredEntityImport,
    String? mockImport,
    String? mockReference,
  }) {
    final description = _descriptionFor(record);
    // Bug #1500: a description-derived explicit body is honored only
    // when its inferred type MATCHES the effective return — the
    // declared contract outranks prose inference, so a declared
    // `-> Task` never renders an int literal under a Task signature.
    final explicitBody =
        derived.explicitBody != null &&
            derived.returnType.trim() == effectiveReturnType.trim()
        ? derived.explicitBody
        : null;

    String body;
    if (effectiveReturnType == 'void') {
      body =
          '''
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entityName;
''';
    } else if (explicitBody != null) {
      body =
          '''
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entityName;
  $explicitBody
''';
    } else if (effectiveReturnType == 'String') {
      body =
          '''
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entityName;
  return '$functionName';
''';
    } else {
      // Bug #920 review: the previous `return 0;` fallback produced a
      // type-wrong body for any non-int/String derived type (bool,
      // List<String>, Map<String, Object?>, double, etc.) once a future
      // matcher added the type without an explicit body. Route through
      // `_defaultBodyFor` so the literal is type-correct by construction.
      // Bug #1500: entity-shaped returns carry [mockReference] so the
      // body binds to the generated MockData sample, never a cast null.
      body =
          '''
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entityName;
  ${_defaultBodyFor(effectiveReturnType, functionName, mockReference: mockReference)}
''';
    }
    return '''
// GENERATED IMPLEMENTATION — `zfa tdd wire ${record.behaviorId}` (bug
// #610; epic 045 precondition 5: the subject is wired by a
// generation-pipeline step, never by a wrapper or by hand).
//
// behavior_id: ${record.behaviorId}
// source_criterion: ${record.sourceCriterion}
// entity: $entityName
// description: $description
//
// This replaces the `zfa tdd gen` stub with the minimal wired
// implementation (spec 047 FR-005): the generated entity $entityName is
// the implementation anchor. Extend the body with real behavior in
// later cycles — the paired test file is immutable (044 ownership).
library;

import '$entityImport';
${declaredEntityImport == null ? '' : "import '$declaredEntityImport';\n"}${mockImport == null ? '' : "import '$mockImport';\n"}
/// Subject for behavior ${record.behaviorId}, wired to entity
/// $entityName by the generation pipeline.
$effectiveReturnType $functionName($stubParams) {$body}
''';
  }

  /// Minimal compilable return for a wired subject whose description
  /// implies [returnType] but yielded no explicit body. Bug #920 review
  /// — the previous `return 0;` was type-wrong for any non-int type.
  /// Bug #1500: an entity-shaped return binds to the MockData sample
  /// via [mockReference] (`TaskMockData.sampleTask` / `.sampleList`) —
  /// never a `return null as Task;` runtime cast error.
  static String _defaultBodyFor(
    String returnType,
    String functionName, {
    String? mockReference,
  }) {
    switch (returnType) {
      case 'bool':
        return 'return false;';
      case 'double':
        return 'return 0.0;';
      case 'List<String>':
        return 'return const <String>[];';
      case 'Map<String, Object?>':
        return 'return const <String, Object?>{};';
      case 'int':
        return 'return 0;';
      case 'num':
        // Review finding 3 (pull/1516): `num` is refused a mock binding
        // (no `<E>MockData` surface) but previously fell through to
        // `return null as num;` — a runtime TypeError. An int literal IS
        // a num.
        return 'return 0;';
      case 'DateTime':
        // Review finding 3 (pull/1516): `DateTime` is likewise refused a
        // mock binding; `DateTime.now()` is the compiling literal (no
        // import — dart:core).
        return 'return DateTime.now();';
      case 'String':
        return "return '$functionName';";
      default:
        // Issue #1500: the pipeline generated the value one step
        // earlier (`zfa mock create`) — bind to it.
        if (mockReference != null) return 'return $mockReference;';
        // Unknown type — emit a null cast so the stub compiles; the
        // real contract must replace this body in a later cycle.
        return 'return null as $returnType;';
    }
  }

  /// The `package:<name>/...` import for [entityFile] under [cwd],
  /// resolved from the target project's pubspec `name:`.
  String _packageImportFor(String cwd, String entityFile) {
    final pubspec = File(p.join(cwd, 'pubspec.yaml'));
    var pkg = 'app';
    if (pubspec.existsSync()) {
      final m = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec.readAsStringSync());
      if (m != null) pkg = m.group(1)!;
    }
    final rel = p.relative(entityFile, from: p.join(cwd, 'lib'));
    return 'package:$pkg/$rel';
  }

  /// Canonicalize [path] when the file itself does not exist yet: walk up
  /// to the nearest EXISTING ancestor, resolve THAT through symlinks, and
  /// re-append the remaining (missing) segments. Returns [path] unchanged
  /// when no ancestor resolves (pull/1516 review: a symlinked temp root
  /// must not make the project's own recorded subject path compare as
  /// outside the project root).
  static Future<String> _canonicalizeMissingPath(String path) async {
    var dir = Directory(p.dirname(path));
    final tail = <String>[p.basename(path)];
    while (true) {
      try {
        final resolved = await dir.resolveSymbolicLinks();
        return p.joinAll([resolved, ...tail.reversed]);
      } on FileSystemException {
        final parent = dir.parent;
        if (parent.path == dir.path) return path;
        tail.add(p.basename(dir.path));
        dir = parent;
      }
    }
  }

  Future<_Resolved?> _resolve(
    String cwd,
    String behaviorId,
    String? featureFlag,
  ) async {
    final matches = <_Resolved>[];
    for (final entry in await _scanRegistries(cwd, featureFlag)) {
      final record = await entry.registry.findRecord(behaviorId);
      if (record != null) {
        matches.add(_Resolved(record, entry.featureName, entry.featureDir));
      }
    }
    if (matches.length > 1) {
      final list = matches.map((m) => m.featureName).join(', ');
      throw _WireResolutionError(
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
        _RegistryEntry(
          featureFlag,
          ArtifactRegistry(featureDir: featureDir),
          featureDir,
        ),
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
            dir.path,
          ),
        );
      }
    }
    return entries;
  }

  void _printSummary({
    required String behavior,
    required WireOutcome outcome,
    required String feature,
  }) {
    print('wire: behavior=$behavior outcome=${outcome.label} feature=$feature');
    // Issue #969: the outcome label IS the exit class.
    _verdict
      ..exitClass = outcome.label
      ..outcome = switch (outcome) {
        WireOutcome.wired => VerdictOutcome.pass,
        WireOutcome.alreadyWired => VerdictOutcome.stopped,
        WireOutcome.runnerError => VerdictOutcome.fail,
      }
      ..details['behavior'] = behavior
      ..feature = feature == 'unknown' ? null : feature;
  }
}

class _WireResolutionError implements Exception {
  _WireResolutionError(this.message);
  final String message;
  @override
  String toString() => message;
}

class _RegistryEntry {
  const _RegistryEntry(this.featureName, this.registry, this.featureDir);
  final String featureName;
  final ArtifactRegistry registry;

  /// The feature directory the registry was resolved from — the
  /// declared-signature source (bug #1500: the same directory gen read
  /// the test-list/spec pair from).
  final String featureDir;
}

class _Resolved {
  const _Resolved(this.record, this.featureName, this.featureDir);
  final ArtifactRecord record;
  final String featureName;
  final String featureDir;
}
