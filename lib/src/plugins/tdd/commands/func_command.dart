/// `zfa tdd func <behavior-id>` — the plain-function generator surface
/// (bug #657).
///
/// Bug #657: the generation planner only mapped behavior descriptions to
/// `zfa entity create` (domain models), `zfa make` (repositories,
/// services, providers), and `zfa build` (build targets). Plain functions
/// (rendering, formatting, parsing, computing, pure logic) had no
/// generator surface, so `zfa tdd make` honestly reported them
/// `unexpressible` — and the TDD run blocked the whole feature at the
/// first such behavior.
///
/// This command is the missing surface, scoped to the tdd plugin for the
/// same reason `zfa tdd wire` is (bug #610 design decision): the subject
/// contract (`lib/tdd/<id>_subject.dart` equivalents under the registry's
/// `subject_path`, SubjectWriter, registry artifacts) is owned by the
/// tdd plugin, and a core command would need a core→plugin dependency the
/// architecture forbids (plugins depend on core, never the reverse).
///
/// The command:
///   1. Resolves the behavior's registry record (same resolution rules
///      as `wire`/`make`) and its `subject_path` artifact.
///   2. Derives only the return type from the behavior DESCRIPTION (never
///      from the test): a described result such as "returns a non-empty
///      string", "returns 42", or "return true when ..." maps to String,
///      int, or bool (with support for double / List / Map and a String
///      fallback). The function name and no-argument shape come from the
///      generated subject stub because the behavior record carries no input
///      parameter schema and the paired generated test invokes it with no args.
///   3. Replaces only the subject stub declaration containing
///      `UnimplementedError` with the minimal implementation satisfying the
///      described contract (spec 047 FR-005 minimal generation). The paired
///      test file is never
///      touched (044 ownership contract), and the stub's function NAME
///      is preserved so the immutable test keeps compiling against it.
///      Issue #1517: when the installed body is a DUMMY (not a still-red
///      scaffold), the gen-time honest-red claims the stub header and doc
///      comment carry are reconciled to the scaffolded-dummy state — the
///      file describes the state it actually contains; contract traces
///      are preserved verbatim.
///   4. Is idempotent: a subject with no `UnimplementedError` left is
///      reported `already-implemented` and exits 0, so a resumed
///      pipeline re-running the step stays green.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/routing.dart';
import '../services/artifact_registry.dart';
import '../services/declared_routing.dart';
import '../services/subject_signature_deriver.dart';
import '../services/tdd_generation_receipt.dart';
import '../services/unit_contract_shape.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

/// Outcome labels for the machine-readable summary line.
enum FuncOutcome {
  scaffolded('scaffolded'),
  alreadyImplemented('already-implemented'),
  runnerError('runner-error');

  const FuncOutcome(this.label);
  final String label;
}

class FuncCommand extends Command<void> {
  FuncCommand(this.plugin) {
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
  String get name => 'func';

  @override
  String get description =>
      'Scaffold the plain-function subject of a behavior (render, format, '
      'parse, compute, ...) with a description-derived return type '
      '— the function-generation surface of the pipeline (bug #657).';

  @override
  String get invocation =>
      'zfa tdd func <behavior-id> [--feature <name>] [--project <path>]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    if (behaviorId == null || behaviorId.isEmpty) {
      print('zfa tdd func: behavior id is required. Usage: $invocation');
      _printSummary(
        behavior: '-',
        outcome: FuncOutcome.runnerError,
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
    } on _FuncResolutionError catch (e) {
      print('zfa tdd func: ${e.message}');
      _printSummary(
        behavior: behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    if (resolved == null) {
      print(
        'zfa tdd func: unknown behavior id "$behaviorId". No matching '
        'record in any specs/<feature>/tdd/artifacts.json'
        '${featureFlag != null && featureFlag.isNotEmpty ? ' for feature $featureFlag' : ''}. Run `zfa tdd gen $behaviorId` first.',
      );
      _printSummary(
        behavior: behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = resolved.record;
    final description = _descriptionFor(record);
    print('zfa tdd func: behavior ${record.behaviorId}');
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
        'zfa tdd func: the registry record for behavior '
        '"${record.behaviorId}" points outside the project root at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) {
      print(
        'zfa tdd func: the registry record for behavior '
        '"${record.behaviorId}" points to a missing subject file at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    // -------------------------------------------------------------
    // 3. Parse the stub and emit the scaffolded implementation.
    // -------------------------------------------------------------
    final raw = await subjectFile.readAsString();
    final stub = _stubSignature.firstMatch(raw);
    if (stub == null) {
      // Spec 0806 FR-006 (convergent generation): the refusal must key on
      // an ACTUAL `throw UnimplementedError(…)` the command might have
      // generated — not the word appearing anywhere. Every scaffolded
      // subject keeps the stub header's doc comment ("Throws
      // [UnimplementedError] until the real implementation lands.") AFTER
      // implementation, so a substring check refuses every already-done
      // subject and breaks deterministic replay of recorded `tdd func`
      // steps (exit 1 on a converged tree).
      final hasUnimplementedThrow = _unimplementedThrow.hasMatch(raw);
      if (hasUnimplementedThrow) {
        print(
          'zfa tdd func: subject at "$recordedSubject" carries an '
          'UnimplementedError in an unrecognized shape — refusing to '
          'rewrite a file this command did not generate.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: FuncOutcome.runnerError,
          feature: resolved.featureName,
        );
        exitCode = 1;
      } else {
        // Idempotent re-run (resumed pipeline): nothing to do.
        print(
          'zfa tdd func: subject at "$recordedSubject" is already '
          'implemented — nothing to scaffold.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: FuncOutcome.alreadyImplemented,
          feature: resolved.featureName,
        );
        exitCode = 0;
      }
      return;
    }
    // The stub's function NAME is preserved: the paired (immutable) test
    // calls `subject.<name>()` and must keep compiling against the
    // scaffolded signature (044 ownership contract).
    final functionName = stub.group(2)!;
    final stubParams = (stub.group(3) ?? '').trim();

    // Feature 071 (issue #920's durable fix): a DECLARED signature from
    // the behavior's function contract row outranks prose inference.
    // Undeclared behaviors keep the description-keyed deriver (the
    // labeled fallback; strict surfaces are handled at plan).
    // Round-2 review fix 3c: a MALFORMED declaration propagates out of
    // the lookup as a StateError — surfaced here as a refusal (exit 1
    // + fix message), never a silent prose-inference fallback.
    final Signature? declared;
    try {
      declared = await DeclaredRouting.declaredSignatureFor(
        cwd: cwd,
        featureName: resolved.featureName,
        behaviorId: record.behaviorId,
      );
    } on StateError catch (e) {
      print('zfa tdd func: declaration refused — ${e.message}');
      _printSummary(
        behavior: record.behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    // Issue #1259: a PARAMETRIZED stub without a declaration cannot be
    // rewritten from prose — the behavior record carries no input schema
    // (the reason the legacy surface was no-arg), so rewriting the
    // declared parametrized shape to an invented no-arg body would break
    // the paired test's invocation (and re-open the invented-shape
    // class). Refuse with the remedy; the declared path below serves
    // every stub gen writes for contract-declared behaviors.
    if (declared == null && stubParams.isNotEmpty) {
      print(
        'zfa tdd func: subject at "$recordedSubject" carries a parametrized '
        'signature but the behavior declares no contract row to derive it '
        'from — refusing to invent a shape (issue #1259).',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    final scaffolded = _renderScaffolded(
      description: description,
      functionName: functionName,
      declared: declared,
    );
    var updated = raw.replaceRange(stub.start, stub.end, scaffolded);
    // Issue #1517: a DUMMY body invalidates the gen-time honest-red
    // claims the stub header and doc comment carry ("MINIMAL COMPILABLE
    // STUB ... honest red", "Throws [UnimplementedError] until the real
    // implementation lands."). The file must describe the state it
    // actually contains — reconcile the claims. A still-red scaffold (a
    // non-renderable declared return that keeps UnimplementedError) is
    // left alone: its claims remain true there.
    if (!scaffolded.contains('UnimplementedError')) {
      updated = _reconcileHeaderClaimsForDummyBody(updated);
    }
    await subjectFile.writeAsString(updated);
    // Issue #969 T003: the scaffolded subject becomes self-certifying.
    await TddGenerationReceipts.writeBestEffort(
      projectRoot: cwd,
      command: 'tdd func',
      target: record.behaviorId,
      feature: resolved.featureName,
      files: {subjectFile.path: 'update'},
    );
    print('   scaffolded: $recordedSubject');
    _printSummary(
      behavior: record.behaviorId,
      outcome: FuncOutcome.scaffolded,
      feature: resolved.featureName,
    );
    exitCode = 0;
  }

  // -------------------------------------------------------------------
  // Resolution + rendering helpers.
  // -------------------------------------------------------------------

  /// The stub declaration func rewrites: the shapes gen emits for the
  /// unit lane — the legacy no-arg int/void stub (issue #657) and the
  /// contract-derived shape (issue #1259: scalar declared types verbatim,
  /// entity types degraded to `Object?`), with an optional parameter
  /// list. A bounded type set (never an arbitrary identifier) keeps the
  /// "this command did not generate" safety: a hand-authored subject
  /// typed by an entity (`User login(...) => throw ...`) still refuses.
  static final RegExp _stubSignature = RegExp(
    r'^((?:int|void|String|bool|double|num|Object|dynamic)\??)'
    r'[ \t]+([A-Za-z_][A-Za-z0-9_]*)\(([^)]*)\)[ \t]*=>[ \t]*'
    r'throw[ \t]+UnimplementedError\([^;\r\n]*\);[ \t]*$',
    multiLine: true,
  );

  /// Spec 0806 FR-006: an actual throw statement — what the refusal keys
  /// on. Distinguished from the stub header's doc comment, which merely
  /// mentions `UnimplementedError` and survives implementation.
  static final RegExp _unimplementedThrow = RegExp(
    r'throw[ \t]+(?:const[ \t]+)?UnimplementedError\s*\(',
  );

  // -------------------------------------------------------------------
  // Issue #1517: header/doc reconciliation for the scaffolded-dummy
  // state. SubjectWriter bakes honest-red claims into the stub header
  // ("MINIMAL COMPILABLE STUB ... honest red") and doc comment ("Throws
  // [UnimplementedError] until the real implementation lands.") —
  // gen-time-accurate, fill-time-stale: once func installs a dummy body
  // the paired test compiles and may go green on the dummy alone. When
  // the body func just installed is a DUMMY, the claims below are
  // rewritten to the scaffolded-dummy state. The patterns tolerate the
  // `// `/`/// ` prefixes and the exact line wraps SubjectWriter emits.
  // -------------------------------------------------------------------

  /// The scaffolded-dummy state claim (the header variant).
  static const _dummyHeaderClaim =
      'Scaffolded dummy per `zfa tdd func` (issue #1517): the body below '
      'is a placeholder that compiles against the signature — the paired '
      'test may pass on this dummy alone. Replace this dummy body with '
      'the real implementation.';

  /// The scaffolded-dummy state claim (the doc-comment variant).
  static const _dummyDocClaim =
      'Scaffolded dummy per `zfa tdd func` (issue #1517) — replace this '
      'dummy body with the real implementation.';

  /// The gen-time honest-red claim sentences SubjectWriter renders into
  /// the unit / acceptance / contract-derived stub headers, and the doc
  /// comment line every stub carries.
  static final List<RegExp> _staleHeaderClaims = [
    _claimPattern(
      'This is a MINIMAL COMPILABLE STUB. It compiles cleanly (FR-011) but '
      'does NOT satisfy the behavior described above — the paired test '
      'will fail on first execution with an assertion-level failure '
      '(honest red). Replace this stub body with real implementation to '
      'make the test pass.',
    ),
    _claimPattern(
      'This is a MINIMAL COMPILABLE acceptance-scenario stub. It compiles '
      'cleanly (FR-011) but does NOT satisfy the behavior described above '
      '— the paired test will fail on first execution with an '
      'assertion-level failure (honest red). The acceptance subject '
      'intentionally does NOT reference any entity/use case/repository '
      '(FR-004): it stands alone. Replace this stub body with real '
      'implementation to make the test pass.',
    ),
    _claimPattern(
      'This is a MINIMAL COMPILABLE STUB: it does NOT satisfy the behavior '
      '— the paired test fails on first execution (honest red). Replace '
      'this stub body with the real implementation of the declared '
      'contract to make the test pass.',
    ),
    _claimPattern(
      'Throws [UnimplementedError] until the real implementation lands.',
    ),
  ];

  /// Builds a pattern matching [sentence] even where SubjectWriter wraps
  /// it across comment lines: a space matches intra-line whitespace OR a
  /// newline followed by the next line's comment prefix (consumed, so
  /// replacements must re-supply prefixes).
  static RegExp _claimPattern(String sentence) {
    final body = sentence
        .split(' ')
        .map(RegExp.escape)
        .join(r'(?:[ \t]+|\r?\n[ \t]*(?://+)[ \t]*)');
    return RegExp(body);
  }

  /// Rewrites the gen-time honest-red claims for the scaffolded-dummy
  /// state (issue #1517). Contract traces (behavior_id, source_criterion,
  /// description, declared-signature fence, declared parameters) are
  /// preserved verbatim — the rewrite only touches claim sentences.
  static String _reconcileHeaderClaimsForDummyBody(String source) {
    var updated = source;
    for (final claim in _staleHeaderClaims) {
      updated = updated.replaceAllMapped(claim, (m) {
        final isDocClaim = m.input.substring(m.start, m.end).startsWith(
              'Throws [UnimplementedError]',
            );
        final replacement = isDocClaim ? _dummyDocClaim : _dummyHeaderClaim;
        final lineStart =
            m.start == 0 ? 0 : m.input.lastIndexOf('\n', m.start - 1) + 1;
        final beforeMatch = m.input.substring(lineStart, m.start);
        // The match starts the line's content (only a comment prefix
        // before it): the prefix stays, the replacement splices in.
        if (beforeMatch.isEmpty || RegExp(r'^[/]+[ \t]*$').hasMatch(beforeMatch)) {
          return replacement;
        }
        // A claim replaced mid-line (the contract-unit sentence starts
        // after "when implementing. ") moves to its own comment line,
        // prefixed like the line it came from.
        final prefix = RegExp(r'[/]+[ \t]*')
            .firstMatch(beforeMatch)
            ?.group(0);
        return prefix == null
            ? '\n$replacement'
            : '\n$prefix$replacement';
      });
    }
    // Safety net: a claim sentence SubjectWriter may re-wrap differently
    // (template drift) or a hand-authored variant must not survive as a
    // stale claim. Drop any comment line still carrying one of the
    // markers — trace lines are exempt so a pathological description
    // can never be torn out of the header.
    const traceKeys = [
      'behavior_id:',
      'source_criterion:',
      'description:',
      'Declared parameters:',
    ];
    const staleMarkers = [
      'honest red',
      'MINIMAL COMPILABLE',
      'does NOT satisfy',
      'assertion-level failure',
      'UnimplementedError',
    ];
    updated = updated
        .split('\n')
        .where((line) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('//')) return true;
          if (traceKeys.any(trimmed.contains)) return true;
          return !staleMarkers.any(trimmed.contains);
        })
        .join('\n');
    // A subject whose header carried no claim sentences (hand-authored
    // stub) still gets the state statement — the file must describe the
    // scaffolded-dummy state even when there was nothing stale to
    // replace.
    if (!updated.contains('Scaffolded dummy')) {
      final library = RegExp(r'^library;', multiLine: true).firstMatch(
            updated,
          );
      const note =
          '// Scaffolded dummy per `zfa tdd func` (issue #1517) — replace\n'
          '// this dummy body with the real implementation.\n';
      updated = library == null
          ? '$note$updated'
          : updated.replaceRange(library.start, library.start, note);
    }
    return updated;
  }

  /// The behavior description the record carries — the record's own
  /// parsing contract ([ArtifactRecord.descriptionSegment]), shared with
  /// make/wire/compose (bug #871: legacy `<id> — ` echoes stripped).
  static String _descriptionFor(ArtifactRecord record) =>
      record.descriptionSegment;

  String _renderScaffolded({
    required String description,
    required String functionName,
    Signature? declared,
  }) {
    // Feature 071: the declared signature is authoritative when
    // present — the prose deriver runs ONLY on the fallback branch
    // (issue #920: no invented return types when a declaration exists).
    if (declared != null) {
      // Issue #1259: the DECLARED SHAPE — params from the request
      // entity, return from the result entity — not just the return
      // type. Non-renderable declared types (entities that may not
      // exist yet) render as `Object?` and the scaffold stays red
      // (`UnimplementedError`) instead of a dummy value.
      final shape = UnitContractShape.of(declared);
      final params = shape.params.map((p) => '${p.type} ${p.name}').join(', ');
      return '''${shape.returnType} $functionName($params) {
  ${_declaredStubBody(shape.returnType, functionName, shape)}
}''';
    }
    final derived = deriveSubjectSignature(description);
    final body = derived.explicitBody ?? "return '$functionName';";
    return '''${derived.returnType} $functionName() {
  $body
}''';
  }

  /// A minimal compiling body honoring the declared return type. For
  /// non-primitive declared returns the honest scaffold stays red —
  /// `UnimplementedError` — instead of inventing a vacuous value
  /// (issue #920: a green suite that measures nothing; issue #1259: the
  /// declared entity contract is named in the error so the implementer
  /// knows the shape the spec declared).
  String _declaredStubBody(
    String returnType,
    String functionName,
    UnitContractShape shape,
  ) {
    if (returnType == 'String') return "return '$functionName';";
    if (returnType == 'int') return 'return 0;';
    if (returnType == 'double') return 'return 0.0;';
    if (returnType == 'bool') return 'return true;';
    if (returnType == 'void') return '';
    return "throw UnimplementedError('implement per declared signature: "
        '${shape.declaredSignature}\');';
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
        matches.add(_Resolved(record, entry.featureName));
      }
    }
    if (matches.length > 1) {
      final list = matches.map((m) => m.featureName).join(', ');
      throw _FuncResolutionError(
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
    required FuncOutcome outcome,
    required String feature,
  }) {
    print('func: behavior=$behavior outcome=${outcome.label} feature=$feature');
    // Issue #969: the outcome label IS the exit class.
    _verdict
      ..exitClass = outcome.label
      ..outcome = switch (outcome) {
        FuncOutcome.scaffolded => VerdictOutcome.pass,
        FuncOutcome.alreadyImplemented => VerdictOutcome.stopped,
        FuncOutcome.runnerError => VerdictOutcome.fail,
      }
      ..details['behavior'] = behavior
      ..feature = feature == 'unknown' ? null : feature;
  }
}

class _FuncResolutionError implements Exception {
  _FuncResolutionError(this.message);
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
