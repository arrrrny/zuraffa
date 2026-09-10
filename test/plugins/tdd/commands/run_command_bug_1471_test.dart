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
}
