// EPIC 1133 — flutter-lane transcript grammar pin + evidence readability
// fix, discovered live on the 004-login-ui corpus.
//
// Two contracts, one file:
//
// 1. PINNED (already true, guarded here so it stays true): the compact
//    reporter of `flutter test` rewrites its progress line in place —
//    every update is `\r`-prefixed and space-padded, with no trailing
//    newline on the final line. The single-test runner captures stdout
//    and stderr SEPARATELY and concatenates them, so the last progress
//    line can sit inside the `\r` blob. Dart's multiline `^` matches
//    after `\r` (ECMAScript line-terminator rule), so
//    `parseExecutedTestCount` still reads the executed count and
//    `classify` still certifies the honest red. This file pins that
//    grammar against regressions: a `\r`-joined transcript with an
//    Expected/Actual + TestFailure signature MUST classify `assertion`
//    with executed-count exactly 1 — the referee may never answer
//    "the runner did not execute exactly the target test" to a
//    transcript that executed exactly one test.
//
// 2. FIXED here (was true-but-ugly): the captured output kept the
//    compact reporter's `\r` line rewrites verbatim, so every evidence
//    excerpt rendered into cycle-log.md / verification.md was a `\r`
// -glued one-line blob. `runSingle`/`runSuite` now normalize `\r` to
//    `\n` at the capture boundary — line-shaped transcripts for humans,
//    identical bytes for every line-anchored parser (the classifier's
//    `^` semantics are unchanged: after `\r` or after `\n`).
//
// Test tier: FAST (spawns a `bash` fixture script; no flutter, no dart
// test subprocess).
//
// RED evidence (pre-fix): the runSuite excerpt assertion fails — the
// output carries raw `\r` rewrites. The classify/count pin passes
// before and after (it documents the grammar the referee already
// honors).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/red_classification.dart';
import 'package:zuraffa/src/plugins/tdd/services/red_classifier.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';

void main() {
  late Directory tmpDir;
  late File fixtureScript;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('epic1133_transcript_');
    // The captured shape from the live 004-login-ui A4 run, verbatim:
    // stdout is ONE \r-joined blob (compact reporter line rewrites,
    // space-padded, no trailing newline); stderr carries the flutter
    // TestFailure dump with the Expected/Actual assertion signature.
    fixtureScript = File(p.join(tmpDir.path, 'fake_flutter_test.sh'))
      ..writeAsStringSync('''
#!/usr/bin/env bash
printf '\\r00:00 +0: loading test/tdd/004-login-ui/a4_test.dart'
printf '                                                                                    '
printf '\\r00:02 +0: A4 (AC-4) A4 \\u2014 the app navigates to the route '
printf "'deal_list'"
printf '                                                                                    '
printf '\\r00:02 +0 -1: A4 (AC-4) A4 \\u2014 the app navigates to the route '
printf "'deal_list'"
printf ' [E]'
printf '                                                                                    '
printf '\\r00:02 +0 -1: Some tests failed.'
printf '\\n\\xe2\\x95\\x90\\xe2\\x95\\x90\\xe2\\x95\\xa1 EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK \\xe2\\x95\\x9e\\n'
printf 'The following TestFailure was thrown running a test:\\n'
printf "Expected: contains 'deal_list'\\n"
printf "  Actual: ['/']\\n"
printf "   Which: does not contain 'deal_list'\\n"
exit 1
''');
    Process.runSync('chmod', ['+x', fixtureScript.path]);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('a \\r-joined flutter transcript classifies assertion with count 1 '
      '(grammar pin)', () async {
    const record = SingleTestRunner();
    final run = await record.runSingle(
      singleTemplate: 'bash {file} --plain-name "{name}"',
      testPath: fixtureScript.path,
      testName: "the app navigates to the route 'deal_list'",
      workingDirectory: tmpDir.path,
    );

    expect(run.exitCode, 1, reason: 'the fixture red is a real failure');
    expect(
      run.testCount,
      1,
      reason:
          'exactly one test executed — the compact reporter line '
          'rewrites must never hide the executed count from the referee',
    );
    expect(
      classify(run),
      RedClassification.assertion,
      reason:
          'the transcript carries the Expected/Actual + TestFailure '
          'signature of the authored finder red — an honest red the '
          'referee must certify',
    );
  });

  test('captured output is line-shaped: \\r rewrites normalized at the '
      'capture boundary', () async {
    const record = SingleTestRunner();
    final run = await record.runSingle(
      singleTemplate: 'bash {file} --plain-name "{name}"',
      testPath: fixtureScript.path,
      testName: "the app navigates to the route 'deal_list'",
      workingDirectory: tmpDir.path,
    );

    expect(
      run.output.contains('\r'),
      isFalse,
      reason:
          'evidence excerpts rendered into cycle-log.md and '
          'verification.md must be line-shaped, not \\r-glued '
          'compact-reporter blobs',
    );
    expect(run.output, contains("Expected: contains 'deal_list'"));
    // The normalization must not lose the progress-line grammar.
    expect(run.output, contains('00:02 +0 -1: Some tests failed.'));
  });

  test('runSuite normalizes the same shape for preflight evidence', () async {
    const record = SingleTestRunner();
    final suite = await record.runSuite(
      suiteTemplate: 'bash "${fixtureScript.path}"',
      workingDirectory: tmpDir.path,
    );

    expect(suite.exitCode, 1);
    expect(
      suite.output.contains('\r'),
      isFalse,
      reason: 'verification.md preflight excerpts must be line-shaped',
    );
    expect(suite.output, contains("Expected: contains 'deal_list'"));
  });
}
