// Bug #805 — generator differential testing (vision slice v0).
//
// The differential corpus is a directory of regression entries shipped
// in the generator repo (`corpus/<tier>/<entry>/entry.json` + a
// `project/` driven-app scaffold). These tests pin the discovery and
// parsing contract: every directory carrying an entry.json in any tier
// is an entry, ordered deterministically, with the four distinct
// failure classes (missing dir, no entries, corrupt JSON, invalid
// entry) surfaced as exceptions — never silently swallowed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/differential_corpus.dart';

void main() {
  late Directory root;

  Future<Directory> writeEntry(
    String tier,
    String name, {
    Map<String, Object?>? entry,
    bool withProject = true,
  }) async {
    final dir = Directory(p.join(root.path, tier, name));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'entry.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        entry ??
            {
              'name': name,
              'incident': 744,
              'description': 'desc for $name',
              'steps': [
                {
                  'argv': ['tdd', 'gen', 'U1', '--feature', 'u2-flow'],
                },
              ],
              'artifactRoots': ['test/tdd', 'lib/tdd'],
            },
      ),
    );
    if (withProject) {
      await Directory(p.join(dir.path, 'project')).create(recursive: true);
      await File(
        p.join(dir.path, 'project', 'pubspec.yaml'),
      ).writeAsString('name: $name\n');
    }
    return dir;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('diff_corpus_');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'discovers entries across tiers in deterministic sorted order',
    () async {
      await writeEntry('regression', 'u2-flow');
      await writeEntry('regression', 'make-baseline-cache');
      await writeEntry('smoke', 'gen-dart-only');

      final entries = await DifferentialCorpus.load(root.path);
      expect(entries.map((e) => e.name).toList(), [
        'gen-dart-only',
        'make-baseline-cache',
        'u2-flow',
      ]);
    },
  );

  test(
    'parses name, incident, description, steps, roots, and project path',
    () async {
      final dir = await writeEntry('regression', 'u2-flow');
      final entries = await DifferentialCorpus.load(root.path);
      expect(entries, hasLength(1));
      final e = entries.single;
      expect(e.name, 'u2-flow');
      expect(e.incident, 744);
      expect(e.description, 'desc for u2-flow');
      expect(e.steps, hasLength(1));
      expect(e.steps.single.argv, ['tdd', 'gen', 'U1', '--feature', 'u2-flow']);
      expect(e.steps.single.label, 'gen U1');
      expect(e.artifactRoots, ['test/tdd', 'lib/tdd']);
      expect(e.projectDir, p.join(dir.path, 'project'));
    },
  );

  test('a missing corpus dir is the distinct missing-corpus failure', () async {
    final missing = p.join(root.path, 'does-not-exist');
    expect(
      () => DifferentialCorpus.load(missing),
      throwsA(
        isA<DifferentialCorpusException>().having(
          (e) => e.kind,
          'kind',
          DifferentialCorpusFailure.missing,
        ),
      ),
    );
  });

  test('a corpus dir with zero entries is the empty failure', () async {
    await Directory(p.join(root.path, 'regression')).create(recursive: true);
    expect(
      () => DifferentialCorpus.load(root.path),
      throwsA(
        isA<DifferentialCorpusException>().having(
          (e) => e.kind,
          'kind',
          DifferentialCorpusFailure.empty,
        ),
      ),
    );
  });

  test(
    'corrupt entry JSON is the corrupt failure, named with the path',
    () async {
      final dir = Directory(p.join(root.path, 'regression', 'broken'));
      await dir.create(recursive: true);
      await File(
        p.join(dir.path, 'entry.json'),
      ).writeAsString('{ not json at all');
      expect(
        () => DifferentialCorpus.load(root.path),
        throwsA(
          isA<DifferentialCorpusException>()
              .having((e) => e.kind, 'kind', DifferentialCorpusFailure.corrupt)
              .having(
                (e) => e.message,
                'message',
                contains(p.join('regression', 'broken', 'entry.json')),
              ),
        ),
      );
    },
  );

  test('an entry without steps or without a project dir is invalid', () async {
    await writeEntry(
      'regression',
      'no-steps',
      entry: {
        'name': 'no-steps',
        'description': 'd',
        'steps': <Object>[],
        'artifactRoots': ['test/tdd'],
      },
    );
    await writeEntry('regression', 'no-project', withProject: false);
    expect(
      () => DifferentialCorpus.load(root.path),
      throwsA(
        isA<DifferentialCorpusException>().having(
          (e) => e.kind,
          'kind',
          DifferentialCorpusFailure.invalid,
        ),
      ),
    );
  });

  test('directories without entry.json are ignored, not errors', () async {
    await writeEntry('regression', 'u2-flow');
    await Directory(
      p.join(root.path, 'regression', 'readme-only'),
    ).create(recursive: true);
    await File(
      p.join(root.path, 'regression', 'README.md'),
    ).writeAsString('notes');

    final entries = await DifferentialCorpus.load(root.path);
    expect(entries.map((e) => e.name), ['u2-flow']);
  });
}
