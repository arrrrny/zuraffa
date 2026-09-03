/// ReplayFixture — builds a throwaway Dart project for `zfa replay` tests
/// (spec 066-zfa-replay).
///
/// Carries the file contracts replay reads and re-executes:
///  - a pubspec (+ optional `.dart_tool/package_config.json`), so the
///    FR-011 package-resolution rule is exercisable both ways;
///  - a `specs/<feature>/tdd/` directory whose cycle log is seeded through
///    the REAL `CycleLog.append` writer — the machine format (schema-1
///    chain lines) is byte-exact by construction;
///  - a scripted POSIX sh fake `zfa` binary for recorded gen steps, with a
///    per-step config + invocation log (the tdd_fixture pattern);
///  - shell "check" scripts the recorded green commands run inside the
///    sandbox, asserting a marker in a subject file (the SC4 mutation
///    surface).
///
/// No `dart test` is ever spawned — fixtures are kernel-cache safe.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';

/// A temp project seeded for replay tests.
class ReplayFixture {
  ReplayFixture._(this.root, this.featureName);

  /// Project root (the temp directory itself).
  final Directory root;

  /// Feature directory name under `specs/`.
  final String featureName;

  static Future<ReplayFixture> create({
    String featureName = '066-replay-fixture',
    bool withPackageConfig = true,
  }) async {
    final root = Directory.systemTemp.createTempSync('zfa_replay_fixture_');
    final fx = ReplayFixture._(root, featureName);
    await File(p.join(root.path, 'pubspec.yaml')).writeAsString('''
name: replay_fixture
environment:
  sdk: ^3.11.0
''');
    if (withPackageConfig) {
      final dartTool = Directory(p.join(root.path, '.dart_tool'));
      await dartTool.create(recursive: true);
      await File(p.join(dartTool.path, 'package_config.json')).writeAsString(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'replay_fixture',
              'rootUri': '../..',
              'packageUri': 'lib/',
              'languageVersion': '3.11',
            },
          ],
        }),
      );
    }
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    return fx;
  }

  String get featureDir => p.join(root.path, 'specs', featureName);
  String get cycleLogPath => p.join(featureDir, 'tdd', 'cycle-log.md');

  /// The scripted fake zfa binary + its invocation log path (created on
  /// [writeFakeZfa]).
  String get fakeZfaPath => p.join(root.path, 'fake_bin', 'zfa');
  String get fakeZfaLogPath => p.join(root.path, 'fake_bin', 'log');

  /// Absolute path of a lib subject file for [id].
  String subjectPathOf(String id) =>
      p.join(root.path, 'lib', '${_snake(id)}_subject.dart');

  /// Absolute path of the paired test file for [id].
  String testPathOf(String id) =>
      p.join(root.path, 'test', '${_snake(id)}_test.dart');

  String _snake(String id) => id.toLowerCase().replaceAll('-', '_');

  /// Write a subject file with [marker] inside its body (the check scripts
  /// grep for it).
  Future<void> writeSubject(String id, String marker) async {
    final file = File(subjectPathOf(id));
    await file.parent.create(recursive: true);
    await file.writeAsString('// subject: $id\n// marker: $marker\n');
  }

  /// Write the paired test file (the red entry's recorded test path must
  /// exist in the real tree).
  Future<void> writeTest(String id) async {
    final file = File(testPathOf(id));
    await file.parent.create(recursive: true);
    await file.writeAsString("// test for $id\nvoid main() {}\n");
  }

  /// The check script a recorded green command runs. Exits 0 iff the
  /// subject file for [id] carries [marker].
  Future<void> writeCheckScript(String id, String marker) async {
    final dir = Directory(p.join(root.path, '.specify'));
    await dir.create(recursive: true);
    final scriptPath = p.join(dir.path, 'check_${_snake(id)}.sh');
    await File(scriptPath).writeAsString(
      '#!/bin/sh\n'
      'grep -q "marker: $marker" "\$1" 2>/dev/null && exit 0\n'
      'echo "marker \$2 missing" >&2\n'
      'exit 1\n',
    );
    await Process.run('chmod', ['+x', scriptPath]);
  }

  /// Recorded green command for [id] (relative to the project root — it
  /// must run identically inside the sandbox).
  String greenCommandOf(String id) =>
      'sh .specify/check_${_snake(id)}.sh lib/${_snake(id)}_subject.dart OK';

  /// Recorded gen step command for [id] (bare `zfa` — the replay runner
  /// substitutes `--zfa-bin`).
  String genCommandOf(String id) => 'zfa tdd gen $id --feature $featureName';

  /// Append a full machine-format cycle for [id] through the REAL writer:
  /// red (assertion failure) → green (with [genSteps] recorded), chained.
  Future<void> appendCycle(
    String id, {
    required String marker,
    List<GenerationStep> genSteps = const [],
    String? greenCommand,
  }) async {
    final log = CycleLog(featureDir);
    await writeTest(id);
    await writeSubject(id, marker);
    await writeCheckScript(id, marker);
    await log.append(
      CycleLogEntry(
        behaviorId: id,
        kind: CycleEntryKind.red,
        runnerCommand: 'dart test ${testPathOf(id)}',
        exitCode: 1,
        capturedOutput: 'Expected: marker present',
        classification: FailureClass.assertionFailure,
        sourceCriterion: 'FR-004',
        testPath: testPathOf(id),
        timestamp: '2026-09-03T00:00:00.000Z',
      ),
    );
    await log.append(
      CycleLogEntry(
        behaviorId: id,
        kind: CycleEntryKind.green,
        runnerCommand: greenCommand ?? greenCommandOf(id),
        exitCode: 0,
        capturedOutput: 'All tests passed!',
        sourceCriterion: 'FR-004',
        testPath: testPathOf(id),
        timestamp: '2026-09-03T00:00:01.000Z',
        generationSteps: genSteps,
      ),
    );
  }

  /// Append only-red evidence for [id] (a loop still in progress).
  Future<void> appendRedOnly(String id) async {
    final log = CycleLog(featureDir);
    await writeTest(id);
    await log.append(
      CycleLogEntry(
        behaviorId: id,
        kind: CycleEntryKind.red,
        runnerCommand: 'dart test ${testPathOf(id)}',
        exitCode: 1,
        capturedOutput: 'Expected: marker present',
        classification: FailureClass.assertionFailure,
        sourceCriterion: 'FR-004',
        testPath: testPathOf(id),
        timestamp: '2026-09-03T00:00:02.000Z',
      ),
    );
  }

  /// Write the scripted fake zfa binary. Recorded gen steps resolve `zfa`
  /// to it via `--zfa-bin`; each invocation appends its argv to the log.
  /// With no config the step exits 0 and writes nothing (the recorded tree
  /// reproduces identically). A config file `fake_bin/config/<behaviorId>`
  /// makes the step "regenerate": its first line is `WRITE <relative-path>`
  /// and the remaining lines are the body — written into the step's CWD
  /// (the sandbox), producing regeneration output that differs from the
  /// recorded tree (the SC3 drift surface).
  Future<void> writeFakeZfa() async {
    final binDir = Directory(p.join(root.path, 'fake_bin'));
    await binDir.create(recursive: true);
    await Directory(p.join(binDir.path, 'config')).create();
    await File(fakeZfaLogPath).writeAsString('');
    final cfgDir = p.join(binDir.path, 'config');
    final script =
        r'''#!/bin/sh
# fake zfa for replay tests. argv: tdd gen <id> --feature <f>
echo "$@" >> "@@LOG@@"
ID="$3"
CFG="@@CFG@@/$ID"
if [ -f "$CFG" ]; then
  TARGET=$(head -n 1 "$CFG" | sed "s/^WRITE //")
  tail -n +2 "$CFG" > "$TARGET"
  exit 0
fi
exit 0
'''
            .replaceAll('@@LOG@@', fakeZfaLogPath)
            .replaceAll('@@CFG@@', cfgDir);
    await File(fakeZfaPath).writeAsString(script);
    await Process.run('chmod', ['+x', fakeZfaPath]);
  }

  /// The fake zfa config that makes a gen step DIVERGE: writing
  /// [relativePath] with [body] into its cwd (the sandbox) — the
  /// regeneration output differs from the recorded tree.
  Future<void> writeDriftConfig(
    String behaviorId,
    String relativePath,
    String body,
  ) async {
    final cfg = File(p.join(root.path, 'fake_bin', 'config', behaviorId));
    await cfg.parent.create(recursive: true);
    await cfg.writeAsString('WRITE $relativePath\n$body\n');
  }

  /// The recorded root of a history written on ANOTHER machine (spec
  /// 0806-zfa-replay): a path that intentionally does not exist locally —
  /// every `<recordedRoot>/./…` path in the seeded history is anchored here,
  /// exactly like `examples/todo_tdd`'s real cycle-log.
  String get recordedRoot => p.join(root.path, 'recorded_box');

  /// An anchored test path as the runner template renders it:
  /// `<root>/./<relative>`.
  String anchoredTestPathOf(String id) =>
      '$recordedRoot/./test/${_snake(id)}_test.dart';

  /// An anchored subject path as `artifacts.json` records it.
  String anchoredSubjectPathOf(String id) =>
      '$recordedRoot/./lib/${_snake(id)}_subject.dart';

  /// The machine-absolute entrypoint pair the make pipeline records for gen
  /// steps on the recording box: `<recorded dart> <recorded zfa.dart>`.
  String recordedEntrypointOf(String id) =>
      '/gone/sdk/bin/dart /gone/zuraffa/bin/zfa.dart tdd gen $id '
      '--feature $featureName';

  /// The recorded green command carrying the anchored subject path (the
  /// runner template substituted the absolute test/subject paths).
  String anchoredGreenCommandOf(String id) =>
      'sh .specify/check_${_snake(id)}.sh ${anchoredSubjectPathOf(id)} OK';

  /// The registry (`specs/<feature>/tdd/artifacts.json`) exactly as the
  /// recording machine wrote it: anchored test/subject/runnable paths for
  /// [ids].
  Future<void> writeAnchoredRegistry(List<String> ids) async {
    final records = [
      for (final id in ids)
        {
          'behavior_id': id,
          'feature': featureName,
          'source_criterion': 'AC-1',
          'test_path': anchoredTestPathOf(id),
          'subject_path': anchoredSubjectPathOf(id),
          'runnable_test_name': '${anchoredTestPathOf(id)}::$id::recorded',
          'test_ownership': 'created',
          'subject_ownership': 'created',
          'created_at': '2026-09-02T09:06:43.108460Z',
        },
    ];
    await File(
      p.join(featureDir, 'tdd', 'artifacts.json'),
    ).writeAsString(const JsonEncoder.withIndent(' ').convert(records));
  }

  /// Append a full machine-format cycle for [id] whose recorded facts are
  /// anchored at [recordedRoot] — the todo example's recorded shape: the
  /// red/green `- test:` fields and the green command carry
  /// `<root>/./…` paths, and the generation steps carry the machine-absolute
  /// entrypoint pair.
  Future<void> appendAnchoredCycle(
    String id, {
    required String marker,
    List<GenerationStep> genSteps = const [],
  }) async {
    final log = CycleLog(featureDir);
    await writeTest(id);
    await writeSubject(id, marker);
    await writeCheckScript(id, marker);
    await log.append(
      CycleLogEntry(
        behaviorId: id,
        kind: CycleEntryKind.red,
        runnerCommand: 'dart test ${anchoredTestPathOf(id)} --name "$id"',
        exitCode: 1,
        capturedOutput: 'Expected: marker present',
        classification: FailureClass.assertionFailure,
        sourceCriterion: 'AC-1',
        testPath: anchoredTestPathOf(id),
        timestamp: '2026-09-02T09:07:00.000Z',
      ),
    );
    await log.append(
      CycleLogEntry(
        behaviorId: id,
        kind: CycleEntryKind.green,
        runnerCommand: anchoredGreenCommandOf(id),
        exitCode: 0,
        capturedOutput: 'All tests passed!',
        sourceCriterion: 'AC-1',
        testPath: anchoredTestPathOf(id),
        timestamp: '2026-09-02T09:08:52.000Z',
        generationSteps: genSteps,
      ),
    );
  }

  /// The fake zfa variant that also proves the sandbox contract end-to-end
  /// (spec 0806 FR-005): every invocation asserts the registry under its CWD
  /// is anchored into the sandbox — it exits 7 (a loud, named failure) when
  /// the copied registry still carries the recorded root. Drift-config
  /// behavior is identical to [writeFakeZfa].
  Future<void> writeAnchoredFakeZfa() async {
    final binDir = Directory(p.join(root.path, 'fake_bin'));
    await binDir.create(recursive: true);
    await Directory(p.join(binDir.path, 'config')).create();
    await File(fakeZfaLogPath).writeAsString('');
    final cfgDir = p.join(binDir.path, 'config');
    final script =
        '''
#!/bin/sh
# fake zfa for re-anchored replay tests (spec 0806).
echo "\$@" >> "@@LOG@@"
REG="specs/@@FEATURE@@/tdd/artifacts.json"
if [ -f "\$REG" ] && grep -q "@@ROOT@@" "\$REG"; then
  echo "registry not re-anchored: recorded root leaked into sandbox" >&2
  exit 7
fi
ID="\$3"
CFG="@@CFG@@/\$ID"
if [ -f "\$CFG" ]; then
  TARGET=\$(head -n 1 "\$CFG" | sed "s/^WRITE //")
  tail -n +2 "\$CFG" > "\$TARGET"
  exit 0
fi
exit 0
'''
            .replaceAll('@@LOG@@', fakeZfaLogPath)
            .replaceAll('@@CFG@@', cfgDir)
            .replaceAll('@@FEATURE@@', featureName)
            .replaceAll('@@ROOT@@', recordedRoot);
    await File(fakeZfaPath).writeAsString(script);
    await Process.run('chmod', ['+x', fakeZfaPath]);
  }
}

/// A `GenerationStep` for seeding green entries.
GenerationStep genStep(
  String command, {
  int exit = 0,
  String purpose = 'gen',
}) => GenerationStep(
  command: command,
  exitCode: exit,
  output: '',
  purpose: purpose,
);
