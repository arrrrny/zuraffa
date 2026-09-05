/// Acceptance behaviors A1–A3 + U9 for spec 1010-zfa-dream-one-command-app
/// (tdd/test-list.md): the `zfa dream` orchestrator.
///
/// A1–A3 drive `DreamRunner.execute` with a fake LLM and a spawner that
/// delegates ingest/plan to the REAL in-process commands (a fresh
/// CliRunner per step — the reentrancy guard is instance-level, and the
/// steps are awaited sequentially) while scripting the engine/skin/git
/// phases. The cycle-log is seeded into the fixture (the state a real
/// engine run leaves behind) so the engine receipt carries real
/// artifacts. U9 drives the REAL `zfa dream` CLI through
/// `runCapturing` with an exec-forwarder fake zfa bin (the sc_018
/// pattern): ingest/plan forward to the real CLI, run/view are canned.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/agent/runtime/llm_client.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/dream_runner.dart';

void main() {
  late Directory tmp;
  late List<String> emitted;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dream_cmd_');
    emitted = <String>[];
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  const feature = '001-favorite-deal';
  const description =
      'A page that lists the user\'s favorite deals, sorted by expiration';

  const validSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 001-favorite-deal

## Functional Requirements

- **FR-001**: list the favorite deals sorted by expiration

## Acceptance Scenarios

1. **Given** a fresh state **When** the user opens the page **Then** the
   deals are listed
   **Type**: widget

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| FavoriteDeal | `id: String`, `title: String` | One saved deal |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| Hive | storage | `read(key) -> FavoriteDeal?` | P1 |

## Layer Contracts

**Domain**:

- `FavoriteDealRepository`: `list() -> Future<Result<List<FavoriteDeal>, AppFailure>>`

## AdaptiveViewSlots

| Slot | Breakpoint | Content |
|------|-----------|---------|
| primary | default | the deals list |

## Skin Contract

| Token | Value | Source |
|-------|-------|--------|
| spacing | default | framework theme |
''';

  const validPlan = '''
# Implementation Plan: 001-favorite-deal

**Branch**: `001-favorite-deal` | **Spec**: specs/001-favorite-deal/spec.md

## Summary

A page that lists the user's favorite deals, sorted by expiration.
''';

  /// A fake LLM whose drafts are real schema-valid specs. [drafts] is
  /// consumed in order; the Nth call returns drafts[N].
  _ScriptedLlm llm(List<({String spec, String plan})> drafts) =>
      _ScriptedLlm(drafts);

  _ScriptedSpawner spawner({
    String runResult = 'complete',
    int runExit = 0,
    String viewOutcome = 'already-implemented',
    String currentBranch = 'master',
  }) => _ScriptedSpawner(
    runResult: runResult,
    runExit: runExit,
    viewOutcome: viewOutcome,
    currentBranch: currentBranch,
  );

  Future<void> seedCycleLog() async {
    final tdd = Directory(p.join(tmp.path, 'specs', feature, 'tdd'));
    await tdd.create(recursive: true);
    await File(p.join(tdd.path, 'cycle-log.md')).writeAsString('''
# Cycle Log: $feature

- schema: 1

## Cycle: A-1 (green)

- behavior: A-1
- kind: green
- criterion: FR-001
- exit: 0
- at: 2026-09-05T00:00:00.000Z
''');
    await File(p.join(tdd.path, 'run-state.json')).writeAsString(
      '{"feature": "$feature", "behavior_states": {"A-1": "done"}}',
    );
  }

  List<File> dreamReceipts() => Directory(p.join(tmp.path, '.zfa', 'receipts'))
      .listSync()
      .whereType<File>()
      .where((f) => p.basename(f.path).contains('dream-'))
      .toList();

  Directory featureDir() => Directory(p.join(tmp.path, 'specs', feature));

  test('A1: full happy path — spec + 3 plan files + cycle-log + 2 receipts '
      '+ ready PR argv + exit 0', () async {
    final fx = spawner();
    await seedCycleLog();

    final code = await DreamRunner.execute(
      description: description,
      feature: feature,
      projectFlag: tmp.path,
      llmClient: llm([(spec: validSpec, plan: validPlan)]),
      zfaSpawner: fx.zfa,
      procSpawner: fx.proc,
      emit: emitted.add,
    );

    expect(code, 0, reason: emitted.join('\n'));
    final summary = emitted.last;
    expect(
      summary,
      matches(
        RegExp(
          r'^dream: feature=\S+ result=complete drafter=llm attempts=1 '
          r'engine=green skin=green pr=\S+$',
        ),
      ),
      reason: summary,
    );

    // The feature dir + the artifact set (spec + 3 plan files + draft).
    expect(featureDir().existsSync(), isTrue, reason: emitted.join('\n'));
    for (final rel in [
      'spec.md',
      'plan.md',
      'tdd/test-list.md',
      'tdd/traceability.md',
      'tdd/draft-spec.md',
      'tdd/cycle-log.md',
    ]) {
      expect(
        File(p.join(featureDir().path, rel)).existsSync(),
        isTrue,
        reason: 'missing $rel',
      );
    }

    // Exactly 2 dream receipts (engine + skin), carrying the cycle-log.
    final receipts = dreamReceipts();
    expect(receipts.length, 2, reason: receipts.map((f) => f.path).join(','));
    final bodies = receipts
        .map((f) => f.readAsStringSync())
        .toList()
        .join('\n');
    expect(bodies, contains('"command": "dream-engine"'));
    expect(bodies, contains('"command": "dream-skin"'));
    expect(bodies, contains('cycle-log.md'));

    // The PR argv: feature branch created, artifacts added+committed,
    // pushed, PR created WITHOUT --draft (engine green).
    final gitLog = fx.procLog.where((a) => a.first == 'git').toList();
    final git = gitLog.map((a) => a.join(' ')).join('\n');
    expect(
      git,
      contains('checkout -b $feature'),
      reason:
          'dream starts from the default branch and must create the '
          'feature branch (AGENTS.md branch=feature-dir convention)',
    );
    expect(git, contains('add specs/$feature'));
    expect(git, contains('commit'));
    expect(git, contains('push'));
    expect(fx.ghArgv, isNot(contains('--draft')));
    expect(fx.ghArgv.join(' '), contains('pr create'));
    expect(fx.ghArgv.join(' '), contains('--head $feature'));
  });

  test('A2: colliding first draft — refusal reaches the LLM re-prompt; '
      'renamed second draft accepted; attempts=2', () async {
    final fx = spawner();
    // First draft collides with a real framework export (bug #942's
    // Credentials), second renames per the --> fix: suggestion.
    final colliding = validSpec.replaceAll('FavoriteDeal', 'Credentials');

    final fake = _ScriptedLlm([
      (spec: colliding, plan: validPlan),
      (spec: validSpec, plan: validPlan),
    ]);

    // Seed the framework surface so the collision is deterministically
    // detected in-process (the framework_export_surface_test pattern).
    await _seedFrameworkSurface(tmp);

    final code = await DreamRunner.execute(
      description: description,
      feature: feature,
      projectFlag: tmp.path,
      llmClient: fake,
      zfaSpawner: fx.zfa,
      procSpawner: fx.proc,
      emit: emitted.add,
    );

    expect(code, 0, reason: emitted.join('\n'));
    expect(
      fake.prompts.length,
      2,
      reason: 'the LLM must be re-prompted exactly once',
    );
    // The refusal text reached the second prompt (deliverable 1b).
    expect(
      fake.prompts[1],
      anyOf(contains('entity name collision'), contains('Credentials')),
      reason: fake.prompts[1],
    );
    // The colliding draft never landed as spec.md.
    expect(
      File(p.join(featureDir().path, 'spec.md')).readAsStringSync(),
      contains('FavoriteDeal'),
    );
    expect(emitted.last, contains('attempts=2'));
  });

  test('A3: scaffolded skin → hand-edit branch + pending receipt; '
      'non-green engine → PR --draft + exit 1', () async {
    final fx = spawner(
      runResult: 'stopped',
      runExit: 1,
      viewOutcome: 'scaffolded',
    );
    await seedCycleLog();

    final code = await DreamRunner.execute(
      description: description,
      feature: feature,
      projectFlag: tmp.path,
      llmClient: llm([(spec: validSpec, plan: validPlan)]),
      zfaSpawner: fx.zfa,
      procSpawner: fx.proc,
      emit: emitted.add,
    );

    expect(code, 1, reason: emitted.join('\n'));
    final summary = emitted.last;
    expect(summary, contains('engine=stopped'));
    expect(summary, contains('skin=hand-edit'));
    expect(summary, contains('pr=draft'));
    // The hand-edit branch was opened for the human/agent.
    expect(
      fx.procLog.map((a) => a.join(' ')).join('\n'),
      contains('checkout -b skin/$feature'),
    );
    // The PR argv carried --draft because the engine is not green.
    expect(fx.ghArgv, contains('--draft'));
    // The skin receipt records the pending hand-edit.
    final skin = dreamReceipts()
        .map((f) => f.readAsStringSync())
        .firstWhere((b) => b.contains('"dream-skin"'));
    expect(skin, contains('hand-edit'));
  });

  test('U9 (fast): `zfa dream` is a registered top-level command with '
      'argument validation', () async {
    final runner = CliRunner(exitOnCompletion: false);

    // RED on master: "Could not find a command named dream" (exit 64).
    final out = await runner.runCapturing(['dream']);
    expect(out, contains('dream'));
    expect(
      out,
      isNot(contains('Could not find a command named "dream"')),
      reason: out,
    );
    expect(exitCode, 64, reason: 'a missing description is a usage error');
    expect(out, contains('A feature description is required'));

    exitCode = 0;
    final out2 = await runner.runCapturing([
      'dream',
      description,
      '--project',
      tmp.path,
      '--max-retries',
      'not-a-number',
    ]);
    expect(out2, contains('--max-retries must be an integer'));
    expect(exitCode, 64);
  });
}

// ---------------------------------------------------------------------
// Fakes & helpers
// ---------------------------------------------------------------------

/// Seeds a fake zuraffa package exporting `Credentials` and wires it via
/// the fixture's package_config (framework_export_surface_test pattern)
/// so the in-process ingest gate sees a deterministic surface.
Future<void> _seedFrameworkSurface(Directory tmp) async {
  final dep = Directory(p.join(tmp.path, 'dep', 'lib'));
  await dep.create(recursive: true);
  await File(
    p.join(dep.path, 'zuraffa.dart'),
  ).writeAsString('class Credentials {}\n');
  final dartTool = Directory(p.join(tmp.path, '.dart_tool'));
  await dartTool.create(recursive: true);
  await File(p.join(dartTool.path, 'package_config.json')).writeAsString(
    jsonEncode({
      'configVersion': 2,
      'packages': [
        {'name': 'zuraffa', 'rootUri': 'file://${tmp.path}/dep'},
      ],
    }),
  );
}

class _ScriptedLlm implements LlmClient {
  _ScriptedLlm(this.drafts);

  final List<({String spec, String plan})> drafts;
  final List<String> prompts = <String>[];
  var _calls = 0;

  @override
  Future<String> complete(String prompt) async {
    prompts.add(prompt);
    final i = _calls < drafts.length ? _calls : drafts.length - 1;
    _calls++;
    final d = drafts[i];
    return '```dream-spec\n${d.spec}\n```\n'
        '```dream-plan\n${d.plan}\n```';
  }
}

/// Delegates ingest/plan to the REAL in-process commands; scripts
/// run/view/git/gh; records every argv.
class _ScriptedSpawner {
  _ScriptedSpawner({
    this.runResult = 'complete',
    this.runExit = 0,
    this.viewOutcome = 'already-implemented',
    this.currentBranch = 'master',
  });

  final String runResult;
  final int runExit;
  final String viewOutcome;
  final String currentBranch;

  final List<List<String>> zfaLog = <List<String>>[];
  final List<List<String>> procLog = <List<String>>[];
  List<String> get ghArgv =>
      procLog.firstWhere((a) => a.first == 'gh', orElse: () => const []);

  /// The zfa command spawner: argv is the command tail
  /// (['tdd', 'ingest', ...]).
  Future<ProcessResult> zfa(List<String> argv, String cwd) async {
    zfaLog.add(List.of(argv));
    if (argv[0] == 'tdd' && (argv[1] == 'ingest' || argv[1] == 'plan')) {
      // REAL command, in-process, hermetic.
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(argv);
      final code = exitCode;
      exitCode = 0;
      return ProcessResult(0, code, out, '');
    }
    if (argv[0] == 'tdd' && argv[1] == 'run') {
      final featureArg = argv[2];
      return ProcessResult(
        0,
        runExit,
        '[run] ...\n'
            'run: feature=$featureArg result=$runResult pending=1 red=0 '
            'green=0 done=0',
        '',
      );
    }
    if (argv[0] == 'tdd' && argv[1] == 'view') {
      final id = argv[2];
      final featureArg = _flagValue(argv, '--feature') ?? '';
      return ProcessResult(
        0,
        0,
        'view: behavior=$id outcome=$viewOutcome feature=$featureArg',
        '',
      );
    }
    return ProcessResult(0, 0, 'dream-test: unscripted ${argv.join(' ')}', '');
  }

  /// The git/gh spawner.
  Future<ProcessResult> proc(List<String> argv, String cwd) async {
    procLog.add(List.of(argv));
    if (argv.first == 'git' && argv.length > 1 && argv[1] == 'rev-parse') {
      return ProcessResult(0, 0, currentBranch, '');
    }
    if (argv.first == 'gh') {
      return ProcessResult(
        0,
        0,
        'https://github.com/arrrrny/zuraffa/pull/1234',
        '',
      );
    }
    return ProcessResult(0, 0, '', '');
  }
}

String? _flagValue(List<String> argv, String flag) {
  final i = argv.indexOf(flag);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : null;
}
