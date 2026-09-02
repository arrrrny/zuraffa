// Bug #760 regression tests — `dart test -n "<name>"` treats the name as a
// regular expression, so a behavior description containing `(...)`, `[...]`,
// dots, etc. either matches nothing ("No tests match regular expression",
// exit 79) or matches an unintended subset. `zfa tdd verify-red` /
// `zfa tdd make` classify that as `runner-error`, blocking any behavior
// whose description carries a parenthetical note (sticky, idempotent,
// FR-XXX, ...).
//
// The contract: `SingleTestRunner.runSingle` must escape regex
// metacharacters in the `{name}` substitution when the profile template
// uses a regex-flavored name filter (`-n` / `--name`), and must keep the
// raw name when the template uses the literal matcher `--plain-name`
// (issue #756) — escaping there would corrupt the match.
//
// Fast tier: runs a real `dart test` child inside a TddFixture (the bug IS
// `dart test`'s regex semantics — it cannot be pinned with a fake), but
// only two tiny single-file spawns with a warm pub cache, no build_runner.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  // Exercises parens around a word AND around an FR id (the two shapes
  // named in issue #760): `(FR-005)` and `(sticky)`.
  const description = 'maps (FR-005) to the request scope (sticky)';

  setUp(() async {
    fx = await TddFixture.create(
      singleTemplate: 'dart test {file} -n "{name}"',
    );
    await fx.registerBehavior(
      id: 'B-760',
      description: description,
      testContent: TddFixture.greenTest(description),
    );
  });

  tearDown(() {
    fx.dispose();
  });

  group('bug 760 — regex metacharacters in the substituted test name', () {
    test(
      'escapes the name for a regex filter (-n) so (parens) still match',
      () async {
        final runner = const SingleTestRunner();
        final record = await runner.runSingle(
          singleTemplate: 'dart test {file} -n "{name}"',
          testPath: fx.testPathOf('B-760'),
          // verify-red passes the runnable name's last `::` segment: the
          // raw description, parens and all.
          testName: description,
          workingDirectory: fx.root.path,
        );
        // The target test ran and passed — NOT "No tests match regular
        // expression" (exit 79) and NOT an unintended-subset match.
        expect(record.exitCode, 0);
        expect(record.testCount, 1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'keeps the raw name for the literal filter (--plain-name, issue #756)',
      () async {
        final runner = const SingleTestRunner();
        final record = await runner.runSingle(
          singleTemplate: 'dart test {file} --plain-name "{name}"',
          testPath: fx.testPathOf('B-760'),
          testName: description,
          workingDirectory: fx.root.path,
        );
        // A literal matcher must receive the un-escaped name: an escaped
        // `\(sticky\)` substring would match nothing.
        expect(record.exitCode, 0);
        expect(record.testCount, 1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
