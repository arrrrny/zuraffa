# TDD Verification — 1610-extract-canonicalize-missing-path

**Command**: /speckit.tdd.verify (fallback path — project is not
zuraffa-wired: no `.zfa.json`) · **Date**: 2026-09-16 · **Branch**:
`chore/1610-extract-canonicalize-missing-path` · **Head at verify**:
`c60f150c`

All numbers below are from REAL runs in this session. Kernel/test caches
were cleared before each targeted run (`rm -rf .dart_tool/test/`;
`rm -f $TMPDIR/dart_test.kernel.*`) and after the last run, per the
cloud-agent protocol.

## 1. Test-first & red evidence integrity

- Test file `test/plugins/tdd/services/path_canonicalizer_test.dart` was
  committed with its mutation red evidence in one commit (`781ce745`,
  merged as `8870a796`) BEFORE the doc-comment change (`c8eecda2`); git
  history ordering honors red-before-implementation for the only source
  touch (comments).
- The suite is green-by-design against the pre-existing helper (the
  mechanical extraction landed on master via `994daeb1`, PR #1611 review) —
  recorded honestly as a characterization baseline in
  `tdd/cycle-log.md` (T001 cycle), with strength proven by deliberate
  mutants (SC-3), not assumed.
- Per-mutant red/green evidence (`tdd/cycle-log.md`, T001m cycle):

| mutant | deliberate change | predicted killer | actual killer | decisive evidence | restore |
| ------ | ----------------- | ---------------- | ------------- | ----------------- | ------- |
| M1 | `...tail.reversed` → `...tail` | U2 | U1 + U2 | U2 actual `/tmp/.../subject.dart/missing_b/missing_a` (reordered) | GREEN +4 |
| M2 | return `path` on first FileSystemException (walk-up skipped) | U1 + U2 | U1 (first run: U2 survived on non-symlinked `/tmp`) → U1 + U2 after U2 was strengthened to travel the alias form | U1 actual `/tmp/..._alias/missing/subject.dart` (raw alias leaked) | GREEN +4 |
| M3 | `p.joinAll([resolved])` (tail re-append dropped) | U1/U2/U3 | U1 + U2 + U3 + U4 | every exact-match lost the re-appended segment(s) | GREEN +4 |

- Mutation hygiene: after each restore `git diff` on `lib/` was EMPTY;
  mutant states were never committed.
- Honest deviations (recorded verbatim in the cycle log, not silently
  rewritten): (a) U3's first baseline run failed on an async `Link.create`
  fixture race — fixed with `createSync`, helper untouched; (b) M2's first
  run was survived by U2 on a non-symlinked `/tmp` — U2 strengthened (chain
  travels the alias) so every mutant now has an independent kill.

## 2. Suite results (final tree, this session)

| suite | invocation | result |
| ----- | ---------- | ------ |
| new direct pins (U1–U4) | `dart test test/plugins/tdd/services/path_canonicalizer_test.dart` | `00:00 +4: All tests passed!` — 4 passed, 0 failed |
| view command pins (U-V3, U-V11/U-V12/U-V13, U-1603a/b) | `dart test --preset=all test/plugins/tdd/commands/view_command_test.dart` | `00:06 +15: All tests passed!` — 15 passed, 0 failed |
| wire command pins (U-W3, U-1603e) | `dart test --preset=all test/plugins/tdd/wire_command_test.dart` | `00:05 +16: All tests passed!` — 16 passed, 0 failed |
| func command pins (U-1603c, U-F5) | `dart test test/plugins/tdd/commands/func_command_test.dart` | `00:03 +10: All tests passed!` — 10 passed, 0 failed |
| analyzer (changed scope: helper + new test) | `dart analyze lib/src/plugins/tdd/services/path_canonicalizer.dart test/plugins/tdd/services/path_canonicalizer_test.dart` | `No issues found!` |
| format gate | `dart format .` → 1 file normalized (the new test, wrapping only) then `dart format --set-exit-if-changed <touched files>` | `Formatted 2 files (0 changed)`, exit 0; `git diff --stat` shows zero remaining formatting diffs |

Baseline cross-check: the pin suites' counts match the cycle-0 baseline
recorded before any change (view 15, wire 16, func 10) — zero regressions,
zero unrelated failures encountered.

## 3. Acceptance criteria / SC coverage matrix

| criterion | verdict | proof |
| --------- | ------- | ----- |
| AC: one shared helper, documented precondition, used by both commands (issue #1610 AC-1 / FR-001, FR-002, FR-003 / SC-1) | **PROVED** | doc comments in `path_canonicalizer.dart` name the absolute-input precondition, the relative-input CWD-join failure mode, the callers' absolutize obligation, and the input-unchanged fallback; `git diff` on the file touches `///` lines only (zero executable-line delta); view + wire (and func) import the shared helper; no `_canonicalizeMissingPath` copy exists under `lib/` |
| AC: direct unit test covering walk-up and tail order (issue #1610 AC-2 / FR-004, FR-005 / SC-2, SC-3) | **PROVED** | 4 pins green (exact-match expectations); M1 (tail order) and M2 (walk-up skip) mutants each turn the suite RED with recorded decisive failure lines; M3 (tail drop) kills all four |
| AC: existing view_command_test.dart and wire_command_test.dart pins stay green (issue #1610 AC-3 / FR-006, FR-003 / SC-4) | **PROVED** | 15/15 and 16/16 green under `--preset=all` (slow tag) with zero source change to either command file (verified by `git diff --stat`: only the new test file + docs changed) |
| Call-site re-check (US1/A2) | **PROVED** | view/wire/func each absolutize before calling (`p.normalize(p.absolute(cwd))` + relative recorded subjects joined onto the absolute root) — the documented precondition matches reality |
| Test-strength audit (smell rubric) | **PASS** | exact-match assertions (no `contains`), deterministic POSIX fixtures (`createSync`), per-test Windows skip via the repo `onPlatform` convention, no async races (fixture note in cycle log), no vacuous passes (slow-tag suites run under `--preset=all`) |

## 4. Not proved / honest limits

- The helper's hard defensive branch (input returned UNCHANGED when even
  the filesystem root fails to resolve) is NOT directly asserted: it is
  unreachable through the public surface on POSIX (`/` always resolves)
  and faking it would require a filesystem seam, which the chore's hard
  constraint forbids (spec.md "Out of scope"). It is documented in the
  helper's doc comment and named as unreachable in the U4 test body. The
  reachable exhaustion behavior (walk anchoring at the resolved root with
  all segments re-appended) IS asserted (U1/U2/U4).
- Mutation strength is proven by deliberate manual mutants, not a wired
  mutation tool — the repo's established precedent (PR #1606 verification).
- Pins were run on Linux x64 only; the macOS `/var` → `/private/var`
  production shape is covered by the deterministic sibling-alias fixture
  (the same approach as U-V11), not by the OS's own symlink.
- `dart format .` touched 2,884 files' scan but only normalized the NEW
  test file; no pre-existing formatting drift was introduced by this
  branch (`git diff --stat` after format: 1 file, the test, committed as
  `c60f150c`).

## 5. Verdict

**PASS** — test-first discipline honored (characterization baseline +
mutation-sampled strength), all four issue-1610 acceptance criteria proved
by the runs above, zero pin regressions, analyze/format gates clean.
