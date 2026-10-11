@Tags(['slow'])
// Bug #1402 — `zfa tdd make`'s `--plain-name` lookup silently exits 79
// ("No tests ran") when a hand-edited test name doesn't embed the behavior
// description verbatim.
//
// `--plain-name` is a literal SUBSTRING match against the OUTER test(...)
// name. When a hand-edited test renames the outer test('...') so it no
// longer contains the behavior description string verbatim, the runner
// matches ZERO tests, exits 79, and — pre-fix — the drift check graded the
// phantom as "still red", spent generation, and dead-ended in a generic
// `generation-error` with no diagnostic naming the actual cause.
//
// Remediation pinned here (from the assessment):
//   1. Zero-match detection — exit 79 + "No tests ran" under a
//      `--plain-name` template is a name-mismatch, never evidence.
//   2. Whole-file fallback + warning — make re-runs the WHOLE target file
//      through the profile's `file:` template so the cycle grades real
//      evidence (the issue's "best" expected fix).
//   3. Targeted remedy — when the fallback also runs zero tests (or the
//      profile carries no `file:` template), make emits "test name must
//      contain the behavior description verbatim — rename the test(...)
//      to embed it" and the drift check misfire-stops (the same no-signal
//      contract as the #742 timeout stop) instead of spending generation.
//
// Test map:
//   U1 — zero-match + whole-file fallback on a PASSING hand-edited test:
//        the skip transition certifies from the whole-file run (exit 0,
//        outcome=skipped) with the #1402 warning present.
//   U2 — zero-match + fallback ALSO zero-match (a target file with no
//        runnable tests): the targeted remedy is printed, the drift check
//        misfire-stops (exit 1, outcome=runner-error), no generation
//        spend, no green evidence.
//   U3 — a HEALTHY cycle (name embeds the description): no #1402 noise —
//        the fallback must not engage when --plain-name matches.
//   U4 — a profile without a `file:` template: the remedy-only path (no
//        fabricated runner invocation), remedy present, no fallback line.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

const feature = '090-bug-1402-plain-name';

/// The description the behavior is registered with — the string
/// `--plain-name` searches for in the outer test(...) name.
const description = 'returns 42 when invoked with no args';

/// A PASSING test whose outer name does NOT embed the description — the
/// issue's hand-edited shape (the registry's plain name matches nothing).
String handEditedGreenTest(String id) =>
    '''
// GENERATED TEST — `zfa tdd gen $id` (hand-edited name, issue #1402)
import 'package:test/test.dart';

void main() {
  test('HAND-EDITED name that does not embed the description', () {
    expect(42, equals(42));
  });
}
''';

/// A target file with NO runnable tests — the whole-file fallback also
/// matches zero (the remedy path).
String emptyMainTest(String id) => '''
// GENERATED TEST — hand-edited into an empty main (issue #1402 remedy case)
import 'package:test/test.dart';

void main() {
  // intentionally empty — no test() calls
}
''';

/// A PASSING test whose outer name DOES embed the description — the
/// healthy cycle (the documented workaround, `docs/zfa-tdd-guide.md` §8).
String embeddedGreenTest(String id, String desc) =>
    '''
// GENERATED TEST — `zfa tdd gen $id`
import 'package:test/test.dart';

void main() {
  test('$desc', () {
    expect(42, equals(42));
  });
}
''';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1402 — make detects the --plain-name zero-match', () {
    test(
      'U1: zero-match falls back to the whole target file and warns — '
      'a passing hand-edited test takes the honest skip transition',
      () async {
        await fx.seedCertifiedRed(
          id: 'B-1402',
          description: description,
          testContent: handEditedGreenTest('B-1402'),
        );

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(['tdd', 'make', 'B-1402', '--project', fx.root.path]);

        expect(exitCode, 0, reason: 'out: $out');
        expect(out, contains('outcome=skipped'));
        expect(
          out,
          contains('issue #1402: --plain-name matched ZERO tests'),
          reason: 'the name-mismatch warning must name the cause',
        );
        expect(
          out,
          contains('falling back to the whole target file'),
          reason: 'the fallback must be announced',
        );
        final log = await File(fx.cycleLogPath).readAsString();
        expect(
          log,
          contains('## Cycle: B-1402 (green)'),
          reason: 'the skip transition certifies green from the fallback run',
        );
      },
    );

    test(
      'U2: zero-match + fallback ALSO zero-match emits the targeted '
      'remedy and misfire-stops — no generation spend, no green evidence',
      () async {
        await fx.seedCertifiedRed(
          id: 'B-1402',
          description: description,
          testContent: emptyMainTest('B-1402'),
        );

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(['tdd', 'make', 'B-1402', '--project', fx.root.path]);

        expect(exitCode, 1, reason: 'out: $out');
        expect(out, contains('outcome=runner-error'));
        expect(out, contains('issue #1402: --plain-name matched ZERO tests'));
        expect(out, contains('falling back to the whole target file'));
        expect(
          out,
          contains(
            'test name must contain the behavior description '
            'verbatim — rename the test(...) to embed it',
          ),
          reason: 'the issue\'s minimum remedy, verbatim',
        );
        expect(
          out,
          contains(
            'the drift check (target test re-run before generation) '
            'ran zero tests',
          ),
          reason: 'the no-signal misfire-stop must name the drift check',
        );
        final log = await File(fx.cycleLogPath).readAsString();
        expect(
          log,
          isNot(contains('## Cycle: B-1402 (green)')),
          reason: 'a no-signal stop must never append green evidence',
        );
      },
    );

    test('U3: a healthy cycle (name embeds the description) gets NO '
        '#1402 noise — the fallback engages only on a zero-match', () async {
      await fx.seedCertifiedRed(
        id: 'B-1402',
        description: description,
        testContent: embeddedGreenTest('B-1402', description),
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'B-1402', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=skipped'));
      expect(out, isNot(contains('issue #1402')));
      expect(out, isNot(contains('falling back to the whole target file')));
    });

    test(
      'U4: a profile without a `file:` template takes the remedy-only '
      'path — the remedy is printed, no fallback runner is fabricated',
      () async {
        await fx.seedCertifiedRed(
          id: 'B-1402',
          description: description,
          testContent: handEditedGreenTest('B-1402'),
        );
        await Directory(
          p.join(fx.root.path, '.specify', 'memory'),
        ).create(recursive: true);
        await File(
          p.join(fx.root.path, '.specify', 'memory', 'tdd-profile.md'),
        ).writeAsString('''
# TDD Profile — no file key

## Commands

- Single test: `dart test {file} --plain-name "{name}"`
- Full suite: `dart test`

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
suite: 'dart test'
coverage: 'dart test --coverage'
```
''');

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(['tdd', 'make', 'B-1402', '--project', fx.root.path]);

        expect(exitCode, 1, reason: 'out: $out');
        expect(out, contains('outcome=runner-error'));
        expect(out, contains('issue #1402: --plain-name matched ZERO tests'));
        expect(
          out,
          contains(
            'test name must contain the behavior description '
            'verbatim — rename the test(...) to embed it',
          ),
          reason: 'remedy-only path: the minimum fix without a fallback run',
        );
        expect(
          out,
          isNot(contains('falling back to the whole target file')),
          reason: 'no `file:` template — no fabricated runner invocation',
        );
      },
    );
  });
}
