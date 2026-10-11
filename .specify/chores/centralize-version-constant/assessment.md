# Chore Assessment: Centralize version constant — eliminate hardcoded version literals

- **Slug**: centralize-version-constant
- **Created**: 2026-09-08
- **Source**: pasted text
- **Verdict**: in scope
- **Size**: medium

## Report (verbatim or summarized)

> I remember somewhere in the code we had a constant as "version" this reminds me
> that we should have a global establisment of current version, so when the version
> is bumped, all tests read from this version number constants rather than hardcoded
> number. find every hardcoded number reference and turn into a referenced version
> constant

## Summary

`lib/src/version.dart` already holds the single source of truth (`const version = '6.2.2'`)
and most of `lib/` imports it. The chore is to extend that contract to the remaining
hardcoded version literals in tests and lib: ~21 `generatorVersion: '6.1.0'`-style
fixture literals across ~12 test files, one MCP `serverInfo.version` literal in
`lib/src/mcp/v2_tools.dart`, and the 12 state-snapshot goldens that carry a stamped
`Generator version:` line — the exact failure class that turned PR #1346 red when
6.2.2 shipped without re-baselining them. This is maintenance (no user-facing change):
a bug-prevention refactor of test expectations and fixtures.

## Constitution Check

`.specify/constitution.md` does not exist in this repo — no constitution principles
to check against. Standard constraints apply: no new runtime dependencies, changes
must not weaken what any test asserts (historical-version fixtures that deliberately
exercise old-version/floor behavior keep their literals — see Proposed Approach).

## Affected Paths

Evidence-backed hardcoded-version sites (current version = 6.2.2):

- `lib/src/version.dart:1` — the existing `const version = '6.2.2'`; the reference constant.
- `lib/src/mcp/v2_tools.dart:864` — `'version': '6.0.0'` in MCP `serverInfo` initialize response; a stale literal that should track the constant.
- `test/core/proof_checker_test.dart` (6 sites) — `generatorVersion: '6.1.0'` fixture receipts.
- `test/core/receipt_store_test.dart:25,77` — fixture + `json['generator_version']` expectation.
- `test/commands/proof_command_test.dart:46` — `generatorVersion: '6.1.0'` fixture.
- `test/plugins/tdd/commands/realize_command_test.dart:87`, `realize_diff_only_test.dart:88`,
  `referee_command_test.dart:72`, `realize_command_1193_test.dart` — same pattern.
- `test/plugins/tdd/services/nuance_receipts_test.dart:129`, `provenance_rollup_test.dart`,
  `ci_referee/feature_provenance_reader_test.dart` — same pattern.
- `test/plugins/tdd/theater/theater_fixture.dart:298` — `generatorVersion: '6.1.0'`.
- `test/plugins/state/golden/*.dart.txt` (12 files) — stamped `// Generator version: 6.2.2.`
  header bytes compared byte-for-byte by `state_snapshot_test.dart` SC-3; the 6.2.2 bump
  broke this on every branch until PR #1346 re-baselined them.
- `test/plugins/state/state_snapshot_test.dart:112-225` — the comparator that enforces
  byte-identity against the stamped goldens (the pinch point; see alternatives).

**Explicitly NOT in scope (different concepts — keep literals):**

- `lib/src/skew/skew_contract.dart:53` — `supportedCoreFloor = '6.0.0'` (oldest supported
  core, a floor registry, not the current version) and the `introducedIn: '6.2.0'` surface
  registry entries.
- `test/skew/bug_1197_receipt_stamp_test.dart:48` — `'6.1.0'` deliberately simulates a
  legacy receipt for floor evaluation.
- `test/commands/update_command_test.dart:70-73` — `compareVersions` unit tests using
  arbitrary version pairs.
- `test/plugins/slice/exporter/pubspec_filter_test.dart` — `'6.2.0'` is fixture input data
  for the exporter, not an expectation about the current version.

**Already correct (the precedent to follow):**

- `test/skew/bug_1197_receipt_stamp_test.dart:26,92` — imports `package:zuraffa/src/version.dart`,
  uses `generatorVersion: version`, and carries an explicit "de-hardcoding guard" comment.
- `test/plugins/state/state_provenance_test.dart:62`, `test/package_sdk/*_test.dart`,
  `test/skew/bug_1197_doctor_skew_test.dart` — already import and assert against the constant.

## Proposed Approach

**Preferred**: Two mechanical passes plus one design decision.

1. **Fixture de-hardcoding pass.** In every `generatorVersion: '<literal>'` test site,
   classify the literal: if the fixture means "a receipt written by the current generator"
   (the majority — the value is never compared against a floor or an old-version branch),
   replace with the imported `version` constant, matching the `bug_1197_receipt_stamp_test.dart`
   precedent. Sites that deliberately simulate legacy receipts (e.g. skew floor evaluation)
   keep their literal and gain a one-line comment saying why, so a future sweep doesn't
   "fix" them blindly.
2. **lib literal.** `lib/src/mcp/v2_tools.dart` `serverInfo.version` → the `version`
   constant (import already exists in that file or is a one-line add). Check whether any
   MCP test asserts `'6.0.0'` there and update it to `version` as well.
3. **Golden stamped-version decision.** Pick one of the alternatives below and apply it.
   This is the only part with real design weight; passes 1–2 are pure refactor.

**Alternatives** for the golden stamped version (the recurring bump pain):

- **A. Normalize in the comparator (recommended).** In `state_snapshot_test.dart`,
  replace the exact `Generator version: X.Y.Z` line with a placeholder in *both* the
  golden bytes and the generated bytes before comparing (or inject the live `version`
  const into the golden text at compare time). Goldens become bump-proof forever;
  the byte-identity guarantee still covers all real emission logic. Zero per-release
  ritual. Slight cost: the version stamp itself is no longer golden-tested — but
  `state_provenance_test.dart:62` already asserts `header contains version`, so
  coverage is not lost.
- **B. Keep re-baselining.** Status quo: on every version bump run
  `ZFA_STATE_UPDATE_GOLDENS=1` and commit 12 changed files. Zero code churn now,
  but it has already failed once (PR #1346 went red; master itself carried stale
  6.2.0 goldens after the 6.2.2 release) and will fail again.
- **C. Placeholder in goldens.** Store `{{version}}` in the committed `.dart.txt`
  files and substitute at compare time. Same effect as A but makes goldens
  non-byte-reproducible outside the test harness — A is cleaner.

**Paths likely to change**:

- `lib/src/mcp/v2_tools.dart` (1 line + possible test)
- ~12 test files listed above (mechanical literal → `version`)
- `test/plugins/state/state_snapshot_test.dart` + 12 golden files (alternative A only)
- Optionally `scripts/publish.sh`: add a post-bump assertion that `pubspec.yaml` version
  equals `lib/src/version.dart` (the 6.2.0-pubspec-vs-6.2.1-CHANGELOG drift showed the
  two files can diverge; a one-line grep guard in the script prevents a half-bumped release)

**Verification to run**:

- `dart format --set-exit-if-changed lib test`
- `dart analyze lib test`
- Targeted: `dart test test/core/proof_checker_test.dart test/core/receipt_store_test.dart
  test/commands/proof_command_test.dart test/plugins/state/
  test/plugins/tdd/commands/realize_command_test.dart test/skew/ test/plugins/mcp/`
- Full fast suite: `dart test` (or `tools/run_tests_chunked.sh` on small disks)
- Bump drill (the proof the chore works): temporarily set `version` to `6.2.3-dev` in a
  scratch tree and confirm zero test failures without touching any golden or fixture.

## Risks & Considerations

- **Weakened tests.** Blindly replacing every literal with `version` would break the
  *meaning* of fixtures that simulate legacy receipts (skew floor tests rely on a version
  below/above `supportedCoreFloor`). The per-site classification in pass 1 is the
  load-bearing part of this chore; document kept literals with comments.
- **Golden normalization scope.** If alternative A is chosen, only the version line may
  be normalized — normalizing anything else silently voids the byte-identity guarantee
  the test exists for.
- **MCP protocol surface.** Changing `serverInfo.version` from the long-stale `'6.0.0'`
  to the live version is user-visible to MCP clients that log/display it; it is a
  correction, not a breakage (no capability depends on it), but worth a CHANGELOG line.
- **Sweep completeness.** The literal list above is from grepping `6\.[0-9]+\.[0-9]+`
  in `test/` and `lib/`; the implement pass should re-run the grep (including
  `benchmark/`, `example/`, `bin/`) rather than trusting this list verbatim.

## Open Questions

- [NEEDS CLARIFICATION: golden strategy — alternative A (normalize in comparator,
  recommended), B (keep re-baselining), or C (placeholder in goldens)?]
- [NEEDS CLARIFICATION: should `scripts/publish.sh` gain the pubspec↔version.dart
  equality guard as part of this chore, or is that a separate chore?]
