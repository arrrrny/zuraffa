# TDD Verification: 1690-companion-seams

- **Slug**: 1690-companion-seams
- **Verified**: 2026-09-18
- **Method**: real red → green over the pinned seams (unit: fake-compiler
  hermetic runs; e2e: real `dart pub get` + real AOT companion compile +
  real child spawn), plus deliberate-mutant sampling per the TDD
  profile's rubric (no mutation tool is wired), plus the untouched
  neighbor suites.
- **Deterministic-engine note**: `/speckit.tdd.verify` Step 0 ran
  `zfa --version && test -f .zfa.json` → `ZFA_MISSING` (no installed zfa
  engine in this environment), so the skill's fallback LLM-guided audit
  produced this file. As with 1669, this bug directory has no
  `tdd/artifacts.json` scope for the step-spawning pipeline — the
  subject under fix is this repository itself.
- **Result**: verified — every check below is from an ACTUAL run in this
  session on the fix branch (Dart SDK 3.13.4 stable); nothing is copied
  or back-dated.

## Checks

| # | Check | Command | Result | Evidence |
|---|-------|---------|--------|----------|
| 1 | RED §1 (pre-fix) | `dart test test/plugins/plugin_gate/plugin_gate_test.dart` on the tests alone | FAIL ×2 — the RIGHT failures | U7a/U7b: `Expected: '/tmp/gate_u7_companion_PJIXDZ/bin/zuraffa_graphql.dart' / Actual: <null>` — relative rootUri → null (the issue's defect byte-for-byte); U7c/U7d passed pre-fix (guards hold) |
| 2 | RED §2 (pre-fix) | `dart test test/cli/zfa_executable_test.dart --plain-name "U12"` (pass-through `packagesFile` stub) | FAIL ×4 — the RIGHT failures | argv had NO `--packages=`; artifact written INSIDE the companion source root (`/tmp/zfa_companion_stale_…/.dart_tool/zfa_cli_bin/…` — the pub-cache-mutating shape); same slot for two projects; config rewrite did not invalidate. U12e (legacy) passed pre-fix |
| 3 | GREEN §1+§2 | `dart test test/plugins/plugin_gate/plugin_gate_test.dart test/cli/zfa_executable_test.dart` | PASS ×35 | `All tests passed!` (9 gate incl. U7a–U7d + 26 executable incl. U12a–U12e) |
| 4 | GREEN e2e A1+A2 | `dart test test/graphql/graphql_generate_delegation_e2e_test.dart` | PASS | `00:16 +1: All tests passed!` — real `dart pub get` wrote a RELATIVE rootUri (asserted), `zfa graphql generate` completed (`✅ Generated`, files in `lib/graphql_generated`), artifact in the fixture's `.dart_tool/zfa_cli_bin/`, companion package `.dart_tool` unchanged |
| 5 | Analyzer, touched files | `dart analyze <6 touched files>` | PASS | `No issues found!` |
| 6 | Mutation M1 (§1) | revert `_resolvePackageRoot` to `Directory(path).absolute.path` (pre-fix code), run U7 pins | KILLED | U7a/U7b fail (null for relative rootUri) |
| 7 | Mutation M2 (§2) | drop `--packages=` from the compile argv, run U12a | KILLED | U12a fails: argv missing the flag |
| 8 | Mutation M3 (§2) | key the slot by candidate only, run U12c | KILLED | U12c fails: both projects share one slot |
| 9 | Mutation M4 (§2) | drop the package config from `_isStale` inputs, run U12d | KILLED | U12d fails: stale artifact reused |
| 10 | Regression — cli suite | `dart test test/cli/` | PASS ×281 | `All tests passed!` (incl. #1664 reuse probe, staleness, no-JIT contract) |
| 11 | Regression — gate + spawn sweep + graphql units | `dart test test/plugins/plugin_gate/ test/core/no_jit_zfa_spawn_scan_test.dart test/graphql/` | PASS ×168 | `All tests passed!` — the no-JIT spawn sweep certifies no new JIT path |
| 12 | Regression — graphql command suites | `dart test test/commands/graphql_diff_command_test.dart test/commands/exit_code_sweep_1139_test.dart test/commands/graphql_introspect_command_test.dart test/commands/graphql_pull_command_test.dart` | PASS ×15 | `All tests passed!` |
| 13 | Format gate | `dart format .` | PASS | `Formatted 2943 files (0 changed)` |

## Mutation summary

4/4 sampled mutants killed (M1–M4 above), restoration verified (working
tree restored after each mutant; final `git diff --stat` shows only the
six intended files). One additional defect was caught during the cycle
by the flow-level pin A2: the first cache-dir anchor joined
`kZfaBinaryCacheDir` onto `.dart_tool` producing
`<project>/.dart_tool/.dart_tool/zfa_cli_bin` — A2 failed, the anchor
was corrected to the project root, and U12b was tightened to the exact
`<project>/.dart_tool/zfa_cli_bin/` path.

## Success criteria (issue constraints) — PROVED

1. relative rootUris resolve with a regression pin — PROVED (U7a/U7b green; M1 killed; e2e A1 asserts pub's relative rootUri end-to-end)
2. hosted companions compile against the project's package config with per-project keying — PROVED (U12a–U12d green; M2/M3/M4 killed; e2e A2 asserts the project cache)
3. absolute/`file://` rootUri resolution unbroken — PROVED (U7c green pre- and post-fix)
4. shared pub cache untouched during hosted compile — PROVED (U12b + e2e A2: no artifact, no `.dart_tool`, no `pubspec.lock` written into the companion root)

Not covered by a pin: a REAL pub-cache-hosted companion install
(network install into `~/.pub-cache`) — the sandbox pins the same seam
through the in-repo companion with a genuine pub-written package config;
the seam code paths are identical (`packagesFile` threading →
`--packages=` → project cache).
