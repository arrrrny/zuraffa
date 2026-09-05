/// `DreamRunner` — the `zfa dream "<description>"` orchestrator (spec
/// 1010-zfa-dream-one-command-app, FR-001..FR-009): a feature
/// description in plain English produces a spec, a plan, receipts, and
/// a PR.
///
/// A THIN orchestrator over existing commands and the existing MCP v2
/// surface — every phase delegates:
///
///   1. draft      — the v2 tool `dream_draft_spec` (the only LLM seam,
///                   `LlmClient`; deterministic fallback labeled);
///   2. ingest     — `zfa tdd ingest` (the validation gate; refusal
///                   text re-prompts the draft tool, FR-003);
///   3. plan       — `zfa tdd plan` (the REAL plan artifacts; dream only
///                   writes the LLM's plan.md draft);
///   4. engine     — `zfa tdd run` to green (resumable; re-run budget);
///   5. skin       — `zfa tdd view` over the widget lane; a `scaffolded`
///                   outcome opens the `skin/<feature>` hand-edit branch;
///   6. receipts   — two `proof.v1` receipts via `ReceiptStore`
///                   (dream-engine + dream-skin);
///   7. PR         — git commit + `gh pr create` (`--draft` iff the
///                   engine is not green; `--no-pr` skips the phase).
///
/// Every zfa command and every git/gh invocation runs through an
/// injectable spawner seam (a sub-process for the real path, so a phase
/// crash cannot corrupt the orchestrator — the StepRunner pattern).
///
/// Machine contract (FR-009): the last line is
/// `dream: feature=<f> result=<complete|stopped>
/// drafter=<llm|deterministic> attempts=<n> engine=<green|stopped>
/// skin=<green|hand-edit|skipped|stopped> pr=<url|draft|none|failed>`;
/// exit 0 iff the engine is green and the PR phase (when attempted) did
/// not fail.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../agent/runtime/llm_client.dart';
import '../../../core/project/project_root.dart';
import '../../../core/project/receipt_store.dart';
import '../../../mcp/capabilities/dream_capability.dart' show DreamNouns;
import '../../../mcp/v2_tools.dart';
import '../models/behavior.dart';
import '../services/step_runner.dart';
import '../services/test_list_reader.dart';

/// Runs one zfa command (the tail, e.g. `['ttd','ingest',...]`) in
/// [cwd] and returns its process result.
typedef DreamZfaSpawner =
    Future<ProcessResult> Function(List<String> zfaTail, String cwd);

/// Runs one git/gh command (the full argv, e.g. `['git','push',...]`)
/// in [cwd].
typedef DreamProcSpawner =
    Future<ProcessResult> Function(List<String> argv, String cwd);

/// One draft attempt's decoded v2-tool payload.
class _DraftPayload {
  const _DraftPayload(this.specMarkdown, this.planMarkdown, this.drafter);

  final String specMarkdown;
  final String planMarkdown;
  final String drafter;
}

class DreamRunner {
  /// Executes the dream pipeline for [description]; returns the exit
  /// code (0 iff the engine is green and the PR phase, when attempted,
  /// did not fail).
  static Future<int> execute({
    required String description,
    String? feature,
    String? projectFlag,
    String? zfaBin,
    LlmClient? llmClient,
    int maxRetries = 3,
    int engineAttempts = 2,
    bool noPr = false,
    DreamZfaSpawner? zfaSpawner,
    DreamProcSpawner? procSpawner,
    void Function(String line) emit = print,
  }) async {
    final root = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final featureName = (feature != null && feature.isNotEmpty)
        ? feature
        : _deriveFeatureName(root, description);
    final zfa = zfaSpawner ?? _defaultZfaSpawner(zfaBin);
    final proc = procSpawner ?? _defaultProcSpawner;

    emit('[dream] feature=$featureName project=$root');
    emit('[dream] description: $description');

    // ---------------------------------------------------------------
    // 1 + 2. Draft via the MCP v2 tool; ingest; re-prompt on refusal.
    // ---------------------------------------------------------------
    _DraftPayload? accepted;
    String? refusal;
    var attempts = 0;
    var drafter = 'deterministic';
    while (attempts < maxRetries) {
      attempts++;
      emit('[dream] draft attempt $attempts/$maxRetries ...');
      final draft = await _draftViaV2Tool(
        root: root,
        feature: featureName,
        description: description,
        feedback: refusal,
        llmClient: llmClient,
      );
      drafter = draft.drafter;
      emit('[dream] drafter=${draft.drafter}');

      final draftPath = p.join(
        root,
        'specs',
        featureName,
        'tdd',
        'draft-spec.md',
      );
      await File(draftPath).parent.create(recursive: true);
      await File(draftPath).writeAsString(draft.specMarkdown);

      final tail = [
        'tdd',
        'ingest',
        featureName,
        '--draft',
        draftPath,
        '--project',
        root,
        if (attempts > 1) '--force',
      ];
      final res = await zfa(tail, root);
      final out = '${res.stdout}\n${res.stderr}'.trim();
      if (res.exitCode == 0 && out.contains('result=accepted')) {
        accepted = draft;
        emit('[dream] ingest accepted (attempt $attempts)');
        break;
      }
      refusal = out;
      emit(
        '[dream] ingest refused (exit ${res.exitCode}) — re-prompting the '
        'drafter with the refusal',
      );
    }
    if (accepted == null) {
      emit(
        '[dream] every draft was refused after $maxRetries attempts — '
        'nothing was written as spec.md and no PR was opened.',
      );
      emit(
        _summaryLine(
          featureName,
          'stopped',
          drafter,
          attempts,
          'stopped',
          'skipped',
          'none',
        ),
      );
      return 1;
    }

    // ---------------------------------------------------------------
    // 3. The plan artifacts: the LLM's plan.md draft + the REAL plan.
    // ---------------------------------------------------------------
    final planPath = p.join(root, 'specs', featureName, 'plan.md');
    await File(planPath).writeAsString(accepted.planMarkdown);
    final planRes = await zfa([
      'tdd',
      'plan',
      featureName,
      '--project',
      root,
    ], root);
    if (planRes.exitCode != 0) {
      emit(
        '[dream] zfa tdd plan failed (exit ${planRes.exitCode}) — the '
        'engine cycle cannot start without the test list.',
      );
      emit('${planRes.stdout}\n${planRes.stderr}'.trim());
      emit(
        _summaryLine(
          featureName,
          'stopped',
          drafter,
          attempts,
          'stopped',
          'skipped',
          'none',
        ),
      );
      return 1;
    }
    emit('[dream] plan ok (tdd/test-list.md, tdd/traceability.md)');

    // ---------------------------------------------------------------
    // 4. The engine cycle: zfa tdd run, to green.
    // ---------------------------------------------------------------
    var engineGreen = false;
    var engineResult = 'stopped';
    for (var i = 1; i <= engineAttempts && !engineGreen; i++) {
      final runRes = await zfa([
        'tdd',
        'run',
        featureName,
        '--project',
        root,
        if (zfaBin != null && zfaBin.isNotEmpty) ...['--zfa-bin', zfaBin],
      ], root);
      final out = '${runRes.stdout}\n${runRes.stderr}';
      final m = RegExp(r'run: feature=\S+ result=(\w+)').firstMatch(out);
      engineResult = m?.group(1) ?? 'error';
      engineGreen = runRes.exitCode == 0 && engineResult == 'complete';
      if (engineGreen) break;
      // Only a resumable stop (exit 1, result=stopped) re-runs; a
      // runner-error/corrupt/concurrent stop is honest and terminal.
      if (engineResult != 'stopped' || runRes.exitCode != 1) break;
      if (i < engineAttempts) {
        emit('[dream] engine stopped — resuming (attempt ${i + 1})');
      }
    }
    emit(
      '[dream] engine ${engineGreen ? 'green' : 'stopped'} '
      '(result=$engineResult)',
    );

    // ---------------------------------------------------------------
    // 5. The skin cycle: the widget lane via zfa tdd view.
    // ---------------------------------------------------------------
    var skin = 'skipped';
    var handEdit = false;
    final widgetRows = await _widgetRows(root, featureName);
    if (widgetRows.isEmpty) {
      emit('[dream] skin cycle: no widget lane — skipped (recorded)');
    } else {
      skin = 'green';
      for (final row in widgetRows) {
        final viewRes = await zfa([
          'tdd',
          'view',
          row.id,
          '--feature',
          featureName,
          '--project',
          root,
        ], root);
        final out = '${viewRes.stdout}\n${viewRes.stderr}';
        final m = RegExp(r'view: behavior=\S+ outcome=(\S+)').firstMatch(out);
        final label = m?.group(1) ?? 'runner-error';
        if (label == 'scaffolded') {
          handEdit = true;
          skin = 'hand-edit';
          emit(
            '[dream] skin ${row.id} scaffolded — the handcraft seam: a '
            '`skin/$featureName` branch will be opened for the '
            'human/agent',
          );
        } else if (viewRes.exitCode != 0) {
          skin = 'stopped';
          emit('[dream] skin ${row.id} failed (exit ${viewRes.exitCode})');
        }
      }
    }

    // ---------------------------------------------------------------
    // 6. The two receipts (dream-engine + dream-skin), proof.v1.
    // ---------------------------------------------------------------
    final store = ReceiptStore(projectRoot: root);
    final tddDir = p.join(root, 'specs', featureName, 'tdd');

    final engineReceipt = await store.save(
      GenerationReceipt(
        command: 'dream-engine',
        target: featureName,
        repro: 'zfa dream "$description"',
        at: DateTime.now().toUtc(),
        generatorVersion: 'zfa-dream-1.0.0',
        input: {
          'description': description,
          'drafter': drafter,
          'attempts': attempts,
          'engine_result': engineResult,
          'engine_green': engineGreen,
        },
        files: await _receiptFiles(root, [
          p.join(root, 'specs', featureName, 'spec.md'),
          p.join(root, 'specs', featureName, 'plan.md'),
          p.join(tddDir, 'test-list.md'),
          p.join(tddDir, 'traceability.md'),
          p.join(tddDir, 'cycle-log.md'),
          p.join(tddDir, 'run-state.json'),
        ]),
      ),
    );
    emit('[dream] engine receipt: ${engineReceipt.path}');

    final skinReceipt = await store.save(
      GenerationReceipt(
        command: 'dream-skin',
        target: featureName,
        repro: 'zfa dream "$description"',
        at: DateTime.now().toUtc(),
        generatorVersion: 'zfa-dream-1.0.0',
        input: {
          'description': description,
          'drafter': drafter,
          'skin': skin,
          'hand_edit_pending': handEdit,
          'widget_behaviors': widgetRows.map((r) => r.id).toList(),
        },
        files: await _receiptFiles(root, [
          p.join(tddDir, 'draft-spec.md'),
          p.join(tddDir, 'provenance-ledger.json'),
        ]),
      ),
    );
    emit('[dream] skin receipt: ${skinReceipt.path}');

    // ---------------------------------------------------------------
    // 7. The PR (draft: true until the engine is green).
    // ---------------------------------------------------------------
    var pr = 'none';
    if (!noPr) {
      pr = await _openPr(
        proc: proc,
        root: root,
        feature: featureName,
        description: description,
        engineGreen: engineGreen,
        handEdit: handEdit,
        emit: emit,
      );
    }

    final result = engineGreen ? 'complete' : 'stopped';
    emit(
      _summaryLine(
        featureName,
        result,
        drafter,
        attempts,
        engineGreen ? 'green' : 'stopped',
        skin,
        pr,
      ),
    );
    return (engineGreen && pr != 'failed') ? 0 : 1;
  }

  // -----------------------------------------------------------------
  // Pieces
  // -----------------------------------------------------------------

  /// The feature name: next sequential prefix + the description slug
  /// (the same noun extraction the drafter's entity name uses, so
  /// feature and entity can never disagree).
  static String _deriveFeatureName(String root, String description) {
    final prefix = _nextSpecNumber(root);
    final slug = DreamNouns.featureSlug(description);
    return '$prefix-$slug';
  }

  static String _nextSpecNumber(String root) {
    var max = 0;
    final specs = Directory(p.join(root, 'specs'));
    if (specs.existsSync()) {
      for (final entry in specs.listSync()) {
        if (entry is! Directory) continue;
        final m = RegExp(r'^(\d+)').firstMatch(p.basename(entry.path));
        if (m != null) {
          final n = int.tryParse(m.group(1)!) ?? 0;
          if (n > max) max = n;
        }
      }
    }
    return (max + 1).toString().padLeft(3, '0');
  }

  static Future<_DraftPayload> _draftViaV2Tool({
    required String root,
    required String feature,
    required String description,
    required String? feedback,
    required LlmClient? llmClient,
  }) async {
    final result = await handleV2ToolCall(
      toolName: 'dream_draft_spec',
      args: {
        'feature': feature,
        'description': description,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      },
      projectRoot: root,
      llmClient: llmClient,
    );
    final text =
        ((result?['content'] as List?)?.first as Map?)?['text'] as String? ??
        '';
    final data = jsonDecode(text) as Map<String, dynamic>;
    return _DraftPayload(
      data['specMarkdown'] as String? ?? '',
      data['planMarkdown'] as String? ?? '',
      data['drafter'] as String? ?? 'deterministic',
    );
  }

  static Future<List<BehaviorRow>> _widgetRows(
    String root,
    String feature,
  ) async {
    try {
      final rows = await TestListReader(p.join(root, 'specs', feature)).read();
      return rows.where((r) => r.kind == BehaviorKind.widget).toList();
    } catch (_) {
      // An unreadable/absent test list means no widget lane — recorded
      // honestly as skin=skipped, never a crash.
      return const <BehaviorRow>[];
    }
  }

  static Future<List<GenerationReceiptFile>> _receiptFiles(
    String root,
    List<String> absPaths,
  ) async {
    final files = <GenerationReceiptFile>[];
    for (final abs in absPaths) {
      final f = File(abs);
      if (!await f.exists()) continue;
      final bytes = await f.readAsBytes();
      final snapshot = bytes.length <= ReceiptStore.maxSnapshotBytes
          ? utf8.decode(bytes)
          : null;
      files.add(
        GenerationReceiptFile(
          path: p.relative(abs, from: root).replaceAll('\\', '/'),
          action: 'create',
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          snapshot: snapshot,
        ),
      );
    }
    return files;
  }

  /// Commits the feature artifacts and opens the PR. Returns the PR
  /// token: a URL, `draft`, or `failed` (`none` is the caller's
  /// `--no-pr` case).
  static Future<String> _openPr({
    required DreamProcSpawner proc,
    required String root,
    required String feature,
    required String description,
    required bool engineGreen,
    required bool handEdit,
    required void Function(String line) emit,
  }) async {
    Future<bool> run(List<String> argv) async {
      final res = await proc(argv, root);
      if (res.exitCode != 0) {
        emit(
          '[dream] `${argv.take(2).join(' ')}` failed (exit '
                  '${res.exitCode}): ${res.stderr}'
              .trim(),
        );
        return false;
      }
      return true;
    }

    // Which branch are we on? Create the feature branch when dream
    // started from a default branch (AGENTS.md: branch = feature dir).
    final headRes = await proc([
      'git',
      'rev-parse',
      '--abbrev-ref',
      'HEAD',
    ], root);
    var branch = (headRes.stdout as String).trim();
    if (headRes.exitCode != 0 || branch.isEmpty) {
      emit('[dream] git failed: no branch context — PR phase failed');
      return 'failed';
    }
    const defaultBranches = {'master', 'main', 'trunk'};
    if (defaultBranches.contains(branch)) {
      if (!await run(['git', 'checkout', '-b', feature])) return 'failed';
      branch = feature;
    }

    if (!await run(['git', 'add', 'specs/$feature', '.zfa/receipts'])) {
      return 'failed';
    }
    if (!await run([
      'git',
      'commit',
      '-m',
      'spec($feature): zfa dream — $description',
    ])) {
      return 'failed';
    }
    if (!await run(['git', 'push', '-u', 'origin', branch])) {
      return 'failed';
    }

    final title = 'spec($feature): zfa dream — $description';
    final body =
        'Dreamed by `zfa dream "$description"` (drafter: see '
        'receipts).\n\n'
        'Artifacts: specs/$feature/spec.md, plan.md, '
        'tdd/test-list.md, tdd/traceability.md, tdd/draft-spec.md, '
        'tdd/cycle-log.md (when the engine produced one), and the two '
        'dream receipts under .zfa/receipts/.\n\n'
        'Engine: ${engineGreen ? 'green' : 'NOT green (draft PR)'}; skin: '
        '${handEdit ? 'hand-edit pending on `skin/$feature`' : 'no pending hand-edit'}.\n';
    final prRes = await proc([
      'gh',
      'pr',
      'create',
      '--title',
      title,
      '--body',
      body,
      '--head',
      branch,
      if (!engineGreen) '--draft',
    ], root);
    if (prRes.exitCode != 0) {
      emit(
        '[dream] gh pr create failed (exit ${prRes.exitCode}): '
                '${prRes.stderr}'
            .trim(),
      );
      return 'failed';
    }
    final url = RegExp(
      r'https?://\S+',
    ).firstMatch(prRes.stdout as String)?.group(0);

    // The skin hand-edit branch, for the human/agent (everything is
    // committed already — the branch is a clean starting point).
    if (handEdit) {
      final skinRes = await proc([
        'git',
        'checkout',
        '-b',
        'skin/$feature',
      ], root);
      if (skinRes.exitCode != 0) {
        emit(
          '[dream] could not open the skin hand-edit branch '
                  '(exit ${skinRes.exitCode}): ${skinRes.stderr}'
              .trim(),
        );
      } else {
        emit('[dream] skin hand-edit branch opened: skin/$feature');
      }
    }

    if (!engineGreen) {
      emit('[dream] PR opened as DRAFT (engine not green)');
      return 'draft';
    }
    return url ?? 'failed';
  }

  static String _summaryLine(
    String feature,
    String result,
    String drafter,
    int attempts,
    String engine,
    String skin,
    String pr,
  ) =>
      'dream: feature=$feature result=$result drafter=$drafter '
      'attempts=$attempts engine=$engine skin=$skin pr=$pr';

  // -----------------------------------------------------------------
  // Default spawners (the real sub-process path)
  // -----------------------------------------------------------------

  static DreamZfaSpawner _defaultZfaSpawner(String? zfaBin) {
    return (List<String> tail, String cwd) async {
      final entry = zfaBin ?? await StepRunner.defaultZfaBin();
      final argv = <String>[
        if (entry.endsWith('.dart')) Platform.resolvedExecutable,
        entry,
        ...tail,
      ];
      return _timedProcessRun(argv, cwd, const Duration(minutes: 30));
    };
  }

  static DreamProcSpawner get _defaultProcSpawner =>
      (List<String> argv, String cwd) =>
          _timedProcessRun(argv, cwd, const Duration(minutes: 5));

  /// Process.run with a deadline (the bug #742 rule: a hanging child is
  /// killed and mapped to a non-zero result instead of hanging the
  /// orchestrator forever).
  static Future<ProcessResult> _timedProcessRun(
    List<String> argv,
    String cwd,
    Duration timeout,
  ) async {
    final proc = await Process.start(
      argv.first,
      argv.skip(1).toList(),
      workingDirectory: cwd,
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    proc.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
    proc.stderr.transform(utf8.decoder).listen(stderrBuffer.write);
    final code = await proc.exitCode.timeout(
      timeout,
      onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    return ProcessResult(
      proc.pid,
      code,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }
}
