// Bug #1471: `zfa tdd run <ref>` (and run-engine / run-skin / doctor /
// verify) hardcoded `<root>/specs/<feature>` and refused any reference
// containing `/`, so the bug extension's TDD mode — which pins
// `.specify/feature.json` -> `feature_directory: .specify/bugs/<slug>` —
// could PLAN a bug (`tdd plan`, issue #1182) but never RUN one: the
// documented bug loop (`bug.fix` -> tdd.plan -> tdd.run -> tdd.verify)
// stopped at the run step with exit 2 (the usage protocol's canonical
// code).
//
// The fix routes the family through the single `TddFeaturePaths`
// resolver and carries the resolved triple explicitly:
//
//   * the NAME (`<slug>`) namespaces artifacts, receipts and labels —
//     `test/tdd/<slug>/...`;
//   * the DIRECTORY is every path — `.specify/bugs/<slug>/tdd/...`;
//   * the canonical REF is what a parent run hands its spawned
//     gen/verify-red/make/refactor children, so the whole loop agrees on
//     one directory instead of a parent in `.specify/bugs/<slug>` and a
//     child in a fabricated `specs/<slug>`.
//
// The plain-name contract is unchanged by construction: for a
// separator-free reference the resolver returns EXACTLY the legacy
// `specs/<name>` path, which is why the pre-existing suites stay green.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/feature_path_resolver.dart';

void main() {
  late Directory tmpDir;
  const slug = '1471-bug-dir-slug';
  const plain = '1190-plain-feature';

  const specMd =
      '''
# Bug spec — $slug

**Template Version**: zuraffa-1.0

## Acceptance Scenarios

- SC-001: the run resolves the bug directory.
''';

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('tdd_bug_1471_');
    // A real project root: the resolver and the driver both key on it.
    Directory(p.join(tmpDir.path, 'specs')).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Directory seedBugFeature({
    String bugSlug = slug,
    bool emptyTestList = false,
  }) {
    final dir = Directory(p.join(tmpDir.path, '.specify', 'bugs', bugSlug))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'spec.md')).writeAsStringSync(specMd);
    if (emptyTestList) {
      File(p.join(dir.path, 'tdd', 'test-list.md')).createSync(recursive: true);
    }
    return dir;
  }

  void pin(String featureDirectory) {
    File(p.join(tmpDir.path, '.specify', 'feature.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'feature_directory': featureDirectory}));
  }

  List<String> runArgs(String ref) => [
    'tdd',
    'run',
    ref,
    '--project',
    tmpDir.path,
  ];

  String bugPath(String bugSlug) => p.join('.specify', 'bugs', bugSlug);

  /// Seed the bug feature's TDD registry and test list: the artifact set the
  /// sibling commands (`make`, `gen`, `verify-red`) must find when they
  /// resolve `--feature` to the bug directory rather than to a fabricated
  /// `specs/<slug>` (issue #1471). A registry under the bug dir is the
  /// observable proof of where the command looked.
  void seedBugRegistry({String bugSlug = slug}) {
    final dir = seedBugFeature(bugSlug: bugSlug);
    Directory(p.join(dir.path, 'tdd')).createSync(recursive: true);
    File(p.join(dir.path, 'tdd', 'artifacts.json')).writeAsStringSync(
      jsonEncode({
        'feature': bugSlug,
        'records': [
          {
            'behavior_id': 'U1',
            'feature': bugSlug,
            'source_criterion': 'FR-001',
            'test_path': 'test/tdd/$bugSlug/u1_test.dart',
            'subject_path': 'lib/tdd/$bugSlug/u1.dart',
            'runnable_test_name': 'test/tdd/$bugSlug/u1_test.dart::U1::x',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-08-30T00:00:00.000Z',
          },
        ],
      }),
    );
    File(p.join(dir.path, 'tdd', 'test-list.md')).writeAsStringSync('''
# Test List: $bugSlug

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | resolves the bug directory | FR-001 | PENDING |
''');
  }

  /// Write a fake zfa that appends every spawned argv to `<tmp>/argv.log`
  /// and reports a successful cycle (red then green evidence written under
  /// the `--feature` reference it was handed). Returns the argv-log path.
  /// Used to observe the reference `zfa tdd run` hands its spawned
  /// gen/verify-red/make children (issue #1471).
  String writeDriverFakeZfa() {
    final log = p.join(tmpDir.path, 'argv.log');
    final fake = p.join(tmpDir.path, 'fake-zfa');
    File(fake).writeAsStringSync(
      r'''#!/bin/sh
echo "$@" >> "__ARGVLOG__"
STEP="$2"
ID="$3"
FEATURE=""
PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --feature) FEATURE="$2"; shift ;;
    --project) PROJECT="$2"; shift ;;
  esac
  shift
done
CYCLE="$PROJECT/$FEATURE/tdd/cycle-log.md"
case "$STEP" in
  gen) exit 0 ;;
  verify-red)
    mkdir -p "$(dirname "$CYCLE")"
    printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-001\n- exit: 1\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"; exit 0 ;;
  make)
    printf '\n## Cycle: %s (green)\n\n- behavior: %s\n- kind: green\n- criterion: FR-001\n- exit: 0\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "make: behavior=$ID outcome=green feature=$FEATURE"; exit 0 ;;
  refactor)
    echo "refactor: behavior=$ID outcome=clean feature=$FEATURE"; exit 0 ;;
  *) exit 0 ;;
esac
'''
          .replaceAll('__ARGVLOG__', log),
    );
    Process.runSync('chmod', ['+x', fake]);
    return log;
  }

  group('Bug #1471 — TddFeaturePaths.', () {
    final root = '/repo';

    ResolvedFeatureDir resolve(String ref) =>
        TddFeaturePaths.resolve(projectRoot: root, featureRef: ref);

    test('a bug-directory reference resolves there and keeps the slug', () {
      final r = resolve('.specify/bugs/$slug');
      expect(r.dir, p.join(root, '.specify', 'bugs', slug));
      expect(r.name, slug, reason: 'the NAME namespaces artifacts');
      expect(r.ref, '.specify/bugs/$slug', reason: 'the REF is canonical');
    });

    test('the canonical ref round-trips to the same dir and name', () {
      for (final ref in [slug, 'specs/$slug', '.specify/bugs/$slug']) {
        final first = resolve(ref);
        final again = resolve(first.ref);
        expect(again.dir, first.dir, reason: 'ref "$ref" must be idempotent');
        expect(again.name, first.name);
        expect(again.ref, first.ref);
      }
    });

    test('a plain name keeps the legacy specs/ location (no regression)', () {
      final r = resolve(plain);
      expect(r.dir, p.join(root, 'specs', plain));
      expect(r.name, plain);
      expect(r.ref, plain);
    });

    test('isSupportedRef accepts the four documented shapes', () {
      for (final ref in [
        plain,
        'specs/$plain',
        '.specify/bugs/$slug',
        p.join(root, 'specs', plain),
      ]) {
        expect(
          TddFeaturePaths.isSupportedRef(ref),
          isTrue,
          reason: '$ref is a documented shape',
        );
      }
    });

    test('isSupportedRef still refuses traversal and empty shapes', () {
      for (final ref in [
        '',
        '.',
        '..',
        'specs/../foo',
        'specs/',
        '.specify/bugs/',
        'a/b',
      ]) {
        expect(
          TddFeaturePaths.isSupportedRef(ref),
          isFalse,
          reason: '$ref must stay refused',
        );
      }
    });
  });

  group('Bug #1471 — the .specify/feature.json pin', () {
    test('pinned() is null when no pin file exists', () {
      expect(TddFeaturePaths.pinned(projectRoot: tmpDir.path), isNull);
    });

    test('pinned() resolves feature_directory through the resolver', () {
      seedBugFeature();
      pin('.specify/bugs/$slug');
      final pinned = TddFeaturePaths.pinned(projectRoot: tmpDir.path);
      expect(pinned, isNotNull);
      expect(pinned!.dir, p.join(tmpDir.path, '.specify', 'bugs', slug));
      expect(pinned.name, slug);
    });

    test('a malformed pin degrades to a miss, never a redirect', () {
      File(p.join(tmpDir.path, '.specify', 'feature.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('{"feature_directory": ');
      expect(TddFeaturePaths.pinned(projectRoot: tmpDir.path), isNull);
    });

    test('a bare slug resolves to the pinned bug directory', () {
      seedBugFeature();
      pin('.specify/bugs/$slug');
      final r = TddFeaturePaths.resolveWithPin(
        projectRoot: tmpDir.path,
        featureRef: slug,
      );
      expect(r.dir, p.join(tmpDir.path, '.specify', 'bugs', slug));
      expect(r.name, slug);
    });

    test('an existing specs/<slug> wins over the pin (no regression)', () {
      Directory(p.join(tmpDir.path, 'specs', slug)).createSync(recursive: true);
      pin('.specify/bugs/$slug');
      final r = TddFeaturePaths.resolveWithPin(
        projectRoot: tmpDir.path,
        featureRef: slug,
      );
      expect(r.dir, p.join(tmpDir.path, 'specs', slug));
    });

    test('a pin naming a DIFFERENT feature never hijacks the slug', () {
      pin('.specify/bugs/999-some-other-bug');
      final r = TddFeaturePaths.resolveWithPin(
        projectRoot: tmpDir.path,
        featureRef: slug,
      );
      expect(
        r.dir,
        p.join(tmpDir.path, 'specs', slug),
        reason: 'only an exact basename match may consult the pin',
      );
    });

    test('an explicit path beats the pin (explicit > ambient)', () {
      Directory(
        p.join(tmpDir.path, 'specs', '999-other'),
      ).createSync(recursive: true);
      pin('.specify/bugs/$slug');
      final r = TddFeaturePaths.resolveWithPin(
        projectRoot: tmpDir.path,
        featureRef: '.specify/bugs/$slug',
      );
      expect(r.dir, p.join(tmpDir.path, '.specify', 'bugs', slug));
    });
  });

  group('Bug #1471 — zfa tdd run resolves the bug directory', () {
    test(
      'an explicit bug-directory reference is no longer a usage error',
      () async {
        seedBugFeature();

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(runArgs('.specify/bugs/$slug'));

        expect(
          out,
          isNot(contains('invalid feature')),
          reason:
              'the bug-directory shape is supported — this was the reported '
              'exit-2 grammar refusal',
        );
        expect(
          out,
          contains(p.join(bugPath(slug), 'tdd', 'test-list.md')),
          reason: 'the run looked for the test list in the bug directory',
        );
        expect(
          out,
          isNot(contains(p.join('specs', slug))),
          reason: 'no fabricated specs/<slug> path may ever be consulted',
        );
      },
    );

    test('a bare slug honors the feature.json pin', () async {
      seedBugFeature();
      pin('.specify/bugs/$slug');

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(runArgs(slug));

      expect(
        out,
        contains(p.join(bugPath(slug), 'tdd', 'test-list.md')),
        reason: 'the pin redirected the bare slug to the bug directory',
      );
      expect(out, isNot(contains(p.join('specs', slug))));
    });

    test(
      'a feature whose test list is present is read from the bug dir',
      () async {
        seedBugFeature(emptyTestList: true);

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(runArgs('.specify/bugs/$slug'));

        expect(
          out,
          contains(p.join(bugPath(slug), 'tdd', 'test-list.md')),
          reason: 'the lane resolution reported the bug directory\'s list',
        );
        expect(out, isNot(contains(p.join('specs', slug))));
      },
    );

    test('a plain feature name still resolves specs/<name>', () async {
      Directory(
        p.join(tmpDir.path, 'specs', plain),
      ).createSync(recursive: true);
      File(
        p.join(tmpDir.path, 'specs', plain, 'spec.md'),
      ).writeAsStringSync(specMd);

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(runArgs(plain));

      expect(
        out,
        contains(p.join('specs', plain, 'tdd', 'test-list.md')),
        reason: 'the legacy location is unchanged',
      );
    });
  });

  group('Bug #1471 — the same resolution in doctor and verify', () {
    test('doctor names the bug directory it actually used', () async {
      seedBugFeature();

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'doctor',
        '.specify/bugs/$slug',
        '--project',
        tmpDir.path,
      ]);

      expect(out, contains(bugPath(slug)));
      expect(
        out,
        isNot(contains('specs/$slug')),
        reason: 'the banner must name the directory the command used',
      );
    });

    test('verify accepts the bug-directory shape in --feature', () async {
      File(
        p.join(tmpDir.path, '.specify', 'bugs', slug),
      ).createSync(recursive: true);

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'verify',
        '--feature',
        '.specify/bugs/$slug',
        '--project',
        tmpDir.path,
      ]);

      expect(
        out,
        isNot(contains('invalid --feature')),
        reason: 'the shape is supported (was a usage refusal)',
      );
      expect(
        out,
        contains(bugPath(slug)),
        reason: 'the audit looked in the bug directory',
      );
    });
  });

  group('Bug #1471 — the driver hands children the canonical bug ref', () {
    List<String> stepArgv(String logPath) => File(logPath)
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.startsWith('tdd '))
        .toList();

    test(
      'an explicit bug-directory reference travels to every spawned step',
      () async {
        seedBugRegistry();
        final argvLog = writeDriverFakeZfa();

        await CliRunner(exitOnCompletion: false).runCapturing([
          'tdd',
          'run',
          '.specify/bugs/$slug',
          '--project',
          tmpDir.path,
          '--zfa-bin',
          p.join(tmpDir.path, 'fake-zfa'),
        ]);

        final argv = stepArgv(argvLog);
        expect(
          argv,
          isNotEmpty,
          reason: 'the run must spawn at least one step',
        );
        for (final line in argv) {
          expect(
            line,
            contains('--feature .specify/bugs/$slug'),
            reason:
                'a parent run in the bug directory must hand its children the '
                'canonical bug reference, never the bare slug',
          );
        }
      },
    );

    test('a pinned bare slug is handed down as the bug reference', () async {
      seedBugRegistry();
      pin('.specify/bugs/$slug');
      final argvLog = writeDriverFakeZfa();

      await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'run',
        slug,
        '--project',
        tmpDir.path,
        '--zfa-bin',
        p.join(tmpDir.path, 'fake-zfa'),
      ]);

      final argv = stepArgv(argvLog);
      expect(argv, isNotEmpty);
      for (final line in argv) {
        expect(
          line,
          contains('--feature .specify/bugs/$slug'),
          reason: 'the pin resolved the bare slug to the bug directory',
        );
      }
    });
  });

  group('Bug #1471 — sibling commands resolve the bug directory', () {
    Future<String> runTdd(List<String> args) => CliRunner(
      exitOnCompletion: false,
    ).runCapturing([...args, '--project', tmpDir.path]);

    test('make reads the bug-directory registry (explicit ref)', () async {
      seedBugRegistry();
      final out = await runTdd([
        'tdd',
        'make',
        'U1',
        '--feature',
        '.specify/bugs/$slug',
      ]);
      expect(
        out,
        isNot(contains('unknown behavior id')),
        reason: 'the registry under the bug directory was read',
      );
      expect(out, isNot(contains(p.join('specs', slug))));
    });

    test('make honors the pin for a bare slug', () async {
      seedBugRegistry();
      pin('.specify/bugs/$slug');
      final out = await runTdd(['tdd', 'make', 'U1', '--feature', slug]);
      expect(
        out,
        isNot(contains('unknown behavior id')),
        reason: 'resolveWithPin redirected the bare slug to the bug directory',
      );
      expect(out, isNot(contains(p.join('specs', slug))));
    });

    test(
      'verify-red reads the bug-directory registry (explicit ref)',
      () async {
        seedBugRegistry();
        final out = await runTdd([
          'tdd',
          'verify-red',
          'U1',
          '--feature',
          '.specify/bugs/$slug',
        ]);
        expect(out, isNot(contains('unknown behavior id')));
        expect(out, contains('feature: $slug'));
        expect(out, isNot(contains(p.join('specs', slug))));
      },
    );

    test('verify-red honors the pin for a bare slug', () async {
      seedBugRegistry();
      pin('.specify/bugs/$slug');
      final out = await runTdd(['tdd', 'verify-red', 'U1', '--feature', slug]);
      expect(out, isNot(contains('unknown behavior id')));
      expect(out, isNot(contains(p.join('specs', slug))));
    });

    test('gen reads the bug-directory registry (explicit ref)', () async {
      seedBugRegistry();
      final out = await runTdd([
        'tdd',
        'gen',
        'U1',
        '--feature',
        '.specify/bugs/$slug',
      ]);
      expect(out, isNot(contains('unknown behavior id')));
      expect(out, isNot(contains(p.join('specs', slug))));
    });

    test('refactor appends its evidence beside the bug spec', () async {
      // A bug feature on a green baseline: the profile's suite is a no-op,
      // the build pass is the fake zfa, and `lib/` is unformatted so one
      // pass applies — which makes refactor name its cycle-log destination
      // (the resolved path this test asserts).
      Directory(p.join(tmpDir.path, 'lib')).createSync(recursive: true);
      File(
        p.join(tmpDir.path, 'lib', 'baseline.dart'),
      ).writeAsStringSync('int   answer ( ) {  return 42 ; }\n\n\n');
      Directory(p.join(tmpDir.path, 'test')).createSync(recursive: true);
      File(p.join(tmpDir.path, 'test', 'baseline_test.dart')).writeAsStringSync(
        "import 'package:test/test.dart';\n"
        "void main() { test('green', () { expect(1, equals(1)); }); }\n",
      );
      File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: bug_1471_refactor\nenvironment:\n  sdk: ^3.11.0\n',
      );
      final memory = Directory(p.join(tmpDir.path, '.specify', 'memory'))
        ..createSync(recursive: true);
      File(p.join(memory.path, 'tdd-profile.md')).writeAsStringSync('''
# TDD Profile — bug #1471 refactor

## Commands

- Single test: `true`
- Full suite: `true`

## Keys (machine-readable)

```yaml
runner: dart
single: 'true'
suite: 'true'
file: 'true'
coverage: 'dart test --coverage'
```
''');
      final fake = p.join(tmpDir.path, 'fake-zfa');
      File(fake).writeAsStringSync('#!/bin/sh\nexit 0\n');
      Process.runSync('chmod', ['+x', fake]);
      seedBugRegistry();
      pin('.specify/bugs/$slug');

      final out = await runTdd([
        'tdd',
        'refactor',
        '--feature',
        slug,
        '--zfa-bin',
        fake,
      ]);

      expect(
        out,
        contains('${bugPath(slug)}/tdd/cycle-log.md'),
        reason: 'the refactor receipt lands beside the real bug spec',
      );
      expect(out, isNot(contains(p.join('specs', slug))));
    });
  });
}
