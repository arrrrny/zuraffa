# tdd.verify — Bug #1575 fence-blind line-scanners outside the cycle-log

- **Verified**: 2026-09-13, this session, on
  `fix/1575-remaining-fence-blind-line-scanners` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64 (Flutter SDK absent —
  recorded where it matters, §3/§4)
- **Scope**: the two changed source files, the two new fence-fixture
  suites, the pre-existing reader/proof suites, then the full 1,294-file
  chunked regression sweep below.

## Verdict: PASS (the only non-green entries are pre-existing host-environment gaps, proved on a pristine pre-fix worktree)

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/services/test_list_reader.dart \
             lib/src/core/proof/proof_chain_checker.dart \
             test/plugins/tdd/services/test_list_reader_1575_fence_test.dart \
             test/core/proof_chain_checker_1575_fence_test.dart
→ No issues found!
```

Full-project `dart analyze`: **112 issues — identical to the pre-change
baseline** (a pristine worktree at the pre-fix commit d5a40731 analyzes to
the same 112, 0 errors / 0 warnings on both sides).

`dart format` on the four changed Dart files: clean (idempotent, no diff).

## 2. The bug suites (REAL runs in this session)

RED (pre-fix tree, commit d5a40731 — full evidence in
`.specify/bugs/1575-remaining-fence-blind-line-scanners/red-evidence.md`):

```
dart test test/plugins/tdd/services/test_list_reader_1575_fence_test.dart \
          test/core/proof_chain_checker_1575_fence_test.dart
→ 5 failed / 3 passed   (reader file)
→ 2 failed / 1 passed   (proof-chain file)
```

Every failure mode from the issue reproduced verbatim: an in-fence
`## Inner loop:` banner mis-kinded a post-fence acceptance row
(acceptance → unit); an in-fence `## Key entities` banner silently
swallowed a post-fence behavior row; the same silent vanish in
`readEntities` / `readDependencies` / `readLayerContracts`; a post-fence
behavior id (`B2`) silently dropped from the coverage audit; a fenced
`## Behaviors (example)` table fabricating a phantom `PHANTOM` audit id.

GREEN (post-fix tree, commit 5484f162):

```
dart test test/plugins/tdd/services/test_list_reader_1575_fence_test.dart \
          test/core/proof_chain_checker_1575_fence_test.dart
→ 00:00 +11: All tests passed!
```

REQUIRED check — the five `startsWith('## ')` sites are routed through
the fence-aware splitter: PROVED by A-1575-a1/a2 (parseRows kind-flip and
declarative-swallow), A-1575-a3/a4/a5 (the three declaration readers),
U-1575-c1/c2 (the audit id vanish and phantom fabrication).

REQUIRED check — well-formed parsing is unchanged (hard constraint):
PROVED by U-1575-b1 (no-fence canonical list), U-1575-b2 (the committed
corpus shape — the one real in-fence `## ` at
`specs/004-fix-zuraffa-gen/tdd/test-list.md:83` — parses identically),
U-1575-c3 (the well-formed behaviors audit), and the pre-existing suites
below.

REQUIRED check — the line-naming error contract (bug #984) survives the
section→line reconstruction: PROVED by U-1575-b3 (a malformed row after a
fence reports `test-list.md line 7: expected 4 columns …`, byte-exact).

REQUIRED check — the cycle-log readers are untouched (hard constraint):
`git diff` names exactly two `lib/` files; `provenance_scanner.dart`,
`ci_referee/*`, `cycle_log_sections.dart`, `cycle_log_entry_sections.dart`
have no changes, and their suites are green in the sweep (§3).

## 3. Regression sweep (REAL runs in this session)

The full suite — every `test/**/*_test.dart` file, 1,294 files — ran in
26 chunks of ≤50 files (`dart test` per chunk, caches cleaned per
protocol afterwards):

| Chunk | Result |
| ----- | ------ |
| 1–7, 10–19, 21–25 | `All tests passed!` |
| 8 | `controller_compile_test.dart` (setUpAll) — environmental, see §4 |
| 9 | `presenter_compile_test.dart` (setUpAll) — environmental, see §4 |
| 20 | `view_compile_test.dart` (setUpAll) — environmental, see §4 |
| 26 | `templates/self_hosting/downstream_compile_gate_test.dart` (setUpAll) — environmental, see §4 |

Totals across the sweep: **≈6,507 tests passed, 4 failed** (the four
`(setUpAll)` entries below; a log-string audit for `[E]` finds no other
failure anywhere in the sweep).

Targeted pre-existing suites around the changed readers (REAL runs):

```
dart test test/plugins/tdd/services/test_list_reader_test.dart \
          test/plugins/tdd/services/test_list_reader_984_test.dart \
          test/plugins/tdd/services/test_list_reader_ffi_835_test.dart \
          test/plugins/tdd/services/test_list_reader_persistence_833_test.dart \
          test/plugins/tdd/services/bug_919_reader_test.dart \
          test/plugins/tdd/bug_937_reader_sections_test.dart \
          test/core/proof_chain_checker_test.dart
→ 00:03 +76: All tests passed!
```

## 4. The non-green entries — all proved to pre-date this change

Each of the four failing suites spawns the Flutter toolchain in its
`setUpAll` via `test/plugins/helpers/flutter_cluster_fixture.dart`
(`flutter pub get --no-example`), and this host has **no Flutter SDK**:

```
ProcessException: No such file or directory
  Command: flutter pub get --no-example
```

The same four files fail identically on a pristine worktree at the
pre-fix commit d5a40731 (verified by running
`controller_compile_test`, `presenter_compile_test` and
`view_compile_test` there — same `ProcessException`, same command):
controller, presenter and view generated code targets a Flutter app, so
these compile pins require the Flutter toolchain. The failure is a host
gap (the same one `dart pub get` reports for `example/`), not a
regression; the codegen surfaces they pin are untouched by this fix.

No assertion-level failure was introduced by the change.

## 5. Environment notes (honest recording)

- Chunked execution ran in the foreground on a single-tenant host; the
  kernel/build caches were cleared after the sweep per the verification
  hygiene protocol (`rm -rf .dart_tool/test/`, dart test kernel temp).
- The full-project analyze parity (112 == 112) and the pristine-worktree
  comparisons above were run against a `git worktree` at the pre-fix
  commit, removed after use (disk housekeeping).
- The 004 corpus fixture (`specs/004-fix-zuraffa-gen`) parses
  byte-identically before and after the fix (U-1575-b2), so no committed
  artifact shifts.
