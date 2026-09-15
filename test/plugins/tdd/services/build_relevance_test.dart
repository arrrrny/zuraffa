// Tests for `BuildRelevance` (issue #1587) — the build-skip gate that
// decides whether the make plan's terminal `zfa build` step has anything
// builder-consumable to do.
//
// The gate is pure decision logic over a content fingerprint: it skips
// the build ONLY when nothing a builder consumes changed — no deletion,
// no build-config change, and every write is an un-annotated `.dart`
// file (the reported calculator case: plain subjects + tests). Anything
// else keeps the build running exactly as before.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/build_relevance.dart';

void main() {
  group('canSkipTerminalBuild (U1 — skip shapes)', () {
    test('empty changed set (before == after) skips', () {
      final fp = {'lib/a.dart': 'h1', 'pubspec.yaml': 'cfg'};
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: fp,
        after: Map.of(fp),
        readContent: (_) => '',
      );
      expect(skip, isTrue);
    });

    test('a new plain un-annotated .dart file skips', () {
      const content = 'int answer() => 42;\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'lib/a.dart': 'h1'},
        after: {'lib/a.dart': 'h1', 'lib/tdd/feature/u1_subject.dart': 'h2'},
        readContent: (path) => path.contains('u1_subject') ? content : '',
      );
      expect(skip, isTrue);
    });

    test('a modified plain un-annotated .dart file skips (the subject '
        'implementation rewrite — the reported #1587 case)', () {
      const content = 'library;\n\nint u2_value() => 42;\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'lib/u2_subject.dart': 'old'},
        after: {'lib/u2_subject.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isTrue);
    });

    test('a modified test file skips', () {
      const content = "import 'package:test/test.dart';\nvoid main() {}\n";
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'test/u3_test.dart': 'old'},
        after: {'test/u3_test.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isTrue);
    });
  });

  group('canSkipTerminalBuild (U2 — run shapes)', () {
    test('an @Zorphy-annotated write never skips', () {
      const content = '@Zorphy\nclass User {}\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'lib/user.dart': 'old'},
        after: {'lib/user.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isFalse);
    });

    test('an @JsonSerializable-annotated write never skips', () {
      const content = '@JsonSerializable\nclass UserDto {}\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {},
        after: {'lib/dto.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isFalse);
    });

    test('an @HiveType-annotated write never skips', () {
      const content = '@HiveType(typeId: 1)\nclass Box {}\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {},
        after: {'lib/box.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isFalse);
    });

    test('an @Route-annotated write never skips', () {
      const content = '@Route(path: "/home")\nclass HomeRoute {}\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {},
        after: {'lib/home_route.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isFalse);
    });

    test('a build config file change never skips', () {
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'pubspec.yaml': 'old', 'lib/a.dart': 'h'},
        after: {'pubspec.yaml': 'new', 'lib/a.dart': 'h'},
        readContent: (_) => '',
      );
      expect(skip, isFalse);
    });

    test('a deleted build-relevant file never skips', () {
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'lib/gone.dart': 'old'},
        after: {},
        readContent: (_) => '',
      );
      expect(skip, isFalse);
    });

    test('a non-dart write inside the fingerprinted roots never skips', () {
      // The fingerprint only ever yields paths under lib/test/bin/tool
      // plus the config files (see the class doc's coverage boundary),
      // so the non-Dart shape that can actually reach the gate is one
      // written inside those roots (issue #1587 review, finding 2).
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'test/fixtures/data.txt': 'old'},
        after: {'test/fixtures/data.txt': 'new'},
        readContent: (_) => 'data',
      );
      expect(skip, isFalse);
    });
  });

  group('fingerprint (FR-001 changed-file set)', () {
    late Directory root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('build_relevance_');
    });
    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test(
      'walks lib/test/bin/tool plus config files with stable POSIX keys',
      () async {
        Directory(p.join(root.path, 'lib', 'tdd')).createSync(recursive: true);
        Directory(p.join(root.path, 'test')).createSync(recursive: true);
        File(
          p.join(root.path, 'lib', 'tdd', 'a.dart'),
        ).writeAsStringSync('int a() => 1;\n');
        File(
          p.join(root.path, 'test', 'a_test.dart'),
        ).writeAsStringSync('void main() {}\n');
        File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');

        final fp = await BuildRelevance.fingerprint(projectRoot: root.path);
        expect(fp.keys, contains('lib/tdd/a.dart'));
        expect(fp.keys, contains('test/a_test.dart'));
        expect(fp.keys, contains('pubspec.yaml'));
      },
    );

    test(
      'detects a plain-dart modification between two fingerprints',
      () async {
        Directory(p.join(root.path, 'lib')).createSync(recursive: true);
        final subject = File(p.join(root.path, 'lib', 's.dart'))
          ..writeAsStringSync('int s() => 0;\n');
        File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');

        final before = await BuildRelevance.fingerprint(projectRoot: root.path);
        subject.writeAsStringSync('int s() => 42;\n');
        final after = await BuildRelevance.fingerprint(projectRoot: root.path);

        expect(before['lib/s.dart'], isNot(equals(after['lib/s.dart'])));
        expect(
          BuildRelevance.canSkipTerminalBuild(
            before: before,
            after: after,
            readContent: (_) => 'int s() => 42;\n',
          ),
          isTrue,
          reason: 'a plain subject rewrite is the reported #1587 skip case',
        );
      },
    );

    test('a non-UTF8 .dart write fails the decision toward RUN, never throws '
        '(issue #1587 review, finding 1)', () async {
      Directory(p.join(root.path, 'lib')).createSync(recursive: true);
      final broken = File(p.join(root.path, 'lib', 'broken.dart'))
        ..writeAsBytesSync([0xFF, 0xFE, 0x00, 0x01]);

      final before = await BuildRelevance.fingerprint(projectRoot: root.path);
      broken.writeAsBytesSync([0xFF, 0xFE, 0x00, 0x02]);
      final after = await BuildRelevance.fingerprint(projectRoot: root.path);

      // `readAsStringSync` on invalid UTF-8 raises FormatException — NOT
      // a FileSystemException — so the gate must fail open on ANY throw
      // instead of letting it escape the make.
      expect(
        await BuildRelevance.shouldSkipTerminalBuild(
          projectRoot: root.path,
          before: before,
        ),
        isFalse,
        reason: 'a decode error must fail the decision toward RUN',
      );
      expect(after['lib/broken.dart'], isNotNull);
    });

    test('a non-dart write inside the walked roots forces a run (issue #1587 '
        'review, finding 2)', () async {
      Directory(p.join(root.path, 'test')).createSync(recursive: true);
      final fixture = File(p.join(root.path, 'test', 'data.txt'))
        ..writeAsStringSync('old\n');
      File(
        p.join(root.path, 'test', 'a_test.dart'),
      ).writeAsStringSync('void main() {}\n');

      final before = await BuildRelevance.fingerprint(projectRoot: root.path);
      fixture.writeAsStringSync('new\n');
      final after = await BuildRelevance.fingerprint(projectRoot: root.path);

      expect(before['test/data.txt'], isNot(equals(after['test/data.txt'])));
      expect(
        BuildRelevance.canSkipTerminalBuild(
          before: before,
          after: after,
          readContent: (_) => 'new\n',
        ),
        isFalse,
        reason: 'a non-Dart write is never skipped',
      );
    });
  });

  // Issue #1624: the REFACTOR's build-pass gate. It has no "before"
  // fingerprint to diff (the refactor did not write the tree), so it
  // decides from build_runner's own state marker —
  // `.dart_tool/build/asset_graph.json`. Only files NOT older than that
  // marker can hold input build_runner has not consumed.
  group('refactorBuildSkipNote (issue #1624)', () {
    late Directory root;
    final marker = p.join('.dart_tool', 'build', 'asset_graph.json');

    setUp(() {
      root = Directory.systemTemp.createTempSync('refactor_build_gate_');
    });
    tearDown(() {
      root.deleteSync(recursive: true);
    });

    /// Write the build_runner marker backdated one hour: any file written
    /// "now" by the test is unambiguously newer than it.
    void writeMarker() {
      final file = File(p.join(root.path, marker))
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      file.setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
    }

    void writeLibFile(String name, String content) {
      Directory(p.join(root.path, 'lib')).createSync(recursive: true);
      File(p.join(root.path, 'lib', name)).writeAsStringSync(content);
    }

    test('a missing marker runs the build — the project has never been '
        'built here', () async {
      writeLibFile('a.dart', 'int a() => 1;\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        isNull,
      );
    });

    test('a newer annotated .dart file runs the build', () async {
      writeMarker();
      writeLibFile('user.dart', '@JsonSerializable\nclass User {}\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        isNull,
      );
    });

    test('a newer plain .dart file skips the build', () async {
      writeMarker();
      writeLibFile('plain.dart', 'int answer() => 42;\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        BuildRelevance.refactorBuildSkippedNote,
      );
    });

    test('a newer non-Dart write runs the build', () async {
      writeMarker();
      Directory(p.join(root.path, 'lib')).createSync(recursive: true);
      File(p.join(root.path, 'lib', 'data.txt')).writeAsStringSync('x\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        isNull,
      );
    });

    test('a newer build-config write runs the build', () async {
      writeMarker();
      File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        isNull,
      );
    });

    test('a tree unchanged since the marker skips the build', () async {
      writeMarker();
      writeLibFile('plain.dart', 'int answer() => 42;\n');
      // Backdate the write behind the marker: nothing is newer.
      File(
        p.join(root.path, 'lib', 'plain.dart'),
      ).setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        BuildRelevance.refactorBuildSkippedNote,
      );
    });
  });

  // Issue #1637: the config tier of the REFACTOR gate learns content
  // hashing. An implicit `pub get` during the preflight suite refreshes
  // pubspec.lock / package_config.json byte-identically AFTER the last
  // real build, so the #1624 mtime-only comparison ("any newer config
  // file → run") forces the ~26-31s build pass on every refactor that
  // follows a suite run. The gate now keeps mtime as the cheap
  // pre-filter and falls back to a content digest for the newer config
  // files, compared against a gate-owned baseline
  // (.dart_tool/zfa/build_config_baseline.json) whose recorded marker
  // mtime must be STRICTLY older than the current marker — validity is
  // a completed build, not the record's existence.
  group('refactorBuildSkipNote (issue #1637 config content hashing)', () {
    late Directory root;
    final marker = p.join('.dart_tool', 'build', 'asset_graph.json');
    final baselineRel = p.join(
      '.dart_tool',
      'zfa',
      'build_config_baseline.json',
    );

    setUp(() {
      root = Directory.systemTemp.createTempSync('config_hash_gate_');
    });
    tearDown(() {
      root.deleteSync(recursive: true);
    });

    File markerFile() => File(p.join(root.path, marker));
    File baselineFile() => File(p.join(root.path, baselineRel));

    Future<String?> gate() =>
        BuildRelevance.refactorBuildSkipNote(projectRoot: root.path);

    /// Marker backdated one hour: any file written "now" by the test is
    /// unambiguously newer than it.
    void writeMarker() {
      markerFile()
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      markerFile().setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
    }

    /// Simulate the marker a COMPLETED build wrote: moved strictly after
    /// the baseline's recorded marker mtime, but still in the past so
    /// files written after the bump stay unambiguously newer.
    void bumpMarker() {
      markerFile().setLastModifiedSync(
        DateTime.now().subtract(const Duration(minutes: 30)),
      );
    }

    void writeConfig(String relPath, String content) {
      File(p.join(root.path, relPath))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    /// Config digests exactly as the PUBLIC fingerprint mechanism derives
    /// them — the currency the gate's baseline must speak (FR-003).
    Future<Map<String, String>> fingerprintConfigDigests() async {
      final fp = await BuildRelevance.fingerprint(projectRoot: root.path);
      return Map.of(fp)..removeWhere(
        (key, _) => !BuildRelevance.buildConfigFiles.contains(key),
      );
    }

    void seedBaseline({
      required int markerMillis,
      required Map<String, String> digests,
      int version = 1,
    }) {
      baselineFile()
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'version': version,
            'markerMtimeMillis': markerMillis,
            'digests': digests,
          }),
        );
    }

    test('a byte-identical config refresh after a completed build skips '
        'the build (the reported #1637 regression)', () async {
      writeMarker();
      writeConfig('pubspec.lock', 'name: calc\nlockfile-version: 3\n');
      writeConfig(
        p.join('.dart_tool', 'package_config.json'),
        '{"configVersion":2,"packages":[]}',
      );

      // First refactor after the fix ships: no baseline exists yet, so
      // the gate fails toward RUN exactly as #1624 did — and records
      // the digests the upcoming build will consume.
      expect(
        await gate(),
        isNull,
        reason: 'no baseline yet — the fail-safe direction is RUN',
      );
      expect(
        baselineFile().existsSync(),
        isTrue,
        reason: 'the run decision records the config baseline',
      );

      // A build completes: the marker moves strictly after the record.
      bumpMarker();

      // The preflight suite's implicit pub get refreshes BOTH configs
      // byte-identically — mtimes move, bytes do not.
      writeConfig('pubspec.lock', 'name: calc\nlockfile-version: 3\n');
      writeConfig(
        p.join('.dart_tool', 'package_config.json'),
        '{"configVersion":2,"packages":[]}',
      );

      // mtime says "maybe changed", the digest says "unchanged": the
      // ~26-31s build pass must be skippable now.
      expect(
        await gate(),
        BuildRelevance.refactorBuildSkippedNote,
        reason:
            'a byte-identical no-op refresh must not force the '
            'build pass (issue #1637)',
      );
    });

    test('a config file whose content actually changed still runs the '
        'build and re-records the baseline', () async {
      writeMarker();
      writeConfig('pubspec.lock', 'lock: v1\n');
      expect(await gate(), isNull, reason: 'first call records the baseline');

      // A build completes…
      bumpMarker();
      // …then a REAL dependency change rewrites the lock (bytes move).
      writeConfig('pubspec.lock', 'lock: v2 — real dependency change\n');

      expect(
        await gate(),
        isNull,
        reason: 'a real config change keeps its fail-closed contract',
      );
      // The re-recorded baseline carries the NEW digest — the digest of
      // the content the build that follows will actually consume — and
      // it is the fingerprint mechanism's digest (FR-003).
      final fp = await BuildRelevance.fingerprint(projectRoot: root.path);
      final baseline =
          jsonDecode(baselineFile().readAsStringSync())
              as Map<dynamic, dynamic>;
      expect(baseline['digests']['pubspec.lock'], fp['pubspec.lock']);
    });

    test('a missing, corrupt, or wrong-version baseline fails toward RUN '
        'and records a fresh baseline', () async {
      // Missing.
      writeMarker();
      writeConfig('dart_test.yaml', 'presets: {}\n');
      expect(await gate(), isNull, reason: 'missing baseline never skips');
      expect(baselineFile().existsSync(), isTrue);

      // Corrupt — garbage bytes must behave like a missing record.
      baselineFile().writeAsStringSync('\u0000\u00ff not json {{{');
      writeConfig(
        'analysis_options.yaml',
        'include: package:lints/recommended.yaml\n',
      );
      expect(
        await gate(),
        isNull,
        reason: 'a corrupt baseline never fabricates a skip',
      );
      final afterCorrupt =
          jsonDecode(baselineFile().readAsStringSync())
              as Map<dynamic, dynamic>;
      expect(
        afterCorrupt['version'],
        1,
        reason: 'the corrupt record is replaced by a fresh baseline',
      );

      // Unknown version — never trusted, EVEN when the record's
      // digests match the current content and its marker mtime is
      // strictly older (i.e. the version gate is the ONLY barrier
      // between the record and a skip — kills mutants that drop the
      // version check and rely on digest mismatch alone).
      writeMarker();
      writeConfig('pubspec.lock', 'lock: v1\n');
      expect(await gate(), isNull); // record a v1 baseline
      bumpMarker(); // a build completes — the record's marker is older
      final trusted =
          jsonDecode(baselineFile().readAsStringSync())
              as Map<dynamic, dynamic>;
      seedBaseline(
        version: 999,
        markerMillis: trusted['markerMtimeMillis'] as int,
        digests: Map<String, String>.from(trusted['digests'] as Map),
      );
      writeConfig('pubspec.lock', 'lock: v1\n'); // byte-identical refresh
      expect(
        await gate(),
        isNull,
        reason: 'an unknown baseline version never fabricates a skip, '
            'not even with fully matching digests',
      );
      final afterVersion =
          jsonDecode(baselineFile().readAsStringSync())
              as Map<dynamic, dynamic>;
      expect(afterVersion['version'], 1);
    });

    test('a baseline whose recorded marker mtime is not strictly older is '
        'untrusted even with matching digests', () async {
      writeMarker();
      writeConfig('pubspec.lock', 'lock: v1\n');
      final digests = await fingerprintConfigDigests();
      // Recorded against the CURRENT marker — no completed build has
      // moved the marker since, so nothing proves the digests were ever
      // consumed by a real build.
      seedBaseline(
        markerMillis: markerFile().statSync().modified.millisecondsSinceEpoch,
        digests: digests,
      );
      expect(
        await gate(),
        isNull,
        reason:
            'validity needs a completed build (marker strictly '
            'newer); equality means the digests were never consumed',
      );
    });

    test('dart_test.yaml refreshed byte-identically skips the build', () async {
      writeMarker();
      writeConfig('dart_test.yaml', 'presets: {}\n');
      expect(await gate(), isNull);
      bumpMarker();
      writeConfig('dart_test.yaml', 'presets: {}\n'); // same bytes, fresh mtime
      expect(
        await gate(),
        BuildRelevance.refactorBuildSkippedNote,
        reason: 'FR-007: the dart_test.yaml tier is content-hashed too',
      );
    });

    test('a real analysis_options.yaml change still runs the build', () async {
      writeMarker();
      writeConfig(
        'analysis_options.yaml',
        'include: package:lints/recommended.yaml\n',
      );
      expect(await gate(), isNull);
      bumpMarker();
      writeConfig(
        'analysis_options.yaml',
        'include: package:lints/recommended.yaml\nanalyzer:\n  errors:\n    todo: ignore\n',
      );
      expect(
        await gate(),
        isNull,
        reason: 'FR-007: a real analysis-options change still forces the pass',
      );
    });

    test('a baseline seeded from BuildRelevance.fingerprint digests is '
        'trusted (mechanism reuse, FR-003)', () async {
      writeMarker();
      writeConfig('pubspec.yaml', 'name: x\n');
      writeConfig('pubspec.lock', 'lock: v1\n');
      final digests = await fingerprintConfigDigests();
      expect(digests['pubspec.lock'], isNotNull);
      // The baseline speaks the fingerprint mechanism's currency, and a
      // build completed after it was recorded.
      seedBaseline(
        markerMillis: markerFile().statSync().modified.millisecondsSinceEpoch,
        digests: digests,
      );
      bumpMarker();
      writeConfig('pubspec.yaml', 'name: x\n'); // byte-identical refresh
      expect(
        await gate(),
        BuildRelevance.refactorBuildSkippedNote,
        reason:
            'fingerprint-derived digests and baseline digests are '
            'the same currency — the fingerprint mechanism is reused',
      );
    });

    test(
      'a baseline with one wrong config digest still runs the build',
      () async {
        writeMarker();
        writeConfig('pubspec.yaml', 'name: x\n');
        writeConfig('pubspec.lock', 'lock: v1\n');
        final digests = await fingerprintConfigDigests();
        digests['pubspec.lock'] = 'deadbeef00000000'; // corrupt ONE entry
        seedBaseline(
          markerMillis: markerFile().statSync().modified.millisecondsSinceEpoch,
          digests: digests,
        );
        bumpMarker();
        writeConfig('pubspec.yaml', 'name: x\n'); // matches baseline
        writeConfig(
          'pubspec.lock',
          'lock: v1\n',
        ); // newer, WRONG baseline digest
        expect(
          await gate(),
          isNull,
          reason: 'the tier clears per file, never wholesale',
        );
      },
    );

    test('a cleared config tier plus a newer plain .dart file still skips '
        '(mixed tree)', () async {
      writeMarker();
      writeConfig('pubspec.lock', 'lock: v1\n');
      Directory(p.join(root.path, 'lib')).createSync(recursive: true);
      expect(await gate(), isNull); // record
      bumpMarker();
      writeConfig('pubspec.lock', 'lock: v1\n'); // byte-identical refresh
      File(
        p.join(root.path, 'lib', 'plain.dart'),
      ).writeAsStringSync('int answer() => 42;\n'); // plain rewrite
      expect(
        await gate(),
        BuildRelevance.refactorBuildSkippedNote,
        reason:
            'cleared configs + un-annotated plain Dart = nothing '
            'builder-facing changed',
      );
    });

    test('the recorded baseline is version-1 JSON with markerMtimeMillis '
        'and full config digests', () async {
      writeMarker();
      writeConfig('pubspec.lock', 'lock: v1\n');
      writeConfig('.zfa.json', '{"version":1}\n');
      expect(await gate(), isNull);

      final baseline =
          jsonDecode(baselineFile().readAsStringSync())
              as Map<dynamic, dynamic>;
      expect(baseline['version'], 1);
      expect(
        baseline['markerMtimeMillis'],
        markerFile().statSync().modified.millisecondsSinceEpoch,
        reason:
            'the recorded marker mtime is the PRE-build marker the '
            'validity rule compares against',
      );
      final digests = baseline['digests'] as Map<dynamic, dynamic>;
      expect(digests.keys, containsAll(['pubspec.lock', '.zfa.json']));
      final fp = await BuildRelevance.fingerprint(projectRoot: root.path);
      expect(digests['pubspec.lock'], fp['pubspec.lock']);
      expect(digests['.zfa.json'], fp['.zfa.json']);
    });

    test('the skip path never rewrites or invalidates the baseline', () async {
      writeMarker();
      writeConfig('pubspec.lock', 'lock: v1\n');
      expect(await gate(), isNull);
      bumpMarker();
      writeConfig('pubspec.lock', 'lock: v1\n');
      expect(await gate(), BuildRelevance.refactorBuildSkippedNote);

      final before = baselineFile().readAsStringSync();
      expect(
        await gate(),
        BuildRelevance.refactorBuildSkippedNote,
        reason: 'a skip decision must not self-invalidate the baseline',
      );
      expect(
        baselineFile().readAsStringSync(),
        before,
        reason: 'FR-006: the skip path never writes the baseline',
      );
    });
  });
}
