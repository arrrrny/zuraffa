@Tags(['regression'])
// Regression guard for BUG-1188 (stop-on-roadblock PROGRESS.md path ignored):
// https://github.com/arrrrny/zuraffa/issues/1188
//
// AGENTS.md mandates recording run stoppages in
// `apps/zikzak_demo/PROGRESS.md` — the durable, committable record that a
// stopped run must leave behind. The root `.gitignore` carried BOTH an early
// bare `apps/` rule AND a later intentional re-include block:
//
//     apps/              <- bare rule: excludes the PARENT directory itself
//     ...
//     /apps/*            <- scratch apps stay ignored
//     !apps/zikzak_demo/ <- bug 501's mock ZikZak app is a committed deliverable
//
// Git cannot re-include a path whose parent directory is excluded, so the
// bare `apps/` rule silently defeated the `!apps/zikzak_demo/` negation:
// `git add apps/zikzak_demo/PROGRESS.md` was refused with "The following
// paths are ignored ... apps" and the AGENTS.md-mandated durable record
// could not be committed (the #1177 run had to park its record at
// `specs/081-skin-receipt-contract/PROGRESS.md` instead).
//
// This guard is deterministic and stays in the FAST default tier:
//   1. Behavioral: `git check-ignore` must NOT report the AGENTS.md-mandated
//      path `apps/zikzak_demo/PROGRESS.md` as ignored.
//   2. Syntactic defense in depth: the root `.gitignore` must not contain a
//      bare parent-directory rule for `apps` (the exact re-introduction
//      vector), and must still carry the intentional
//      `/apps/*` + `!apps/zikzak_demo/` narrowing block.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Ignore-rule lines that exclude the `apps` DIRECTORY ITSELF. Any of these
/// defeats every later `!apps/...` negation (git never descends into an
/// excluded parent directory), which is exactly how BUG-1188 shipped.
final _bareAppsParentRule = RegExp(r'^!?/?apps/?$');

/// The intentional narrowing block from the bug-501 deliverable comment:
/// scratch apps stay ignored, the committed ZikZak mock app does not.
const _scratchAppsRule = '/apps/*';
const _zikzakNegationRule = '!apps/zikzak_demo/';

void main() {
  test(
    'BUG-1188: AGENTS.md-mandated apps/zikzak_demo/PROGRESS.md is not gitignored',
    () {
      final rootIgnore = File('.gitignore');
      expect(
        rootIgnore.existsSync(),
        isTrue,
        reason: 'The test must run from the repo root (.gitignore present).',
      );

      // 1. Behavioral: the exact contract the bug broke. `git check-ignore`
      //    exits 0 when the path IS ignored (the bug), 1 when it is not,
      //    128 when not inside a git work tree (no ignore machinery to
      //    audit — an environment limitation, not a bug signal).
      final probe = Process.runSync('git', const [
        'check-ignore',
        '-v',
        '--',
        'apps/zikzak_demo/PROGRESS.md',
      ]);
      if (probe.exitCode == 128) {
        markTestSkipped(
          'git check-ignore unavailable here (exit 128): '
          '${probe.stderr}',
        );
      }
      expect(
        probe.exitCode,
        equals(1),
        reason:
            'apps/zikzak_demo/PROGRESS.md (the AGENTS.md stop-on-roadblock '
            'record) must be committable, but git check-ignore reports it '
            'ignored:\n${probe.stdout}\n'
            'A bare `apps/` parent rule in .gitignore defeats the '
            '!apps/zikzak_demo/ negation (BUG-1188).',
      );

      // 2. Syntactic defense in depth: no line in the root .gitignore may
      //    exclude the `apps` parent directory itself — that pattern shape
      //    is the re-introduction vector that produced BUG-1188. Scratch
      //    apps are ignored via `/apps/*` instead, which leaves the
      //    negation effective.
      final offenders = <String>[];
      final lines = rootIgnore.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#')) continue; // comment
        if (_bareAppsParentRule.hasMatch(line)) {
          offenders.add('.gitignore:${i + 1}: "$line"');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A bare `apps` ignore rule excludes the parent directory, and '
            'git cannot re-include paths under an excluded parent — it '
            'silently kills the !apps/zikzak_demo/ negation and makes the '
            'AGENTS.md-mandated apps/zikzak_demo/PROGRESS.md uncommittable '
            '(BUG-1188). Ignore scratch apps with /apps/* instead. Found:',
      );

      // 3. The intentional narrowing block must survive: scratch apps stay
      //    ignored and the committed ZikZak mock app subtree stays
      //    re-included (bug 501 deliverable, spec 011 US3).
      expect(
        lines.map((l) => l.trim()),
        contains(_scratchAppsRule),
        reason:
            'The /apps/* rule keeps scratch apps ignored (bug 501 comment '
            'block); removing it would un-ignore every scratch app '
            '(BUG-1188 regression in the opposite direction).',
      );
      expect(
        lines.map((l) => l.trim()),
        contains(_zikzakNegationRule),
        reason:
            'The !apps/zikzak_demo/ negation is the committed deliverable '
            'contract from bug 501 (spec 011 US3); removing it re-ignores '
            'the mock ZikZak app subtree (BUG-1188 regression in the '
            'opposite direction).',
      );
    },
  );
}
