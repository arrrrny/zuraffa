# tdd.verify — Bug #1535 tdd-profile `single:` template parsing (YAML escapes + unknown placeholders)

- **Verified**: 2026-09-16, this session, on
  `fix/1535-tdd-profile-yaml-escape-placeholder` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Engine**: `zfa` binary unavailable on this machine (`zfa --version` →
  not found) → LLM-guided fallback audit per the tdd-verify skill's
  non-zuraffa path
- **Scope**: `lib/src/plugins/tdd/services/runner.dart` (parser-only fix),
  the new suite `test/plugins/tdd/bug_1535_profile_template_parsing_test.dart`

## Verdict: PASS

## 1. Static analysis + format gate

```
dart analyze lib/src/plugins/tdd/services/runner.dart
             test/plugins/tdd/bug_1535_profile_template_parsing_test.dart
→ No issues found!

dart format lib/src/plugins/tdd/services/runner.dart
            test/plugins/tdd/bug_1535_profile_template_parsing_test.dart
→ Formatted 2 files (0 changed)
```

Per the task's verify protocol, analyze runs on the changed files only;
the whole-repo info-level baseline drift noted by earlier verifications is
out of scope here.

## 2. TDD discipline (REAL runs in this session)

- RED, pre-fix (re-proven this session by stashing the fix and re-running —
  not trusted from the earlier cycle's log):

```
dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart --preset=all
→ 00:02 +2 -7: Some tests failed.

  Expected: 'dart test {file} --plain-name "{name}"'
    Actual: 'dart test {file} --plain-name \\"{name}\\"'   ← literal escapes survive
             Differ at offset 30

  Failing: AC-1 ×3 (Keys block / frontmatter / file:+suite: unescaping),
           AC-2 ×2 + bullet rejection ×1, AC-3 e2e (slow).
  Passing pre-fix: only the two AC-4 pre-existing-contract guards
  (single-quoted verbatim, legacy bullet normalization).
```

- GREEN, post-fix (fix restored; same command):

```
dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart --preset=all
→ 00:09 +9: All tests passed!
  (includes the slow AC-3 e2e: an honest red driven through the
  double-quoted escaped `single:` template runs exactly the target test —
  testCount == 1 — and classifies RedClassification.assertion)

dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart        (fast tier)
→ +8: All tests passed!
```

The fix was applied only after the repro tests were proven red (test-first
commit `1b6a45f7` precedes the fix in history; no test was edited to pass
retroactively — the working-tree test delta vs that commit is
formatting-only, verified by diff).

## 3. Mutation checks (changed file)

1. **Whole-fix-removal mutant** (the stash run above): all 7 bug behaviors
   failed → 7/7 killed.
2. **Targeted AC-2 mutant** — the load-time rejection neutralized in place
   (`if (false && unknown.isNotEmpty)` in `_prepareSingleScalar`):

```
dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart
→ 00:02 +6 -2: Some tests failed.
  killed by exactly the two AC-2 behaviors:
  - "rejects unknown placeholder <test name> at load time …"
  - "bullet path also rejects an unknown placeholder spelling"
```

The mutant was reverted and the working tree re-verified green
(`--preset=all` → +9 passed; `dart format` → 0 changed).

## 4. Regression suites (REAL runs in this session)

```
dart test test/plugins/tdd/services/
→ 01:16 +1120 -10: Some tests failed.
```

The 10 failures are all in `refactor_passes_test.dart` with
`FormatException: Unexpected extension byte (at offset 51)` surfacing through
`dart:isolate` — a pre-existing, environment-specific isolate-decoding
failure on this machine, NOT introduced by this change. Proven by re-running
the same file with the fix stashed:

```
git stash push -- lib/src/plugins/tdd/services/runner.dart
dart test test/plugins/tdd/services/refactor_passes_test.dart
→ +5 -10: Some tests failed.        (IDENTICAL 10 failures, same exception)
git stash pop
```

Runner-adjacent top-level suites:

```
dart test test/plugins/tdd/runner_instance_method_test.dart
          test/plugins/tdd/verify_red_subdirectory_test.dart
          test/plugins/tdd/bug_830_widget_subject_kind_test.dart
→ +20: All tests passed!
```

## 5. Acceptance criteria audit (issue #1535)

1. **AC-1 — double-quoted escapes unescaped** — PROVED: 3 red→green unit
   behaviors (Keys block, frontmatter, `file:`/`suite:`); pre-fix actual
   `--plain-name \\"{name}\\"` vs post-fix `"…"`. Single-quoted/unquoted
   scalars are NOT backslash-processed (style tracked at extraction).
2. **AC-2 — unknown placeholders rejected at load time** — PROVED: red→green
   behaviors for `<test name>` + the bullet lane, with the error naming
   `{file}`/`{name}` and the remedy; legacy `<path>`/`<file>`/`<name>`
   normalized acceptance pinned by the no-false-rejection guard; targeted
   mutant killed by exactly these tests.
3. **AC-3 — honest red through the escaped template certifies** — PROVED
   end-to-end (slow e2e, real `dart test` subprocess): testCount == 1 and
   `RedClassification.assertion` post-fix; pre-fix the loader assertion
   failed first (the exit-79 `runner-error` shape downstream).
4. **AC-4 — single-quoted form and legacy bullet unchanged** — PROVED: both
   guards passed PRE-fix (the fix did not need them loosened) and POST-fix.

Hard constraint honored: the diff touches only the template-parsing surface
of `runner.dart` — classifier, certification, and process-spawn code paths
are byte-identical to HEAD.

## 6. Verdict

PASS — parser-only fix with red→green evidence re-proven in this session, a
targeted mutation check killed by exactly the AC-2 behaviors, all four
acceptance criteria covered by tests that ran green, zero analyzer findings
on the changed files, zero format drift, and the only regression-suite
failures proven pre-existing environment issues unrelated to the change.
