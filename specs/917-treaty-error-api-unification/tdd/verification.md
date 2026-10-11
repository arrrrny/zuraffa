# TDD Verification — feature `917-treaty-error-api-unification`

Generated fresh by `zfa tdd verify --feature 917-treaty-error-api-unification`,
then extended with the branch's REAL red→green evidence. Every count
below comes from an actual `dart test` / `dart analyze` / live
`zfa` invocation run on this branch (`spec/917-treaty-error-api-unification`,
base master @ `c7cf331a`); nothing is inferred.

## Gate

- gate: `not_assessed`
- not_assessed_reason: no behavior artifacts registered

## Mutation buckets (FR-014)

- killed: 0
- survived: 0
- timed_out: 0

## Behavior scope (FR-018)

- (no behavior artifacts in scope)

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 0

## Repro diagnostics (FR-020, non-sensitive)

## Mutation run

- mutation_was_run: false

The deterministic gate reports its honest state: this repo-level
framework spec carries no `tdd/artifacts.json` behavior registry, so
the mutation audit applies to nothing (the same `not_assessed` state
spec 1005, 1002 and 1102 recorded). The gate is `not_assessed`, not a
fabricated score. (The first gate run failed the receipt preflight on
stale `.zfa/receipts/` entries left by full-suite runs pointing at
deleted `/tmp/zfa_plugin_mcp_test_*` fixtures — `.zfa/` is gitignored
local state; cleared, then re-run, exactly as spec 1102 recorded.)

## 1. Root cause (TDD step 1)

Read issue #917 (absorbing #776/#778/#838/#839), the #904 drift
evidence, #876, and the live tree. The gap, verified before any
implementation:

- No `manifest --verify` conformance gate existed: nothing compared
  manifest `inputSchemas` ↔ the flags commands actually parse ↔ the
  help text they print. The #904 sites were live
  (`feature scaffold --use-mock` manifest-declared but the parser knew
  only `--mock`; `outputDir` declared but hardcoded/ignored; shadcn
  `ui.schema.export --project-root/--schema-version` unaccepted;
  benchmark `--scenario-ids` vs parsed `--scenario`; slice
  `--project-root` ×4 and `--confirm-all` vs parsed `--project`/
  `--yes`), and #876's silent parent-option inertness had no
  reproducer. A dead-flag leg existed in an earlier form (spec 979)
  but false-positived on every hand-rolled command and exited 1, not 3.
- 75 literal `64` exit sites across 29 lib files; the runner's
  `UsageException` path exited 64; benchmark shadowed its `exitCode`
  field with raw `exit(64)`/`exit(1)`; nothing asserted the ratified
  0/1/2/3/4 table anywhere; `255`/`-9` had no documented home.
- `--json` on 26 of 30 tdd verbs only (run-engine/split/status/theater
  lacked it) and on none of the four top-level corpus subcommands;
  `--stream` did not exist; the runner's catch-all error path printed
  no `--> fix:` line.

## 2. RED (step 2 — reproduced before any implementation)

Three test files were written FIRST and failed against the pristine
behavior (the implementation landed only after the failures were
observed):

- `test/commands/exit_protocol_golden_test.dart` — pins the golden
  table (constants, live-CLI usage exits, the top-level help EXIT
  CODES section, the fix-line contract).
- `test/commands/manifest_verify_gate_test.dart` — pins the four gate
  legs on #904 seed fixtures (schema-flag drift → 3, help-text drift
  → 3, dead-flag scoping, unknown plugin id → 2, `manifest-verify.v1`
  JSON shape, live-repo green).
- `test/commands/tdd_json_stream_test.dart` — pins `--json` on the
  four laggard tdd verbs + the four corpus subcommands and the
  `step-verdict.v1` NDJSON per-step stream terminated by the final
  `verdict.v1` envelope.

## 3. GREEN (step 3 — implementation + passing runs)

Final state of this branch (all runs below executed in this session):

- **The three spec suites + the migrated #1044 pin**:
  `dart test test/commands/exit_protocol_golden_test.dart
  test/commands/manifest_verify_gate_test.dart
  test/commands/tdd_json_stream_test.dart
  test/plugins/tdd/bug_1044_verify_runner_test.dart`
  → `00:01 +31: All tests passed!`
- **`lib/` is protocol-clean**: `grep -rn "exitCode = 64\|_exit(64)\|
  exit(64)\|exitCode: 64" lib/` → **0 hits** (75 legacy sites migrated
  to `ExitProtocol` codes; `grep -rln ExitProtocol lib/` → 35 files).
- **Live gate (this repo, real run)**:
  `dart run bin/zfa.dart manifest --verify` →
  `manifest verify: 61 capability route(s) certified, 0 drift
  finding(s), 24 unverifiable flag surface(s)`, **exit 0**; the JSON
  envelope decodes to `ok: true, exit_code: 0, certified: 61,
  findings: 0, unverifiable: 24` under `schema:
  manifest-verify.v1`. Unverifiable surfaces (permissive parsers with
  no declared `CliFlagSurface`) are reported per-flag with a fix
  line — honestly counted, never scored as drift.
- **#904 seed sites certify green**: `zfa feature scaffold --help`
  now documents `--use-mock  Alias of --mock (the manifest
  inputSchema property name)` (live output above); the
  scaffold/json-mock `outputDir` declarations agree with the CLI (0
  drift findings); the gate-fixture tests reproduce the drift → exit 3
  behavior on mutated fixtures.
- **Golden table printed by the top-level help**: live `zfa` (no
  args) prints the `EXIT CODES (the ratified protocol, SPEC 917 /
  VISION §4)` section with all five rows — asserted by the golden
  test via the runner and enforced in CI by the workflow.
- **Machine verdicts live**: `zfa corpus catalog --json --project .`
  closes with a `verdict.v1` envelope (`schema`, `command`, `verdict`,
  `exit_class`, `fix`, `drifts`, …); `zfa tdd run-engine` with a
  missing feature ends in the usage grammar + `--> fix:` line.

## 4. Full-suite verification (the honest tally, chunked)

`tools/run_tests_chunked.sh` runs the fast suite one folder at a
time (kernel-cache bounded; `--preset=all` deliberately excluded per
the dart_test.yaml policy). Two findings from running it for this
verification, both fixed on this branch:

1. **Silent coverage hole (found and fixed here).** `emit_chunks`
   dropped any directory heavier than THRESHOLD=40 whose subdirectories
   carry no test files — which silently skipped **`test/commands`
   (62 files)** and **`test/regression` (59 files)** from every
   previous run of the tool, including this repo's own CI usage. The
   fix emits the directory itself when the recursion yields no
   test-bearing chunk; the chunk list grew 89 → 93 and every
   top-level `test/` directory with test files is now provably
   covered. Because of that hole, 31 legacy-exit-64 test pins in
   `test/commands` had escaped the #1044-style migration — they were
   migrated to `ExitProtocol.usage` in this branch and now pass.
2. **One environmental flake (ENOSPC).** A mid-run chunk died with
   `OS Error: No space left on device, errno = 28` (concurrent kernel
   caches filled the disk); after cleanup the identical chunk
   re-ran green. Recorded here because hiding it would be a lie.

Per-chunk results (each a real `dart test <dir> --exclude-tags
flutter < /dev/null` invocation, kernel caches cleaned between
chunks):

| chunk(s) | result |
|---|---|
| ranges 1–12, 13–24, 25–36, 37–48, 49–60 | `RANGE_OK` — every chunk `All tests passed!` |
| `test/plugins/tdd` (whole tree, incl. commands/services/theater) | `03:24 +1430: All tests passed!` |
| ranges 61–72, 73–85 (through `test/zap`) | `RANGE_OK` — every chunk `All tests passed!` |
| `test/commands` (previously skipped dir) | `03:11 +269: All tests passed!` |
| `test/regression` (previously skipped dir) | `00:05 +15: All tests passed!` |
| re-run after the final lib lint pass (provider, mock, feature, slice, shadcn, benchmark) | `00:35 +353: All tests passed!` |

One failure existed in the first `test/plugins/tdd` run
(`bug_1044_verify_runner_test` pinning legacy 64 against the now-
canonical 2) — migrated, re-run green. No other red anywhere in the
fast suite.

## 5. Static analysis

- `dart analyze` (final): **138 issues = 31 errors + 107 infos**,
  where the 31 errors are ALL in `examples/todo_tdd/` — the
  Flutter-dependent example package whose generated sources don't
  exist in a pure-Dart checkout; `git diff master --name-only |
  grep examples/` → **0** (pre-existing on master, untouched by this
  branch).
- **Zero analyze findings in every file this branch changes** (the
  four lint infos our gate work introduced in
  `lib/src/commands/manifest_command.dart` were cleaned;
  `dart analyze lib/src/commands/manifest_command.dart` → `No issues
  found!`).
- `dart format lib/ test/ tool/ bin/` → `Formatted 2220 files
  (0 changed)` — idempotent, zero format drift.

## 6. CI gate

`.github/workflows/conformance.yml` runs on every push/PR to master:
live `manifest --verify` (text + `manifest-verify.v1` JSON with
`ok:true`/`exit_code:0` grep assertions), the golden-table test, the
gate-fixture tests, and the machine-verdict tests. Three defects
found and fixed while verifying it: the `branches:` selectors were
corrupted (`aster]` — unparseable YAML), `dart analyze --fatal-infos`
would fail on the 107 pre-existing master infos, and `--preset=all`
violated the repo's own dart_test.yaml small-agent policy.

## 7. Success criteria — proved vs not

**Proved (real runs above):** the four treaty legs on live + fixture
paths with drift = 3; 0 drift on the live repo with the #904 seed
sites fixed; zero literal-64 exits in `lib/`; the golden table
asserted against the live CLI and printed by top-level help; `--json`
envelopes on every tdd verb and the four corpus subcommands;
`--stream` NDJSON per-step verdicts terminated by the final envelope;
`--> fix:` lines on the usage and catch-all error paths; full-suite
green including the two previously-skipped directories.

**Not proved (recorded honestly):** mutation-audit scores — the gate
is `not_assessed` because this spec registers no behavior artifacts;
the `flag-surface-unverifiable` findings (24) remain reported-not-
certified until each permissive dispatcher declares its honest
`CliFlagSurface`; byte-identical flag-absent output is asserted by
the suite's legacy-behavior pins, not by a full-output diff of every
verb.

## 8. Reproduction

```bash
dart test test/commands/exit_protocol_golden_test.dart \
          test/commands/manifest_verify_gate_test.dart \
          test/commands/tdd_json_stream_test.dart
dart run bin/zfa.dart manifest --verify --format json
dart run bin/zfa.dart tdd verify --feature 917-treaty-error-api-unification
tools/run_tests_chunked.sh
```
