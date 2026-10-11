# TDD Verification — Bug 1719 (provider create: `--force`/`--revert` no-ops + duplicate members)

- **Bug:** `1719-provider-force-revert-duplicate-members` — GitHub issue #1719
  (provider create: `--force`/`--revert` flags are no-ops and the generated
  provider has duplicate members when the service has `--init` + appended
  methods; severity high).
- **Generated:** FRESH from the actual run in this session (2026-09-19) —
  not a copy of a prior verification.
- **Command path:** `/speckit.tdd.verify` semantics against the bug branch
  `fix/1719-provider-force-revert-duplicate-members`. spec-kit `specify` CLI
  v1.0.9.dev0 installed and checked (`specify --version`, `specify check`);
  `specify init --here --integration zed --ignore-agent-tools` completed
  (the repo's committed `.specify/` matched); the repo's
  `.specify/extensions.yml` already carries **TDD Extension v1.1.2**
  (`specify extension list` → `✓ TDD Extension (v1.1.2) … Status: Enabled`;
  the upstream `specify extension add tdd` release asset 404s —
  catalog-gated — and the installed registration was left untouched per the
  do-not-clobber rule for `.specify/`).
- **Deterministic gate:** `zfa tdd verify --feature
  1719-provider-force-revert-duplicate-members` WAS actually run. Verdict
  (verbatim): gate `not_assessed` — `no behavior artifacts registered`,
  `mutation_was_run: false`, `restoration_verified: true`, exit 2. Reason:
  the spec-flow mutation audit scopes from `specs/<feature>/tdd/artifacts.json`
  (produced by the `/speckit.tdd.plan` feature flow); a BUG carries its
  records under `.specify/bugs/<slug>/tdd/` and registers no mutation
  behaviors, so the mutation bucket is not assessable for this bug shape.
  The auto-created `specs/<bug-slug>/` stub was removed after the run
  (untracked session debris; the spec corpus scans `specs/` for features).
  Mutation-strength evidence for this fix is carried by the discriminating
  regression suite instead (B1–B6 fail on the unfixed tree, pass on the
  fixed tree — see the red log).

## Verdict: **PASSED**

| Gate | Result |
|------|--------|
| RED (repro before fix) | ✅ `tdd/red-T001-bug1719.log` — **0 passed / 6 failed** with the exact defect signatures: `--force` → action `skipped` (expected `overwritten`), `--revert` → `skipped` (expected `deleted`), duplicate member counts for `isInitialized`/`initialize`/`dispose`. Decisive lines quoted in §1; the raw log is retained in-session (the repo gitignores `*.log`) |
| GREEN (after fix) | ✅ `tdd/green-T001-bug1719.log` — **`+6: All tests passed!`** (6/6 regression tests, exit 0; raw log retained in-session per the repo's `*.log` gitignore) |
| Live repro of the issue's exact commands | ✅ scratch fixture (`service create Auth … --init` → provider create `--init` → re-runs): `--force` → `📝 <provider>` (overwritten, exit 0, was `⏭ Skipped (use --force to overwrite)`); `--revert` → `🗑 <provider>` (deleted, exit 0); `service create … --force` → `📝 <service>` + conformance pass (was `⚠️ No files were generated`); `service create --revert` → `✅ Reverted (deleted):` |
| Generated provider compiles | ✅ `dart analyze lib/src` on the scratch fixture: **No issues found!** (was: 3 × `duplicate_definition` errors — `isInitialized`, `initialize`, `dispose`) |
| `dart analyze` (changed files) | ✅ the 5 lib files + the new test file: **No issues found!** |
| Regression scope (direct suites) | ✅ `dart test test/plugins/provider test/plugins/service test/fixes --exclude-tags "flutter \|\| e2e"` → **93 passed / 0 failed**; `dart test test/commands …` → **306 passed / 0 failed** |
| Full fast suite (disk-safe chunked runner) | ✅ `tools/run_tests_chunked.sh` via `tools/run_chunks_range.sh` passes (kernel caches cleared per chunk): **104 chunks passed, 5092 tests passed, 0 failures from this change**; 3 chunks SKIP (`no fast-tier tests`: test/benchmark, test/integration, test/plugins/tdd/scenarios); 1 flagged unrelated pre-existing failure (below) |
| `dart format .` | ✅ `Formatted 2991 files (0 changed)` on the second run — the only file the formatter touched was the NEW test file (now committed formatted); zero remaining diffs |
| Dry-run regression repair (same root cause) | ✅ `zfa provider create X --dry-run` no longer writes the file (the fresh-file write read `options.dryRun` instead of `config.dryRun`; repaired on the same call) |

## 1. Red → green cycle log

- **T001 (red):** `tdd/red-T001-bug1719.log` — with the fix absent,
  `dart test test/fixes/bug_1719_provider_force_revert_duplicate_members_test.dart`:
  `+0 -6: Some tests failed.` All six behaviors fail with the issue's own
  signatures (B1/B2/B5/B6: `skipped` instead of `overwritten`/`deleted`;
  B3/B4: signature-mangled + duplicated members). Raw log retained
  in-session (repo gitignores `*.log`).
- **T001 (green):** `tdd/green-T001-bug1719.log` — with the fix applied,
  same command: `+6: All tests passed!` (exit 0). Raw log retained
  in-session.
- **Refactor:** none required — the fix is flag-plumbing + member-emission
  shape in the existing builders; `dart format` reports zero diffs after
  the fix.

## 2. The fix (what changed)

1. `lib/src/plugins/provider/builders/provider_builder.dart` — (a) the
   fresh-file write reads the PER-INVOCATION flags
   (`force: config.force, dryRun: config.dryRun, verbose: config.verbose`)
   instead of the plugin-level const `GeneratorOptions` — this is the
   `--force` no-op root cause (and the `--dry-run` writes-files leak);
   (b) interface extraction emits signature-faithful members via
   `_buildImplementationMember(ParsedUseCaseInfo)` — getters stay getters,
   `parameterCount == 0` members stay parameter-less (reuses the #1570
   metadata the builder previously ignored); (c) the `--init` members are
   built once (`_buildInitMembers()`), their names collected, and
   interface-extracted members with the same names skipped — exactly one
   implementation member per interface member.
2. `lib/src/plugins/provider/capabilities/create_provider_capability.dart`
   — forwards `args['revert']` into `GeneratorConfig(revert: …)` (the
   CLI-level `--revert` never reached the builder's delete path); the
   service-existence precondition now guards creation only
   (`generateData && !revert`) so `--revert` cleanup is not blocked.
3. `lib/src/plugins/service/service_plugin.dart` — interface write reads
   `config.force`/`config.dryRun`/`config.verbose` (the D3 root cause on
   the service side).
4. `lib/src/plugins/service/capabilities/create_service_capability.dart`
   — forwards `args['revert']`.
5. `lib/src/commands/service_create_command.dart` — declares the
   `--revert` flag, passes it through, and surfaces `deleted` actions as a
   first-class success (prose `✅ Reverted (deleted):` / JSON `pass`
   verdict) instead of the zero-files refusal.

Provider INTERFACE emission (`ServiceInterfaceBuilder`) is untouched;
append/inject keeps its `force: true` semantics; fresh-create shapes are
unchanged apart from the corrected getter / parameter-less member shapes.

## 3. Success criteria — PROVED vs not

| Criterion | Status |
|-----------|--------|
| `--force` actually overwrites (provider AND service create) | **PROVED** (B1, B5 green; live CLI `📝` exit 0) |
| `--revert` deletes without requiring `--force` (provider AND service create) | **PROVED** (B2, B6 green; live CLI `🗑` exit 0) |
| Exactly one implementation member per interface member | **PROVED** (B3/B4: one `isInitialized`, one `initialize(`, one `dispose(` in the emitted class) |
| Interface signatures matched (`get isInitialized` getter, `initialize(InitializationParams)`, parameter-less `dispose()`) | **PROVED** (B3/B4 assertions + scratch fixture `dart analyze` clean — `duplicate_definition` gone) |
| `zfa service create --force` overwrites existing files | **PROVED** (B5 green; live CLI `📝` + conformance pass) |
| Provider interface emission unchanged | **PROVED** (no changes to `ServiceInterfaceBuilder`; provider/service suites green) |
| Minimal fix with tests (red → green) | **PROVED** (5 lib files, 1 test file, RED log → GREEN log) |
| `tdd/verification.md` (REAL) | **PROVED** (this file, generated from the actual run — red/green decisive output quoted verbatim in §1) |

## 4. Environment notes (honest disclosure)

- Toolchain: Dart SDK 3.13.4 stable (linux x64); no Flutter SDK in the
  sandbox — flutter-tagged tests are excluded by the repo's own convention
  (`--exclude-tags "flutter || e2e"`, per dart_test.yaml). The `example/`
  subpackage is Flutter-only and untouched.
- The sandbox has a ~10 GB disk and reaps background processes, so the full
  fast suite ran through the repo's own disk-safe chunked runner
  (`tools/run_tests_chunked.sh` / `run_chunks_range.sh`) in foreground
  passes with kernel-cache cleanup per chunk — the same convention the
  #1185 verification records. One chunk failed: `test/cli` —
  `bug_1360_undeclared_option_crash_test.dart` B1. **Verified pre-existing**
  with `git stash` (fails identically on the unfixed tree; asserts
  `--world` usage-error wording on the simulate walk, unrelated to
  provider/service create). Per-chunk logs retained in the session under
  `tmp_kernel/`.
- `zfa tdd verify`'s receipt preflight initially reported 6 findings for
  `.zfa/receipts/mcp-scaffold-scaffold-*.json` — receipts written THIS
  SESSION by the MCP scaffold tests themselves (gitignored; artifacts are
  the tests' own temp fixtures, deleted by their tearDown). Removed as
  session debris per the gate's own `--> fix:` line, after which the
  preflight reported `skipped (no receipts shipped)` and the mutation audit
  ran to its `not_assessed` verdict (documented above).
- The deterministic mutation gate's `not_assessed` verdict is reported
  verbatim per the `/speckit.tdd.verify` contract (exit 2 = grammar/contract
  drift: the bug flow registers no behavior artifacts). No remediation
  tasks are appended — the mutation phase is not runnable for this bug
  shape without fabricating a feature-flow `artifacts.json`, which the
  one-PR-per-bug constraint forbids.
