// Spec 1529 (US3) — the trimmed re-certification scope and decision.
//
// The scoping service (`RecertScope.compute`) answers: which test files
// could a make step's writes POSSIBLY have affected? The answer is the
// behavior's own test plus every test whose transitive import closure
// (imports, exports, parts; relative and self-package URIs) reaches the
// declared write set. The decision function (`planGuardRecert`) answers:
// may the guard run that trimmed set instead of the full suite? Only
// when the untouched-rest proof holds — a dependency fingerprint and an
// mtime scan proving make wrote nothing outside the declared set — and
// every unmet condition selects the EXISTING full-suite path (fail-
// closed, never a silent pass).
//
// Fast tier: pure filesystem fixtures, no processes.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_baseline_cache.dart';
import 'package:zuraffa/src/plugins/tdd/services/recert_scope.dart';
import 'package:zuraffa/src/plugins/tdd/services/run_baseline_cache.dart';
import 'package:zuraffa/src/plugins/tdd/services/suite_guard.dart';

void main() {
  late Directory root;

  Future<File> write(String relPosix, String content) async {
    final file = File(p.join(root.path, relPosix));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  Future<void> seedTree() async {
    await write('pubspec.yaml', 'name: demo\n');
    // The declared write set: the subject (and the behavior's own test,
    // always in scope by definition).
    await write('lib/subject.dart', 'class Subject {}\n');
    // A barrel that re-exports the subject — indirect importers reach it
    // through the export edge.
    await write('lib/bridge.dart', "export 'subject.dart';\n");
    await write(
      'test/own_test.dart',
      "import 'package:demo/subject.dart';\n"
          "import 'package:test/test.dart';\n"
          'void main() {}\n',
    );
    // A relative-path importer.
    await write(
      'test/importer_test.dart',
      "import '../lib/subject.dart';\n"
          "import 'package:test/test.dart';\n"
          'void main() {}\n',
    );
    // A transitive importer: test → helper (test dir) → export → subject.
    await write('test/helper.dart', "export '../lib/subject.dart';\n");
    await write(
      'test/indirect_test.dart',
      "import 'helper.dart';\n"
          "import 'package:test/test.dart';\n"
          'void main() {}\n',
    );
    // A `part`/`part of` pair reaching the subject.
    await write(
      'test/parted_test.dart',
      "import 'package:demo/subject.dart';\n"
          "part 'parted_part.dart';\n"
          "import 'package:test/test.dart';\n"
          'void main() {}\n',
    );
    await write('test/parted_part.dart', "part of 'parted_test.dart';\n");
    // An unrelated test: imports a file make never wrote.
    await write('lib/other.dart', 'class Other {}\n');
    await write(
      'test/unrelated_test.dart',
      "import 'package:demo/other.dart';\n"
          "import 'package:test/test.dart';\n"
          'void main() {}\n',
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('recert_scope_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  group('U10: RecertScope.compute — the import closure', () {
    test('returns exactly the own test plus every importer, transitively, '
        'across relative, self-package, export, and part edges', () async {
      await seedTree();
      final scope = await RecertScope.compute(
        projectRoot: root.path,
        writtenFiles: {'lib/subject.dart'},
        ownTestPath: 'test/own_test.dart',
      );

      expect(scope.inScope, {
        'test/own_test.dart',
        'test/importer_test.dart',
        'test/indirect_test.dart',
        'test/parted_test.dart',
      }, reason: 'the unrelated test imports only lib/other.dart');
      expect(scope.totalTestFiles, 5);
      expect(scope.coversWholeTree, isFalse);
    });

    test(
      'external package and dart: URIs never leak into the closure',
      () async {
        await seedTree();
        await write(
          'test/external_test.dart',
          "import 'package:other_pkg/thing.dart';\n"
              "import 'dart:io';\n"
              "import 'package:test/test.dart';\n"
              'void main() {}\n',
        );
        final scope = await RecertScope.compute(
          projectRoot: root.path,
          writtenFiles: {'lib/subject.dart'},
          ownTestPath: 'test/own_test.dart',
        );
        expect(scope.inScope, isNot(contains('test/external_test.dart')));
        expect(scope.totalTestFiles, 6);
      },
    );

    test(
      'the own test is in scope even when nothing imports the write set',
      () async {
        await seedTree();
        final scope = await RecertScope.compute(
          projectRoot: root.path,
          writtenFiles: {'lib/nothing_imports_this.dart'},
          ownTestPath: 'test/own_test.dart',
        );
        expect(scope.inScope, {'test/own_test.dart'});
      },
    );

    test(
      'a write set the whole tree reaches yields the full-tree signal',
      () async {
        await seedTree();
        // Every test imports package:test — make the barrel the write set
        // every test reaches by pointing each test at lib/subject.dart via
        // the bridge... simplest full-tree shape: the write set IS the file
        // every test imports (the test package shim is not project-local,
        // so rewrite one file every test imports).
        await write('lib/subject.dart', 'class Subject {}\n');
        await write(
          'test/unrelated_test.dart',
          "import 'package:demo/subject.dart';\n"
              "import 'package:test/test.dart';\n"
              'void main() {}\n',
        );
        final scope = await RecertScope.compute(
          projectRoot: root.path,
          writtenFiles: {'lib/subject.dart'},
          ownTestPath: 'test/own_test.dart',
        );
        expect(scope.coversWholeTree, isTrue);
        expect(scope.inScope.length, scope.totalTestFiles);
      },
    );

    test('absolute or Windows-style inputs are normalized to project-'
        'relative POSIX paths', () async {
      await seedTree();
      final scope = await RecertScope.compute(
        projectRoot: root.path,
        writtenFiles: {p.join(root.path, 'lib', 'subject.dart')},
        ownTestPath: p.join(root.path, 'test', 'own_test.dart'),
      );
      expect(scope.inScope, contains('test/own_test.dart'));
      expect(
        scope.inScope.every((f) => !p.isAbsolute(f)),
        isTrue,
        reason: 'the scoped command appends project-relative paths',
      );
    });
  });

  group('U11: planGuardRecert — the fail-closed decision', () {
    final provenScope = RecertScopeResult(
      inScope: {'test/own_test.dart', 'test/importer_test.dart'},
      totalTestFiles: 5,
    );

    test('the scoped run is selected only under the full proof', () {
      final plan = planGuardRecert(
        fingerprintProven: true,
        writesDeclaredOnly: true,
        scope: provenScope,
        ownTestPath: 'test/own_test.dart',
        suiteTemplate: 'dart test --reporter compact',
      );
      expect(plan.mode, RecertGuardMode.scopedRun);
      expect(
        plan.command,
        'dart test --reporter compact '
        'test/importer_test.dart test/own_test.dart',
        reason:
            'files sorted, appended to the suite template '
            '(the #1374 pattern)',
      );
      expect(plan.reason, isNotEmpty);
    });

    test('a missing fingerprint selects the existing full-suite path', () {
      final plan = planGuardRecert(
        fingerprintProven: false,
        writesDeclaredOnly: true,
        scope: provenScope,
        ownTestPath: 'test/own_test.dart',
        suiteTemplate: 'dart test',
      );
      expect(plan.mode, RecertGuardMode.fullSuite);
    });

    test('a shared write selects the existing full-suite path', () {
      final plan = planGuardRecert(
        fingerprintProven: true,
        writesDeclaredOnly: false,
        scope: provenScope,
        ownTestPath: 'test/own_test.dart',
        suiteTemplate: 'dart test',
      );
      expect(plan.mode, RecertGuardMode.fullSuite);
    });

    test('a scope covering the whole tree selects the full suite '
        '(small/fast suites unchanged)', () {
      final plan = planGuardRecert(
        fingerprintProven: true,
        writesDeclaredOnly: true,
        scope: RecertScopeResult(
          inScope: {'test/own_test.dart', 'test/importer_test.dart'},
          totalTestFiles: 2,
        ),
        ownTestPath: 'test/own_test.dart',
        suiteTemplate: 'dart test',
      );
      expect(plan.mode, RecertGuardMode.fullSuite);
    });

    test('an empty importer set selects the post-run transcript mode '
        '(zero extra spawns)', () {
      final plan = planGuardRecert(
        fingerprintProven: true,
        writesDeclaredOnly: true,
        scope: RecertScopeResult(
          inScope: {'test/own_test.dart'},
          totalTestFiles: 5,
        ),
        ownTestPath: 'test/own_test.dart',
        suiteTemplate: 'dart test',
      );
      expect(plan.mode, RecertGuardMode.postRunTranscript);
    });

    test('a missing suite template cannot build the scoped command — '
        'the full-suite path stands', () {
      final plan = planGuardRecert(
        fingerprintProven: true,
        writesDeclaredOnly: true,
        scope: provenScope,
        ownTestPath: 'test/own_test.dart',
        suiteTemplate: null,
      );
      expect(plan.mode, RecertGuardMode.fullSuite);
    });
  });

  group('U9: the baseline caches persist the capture duration', () {
    test('RunBaselineCache durationMs + fingerprint round-trip; old files '
        'read as null', () async {
      await seedTree();
      final cache = const RunBaselineCache();
      final path = RunBaselineCache.pathFor(featureDir: root.path);
      await cache.write(
        featureDir: root.path,
        snapshot: const _FakeSnapshot(),
        durationMs: 540000,
        fingerprint: 'abc123',
      );
      expect(await cache.readDurationMs(path), 540000);
      expect(await cache.readFingerprint(path), 'abc123');

      // An OLD file (pre-1529) carries neither key — both read null.
      final oldPath = p.join(root.path, 'old.json');
      await File(oldPath).writeAsString(
        '{"command":"dart test","exitCode":0,"failedTests":[],'
        '"capturedAt":"2026-01-01T00:00:00.000Z","parseable":true}',
      );
      expect(await cache.readDurationMs(oldPath), isNull);
      expect(await cache.readFingerprint(oldPath), isNull);

      // A corrupt file reads null (safe failure).
      final badPath = p.join(root.path, 'bad.json');
      await File(badPath).writeAsString('{not json');
      expect(await cache.readDurationMs(badPath), isNull);
      expect(await cache.readFingerprint(badPath), isNull);
    });

    test('CorpusBaselineCache durationMs round-trips and old files read '
        'as null', () async {
      await seedTree();
      final cache = const CorpusBaselineCache();
      await cache.write(
        projectRoot: root.path,
        snapshot: const _FakeSnapshot(),
        fingerprint: 'fprint',
        durationMs: 120000,
      );
      expect(await cache.readDurationMs(projectRoot: root.path), 120000);

      // An old corpus file without the key reads null.
      final file = File(CorpusBaselineCache.pathFor(projectRoot: root.path));
      final json = (await file.readAsString()).replaceAll(
        ',"duration_ms":120000',
        '',
      );
      await file.writeAsString(json);
      expect(await cache.readDurationMs(projectRoot: root.path), isNull);
    });
  });
}

/// Minimal [SuiteSnapshot] stand-in for cache round-trips (the caches
/// copy scalar fields only).
class _FakeSnapshot implements SuiteSnapshot {
  const _FakeSnapshot();

  @override
  String get command => 'dart test';

  @override
  int get exitCode => 0;

  @override
  Set<String> get failedTests => const {};

  @override
  String get capturedAt => '2026-09-13T00:00:00.000Z';

  @override
  bool get parseable => true;
}
