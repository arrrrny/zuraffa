// Bug #859 regression tests — `--plain-name` is a LITERAL substring matcher
// and must never receive regex-escaped names.
//
// `_escapeRegExp` in SingleTestRunner._tokenize escapes regex metacharacters
// (`. -> \.`) in the behavior name before substitution. `dart test
// --plain-name` does NOT interpret backslash escapes — `DispatchResult\.success`
// matches nothing ("No tests match", exit 79, classified `runner-error`) — so
// every behavior whose name contains a dot blocks. The escaping is correct
// ONLY for the regex-flavored filters (`-n` / `--name`, bug #760) and MUST
// stay there: the hard constraint from the #859 assessment is that
// `_escapeRegExp` remains for the `-n`/`--name` path and is skipped for
// `--plain-name`.
//
// The bug IS `dart test`'s matcher semantics — it cannot be pinned with a
// fake — so these run a real `dart test` child inside a TddFixture, but only
// tiny single-file spawns with a warm pub cache (fast tier, no build_runner).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  // The exact shape named in issue #859: a behavior id whose name carries a
  // dot (U13-U20 in spec 004 all hit this).
  const dottedName = 'DispatchResult.success returns the payload';

  // Exercises parens around a word AND around an FR id (the #760 shapes) so
  // the regex path is graded on the metacharacters that actually break it.
  const parenthesizedName = 'maps (FR-005) to the request scope (sticky)';

  setUp(() async {
    fx = await TddFixture.create();
    await fx.registerBehavior(
      id: 'B-859',
      description: dottedName,
      testContent: TddFixture.greenTest(dottedName),
    );
    await fx.registerBehavior(
      id: 'B-760',
      description: parenthesizedName,
      testContent: TddFixture.greenTest(parenthesizedName),
    );
  });

  tearDown(() {
    fx.dispose();
  });

  group('bug 859 — the --plain-name path stays literal', () {
    test(
      'passes the RAW dotted name to --plain-name so it matches (exit 0)',
      () async {
        final record = await const SingleTestRunner().runSingle(
          singleTemplate: TddFixture.defaultSingleTemplate,
          testPath: fx.testPathOf('B-859'),
          testName: dottedName,
          workingDirectory: fx.root.path,
        );
        // The escaped form would report "No tests match" (exit 79,
        // runner-error). The raw form must find and run the target test.
        expect(record.command, contains('DispatchResult.success returns'));
        expect(record.command, isNot(contains(r'DispatchResult\.success')));
        expect(record.exitCode, 0);
        expect(record.testCount, 1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'an escaped dotted name matches NOTHING under --plain-name (exit 79) — '
      'the mechanism the runner must never produce',
      () async {
        // Pins dart test's literal-substring semantics directly: if dart
        // ever starts interpreting escapes in --plain-name, the carve-out's
        // premise (and this test) demands a re-triage.
        final result = await Process.run('dart', [
          'test',
          fx.testPathOf('B-859'),
          '--plain-name',
          r'DispatchResult\.success',
        ], workingDirectory: fx.root.path);
        expect(result.stdout, contains('No tests ran.'));
        expect(result.exitCode, 79);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('bug 859 — the regex path (-n/--name) keeps _escapeRegExp', () {
    test(
      'escapes the name for a regex filter (-n) so (parens) still match',
      () async {
        final record = await const SingleTestRunner().runSingle(
          singleTemplate: 'dart test {file} -n "{name}"',
          testPath: fx.testPathOf('B-760'),
          testName: parenthesizedName,
          workingDirectory: fx.root.path,
        );
        // Raw parens would be parsed as regex groups ("No tests match
        // regular expression", exit 79). The escaped name matches literally.
        expect(record.exitCode, 0);
        expect(record.testCount, 1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'escapes the name for a regex filter (--name) so (parens) still match',
      () async {
        final record = await const SingleTestRunner().runSingle(
          singleTemplate: 'dart test {file} --name "{name}"',
          testPath: fx.testPathOf('B-760'),
          testName: parenthesizedName,
          workingDirectory: fx.root.path,
        );
        expect(record.exitCode, 0);
        expect(record.testCount, 1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
