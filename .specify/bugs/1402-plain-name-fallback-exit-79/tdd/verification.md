# Verification — #1402 fix (REAL run, this session)

**Branch:** `fix/1402-plain-name-fallback-exit-79`
**Toolchain:** Dart SDK 3.13.3 (stable) on linux_x64 — the repo's
`dependency_overrides:` section is absent (removed per spec 018, verified
before `dart pub get`); dependencies resolve from pub.dev.
**Date:** 2026-09-09 (session-local clock)

## 1. Live CLI evidence (real `zfa tdd make` subprocess runs)

Repro harness: throwaway dart project with the standard
`.specify/memory/tdd-profile.md` (runner dart), a certified-red cycle-log
entry, and a registry record whose plain name is
`returns 42 when invoked with no args` while the OUTER test name is
hand-edited to `HAND-EDITED name that does not embed the description`.

### Pre-fix (binary at 27644a49 + zero fix)

- `zfa tdd make B-1402 --project <fixture>` → exit 1.
- Drift check matched ZERO tests (exit 79, "No tests ran") — consumed
  SILENTLY; make spent a 2-step generation pipeline and stopped
  `outcome=generation-error`.
- `grep "must contain the behavior description verbatim"` → 0 hits (the
  bug).

### Post-fix — fallback path (hand-edited name, test runnable)

- `zfa tdd make B-1402 --project <fixture>` → exit 0,
  `outcome=green-with-failed-build` (the fixture lacks build_runner; the
  terminal build failure is the documented #737/#942 per-behavior-tolerance
  class).
- Transcript contains:
  `issue #1402: --plain-name matched ZERO tests — the outer test(...) name
  does not contain the behavior description verbatim (command: ...)` and
  `falling back to the whole target file: dart test {file}` — the cycle
  re-certified from the whole-file run's real evidence.

### Post-fix — remedy path (hand-edited name AND a target file with zero tests)

- `zfa tdd make B-1402 --project <fixture>` → exit 1,
  `outcome=runner-error`, stop BEFORE generation.
- Transcript contains the targeted remedy, verbatim:
  `--> fix: test name must contain the behavior description verbatim —
  rename the test(...) to embed it (issue #1402).`
  plus the no-signal stop: `the drift check (target test re-run before
  generation) ran zero tests; the cycle cannot be re-certified from this
  transcript.`

## 2. TDD red → green (test/plugins/tdd/bug_1402_plain_name_fallback_test.dart)

- RED (fix stashed, binary at 27644a49):
  `dart test --preset=all --plain-name "issue #1402"
  test/plugins/tdd/bug_1402_plain_name_fallback_test.dart`
  → `+1 -3: Some tests failed.` (U1, U2, U4 fail; U3 — the healthy-cycle
  no-noise contract — passes pre-fix by design).
- GREEN (fix restored): same command → `+4: All tests passed!` (U1, U2,
  U3, U4).

## 3. Scoped regression checks (files/paths touched by the change only)

- `dart analyze lib/src/plugins/tdd/commands/make_command.dart
  test/plugins/tdd/bug_1402_plain_name_fallback_test.dart`
  → No issues found!
- `dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart
  test/plugins/tdd/bug_1258_skin_author_make_test.dart
  test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart
  test/plugins/tdd/bug_1159_baseline_timeout_test.dart`
  → `+34: All tests passed!` (drift/skip, skin-authoring re-certification,
  re-drive adoption, baseline-timeout paths).
- `dart test --preset=all test/plugins/tdd/make_command_1036_test.dart
  test/plugins/tdd/issue_1330_make_subject_edit_fallback_test.dart
  test/plugins/tdd/make_build_step_classifier_test.dart`
  → `+13: All tests passed!` (subject-drift refusal, subject-edit fallback,
  build-step classifier).
- `make_command_test.dart` (spec 047 core suite):
  `+33 -5` on the FIXED tree — and the SAME `+33 -5` on clean HEAD
  (fix stashed): the 5 failures are PRE-EXISTING in this environment
  (subprocess/isolate entrypoint quirks of the sandbox kernel cache, e.g.
  `type 'Null' is not a subtype of type 'SendPort'` from the child zfa
  spawn), not regressions of this change. Flagged per the report protocol.

## 4. Format gate

- `dart format .` → `Formatted 2664 files (0 changed).`
- `git diff --stat` after format: ONLY
  `lib/src/plugins/tdd/commands/make_command.dart` (+129/−4) — zero
  formatting diffs anywhere.

## 5. Success criteria — PROVED vs not

- PROVED: zero-match detection (exit 79 + "No tests ran" under a
  `--plain-name` template), whole-file fallback + warning, targeted remedy
  (verbatim, both the fallback-exhausted and fileless-profile paths),
  drift-check no-signal misfire-stop, no green evidence on any stop,
  healthy-cycle byte-identical behavior (no #1402 noise), red→green, scoped
  suites green, format gate clean.
- NOT RUN (out of scope by the cloud-agent disk constraint and the issue's
  hard constraints): the full suite (no `--preset=all` repo-wide run —
  ~6.5 GB kernel-cache risk), verify-red suites (verify-red logic
  untouched), flutter-profile live runs (no Flutter SDK in this
  environment — the fallback uses the same profile `file:` template and
  the identical wrapper on both runners; the dart lane proves the logic).

## 6. Disk housekeeping

Repro fixtures (`/tmp/repro_*`, `/tmp/tdd_fixture_*`), dart kernel caches
(`/tmp/dart_test.kernel.*`, `.dart_tool/test/`) deleted after each phase;
`df -h .` at delivery: 8.2G free of 9.9G (13% used) — healthy.
