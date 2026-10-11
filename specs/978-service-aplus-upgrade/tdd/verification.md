# TDD Verification — 978-service-aplus-upgrade

**Date**: 2026-09-05
**Branch**: `spec/978-service-aplus-upgrade` (base: master @ 77e69f24)
**Toolchain**: Dart 3.13.2 (CI pin), spec-kit TDD extension v1.1.2
**Result**: **PASS** — all acceptance criteria proven by real runs; full fast
suite green (74/74 chunks, 0 failures); 4/4 targeted mutants killed.

## 1. Suite baseline (REAL run)

`tools/run_tests_chunked.sh` (the disk-safe fast-suite runner, the same
verification the spec mandates):

- 74 chunks enumerated; **74 executed green** — 61 chunks passed in the
  chunked run before the 10-minute tool timeout cut the process at chunk 66
  (`test/simulation`, mid-run), and the remaining 9 chunks (simulation,
  state, testing, utils, zap, tdd/072–075) were executed immediately after
  with the same `dart test <folder> --exclude-tags flutter` invocation.
- **Failures: 0. Analyzer-error tests: 0.** 4 chunks legitimately report
  `SKIP: no fast-tier tests` (benchmark/integration/property-only folders —
  excluded by `dart_test.yaml` by design).
- Total fast-tier tests passed: **2,919** (2,459 in the chunked log + 89 +
  371 from the nine post-timeout chunks).
- `dart analyze`: 31 errors / 20 warnings — **all pre-existing on pristine
  master** (verified via `git stash` + re-analyze: identical counts; all
  errors live in `examples/todo_tdd/`, generated example code that needs
  `build_runner`). Zero new analyzer findings in the four changed files.
- `dart format .`: 7 files reformatted on first run (the new tests + one
  restored source); **second run: 0 changed** — `git diff --stat` shows zero
  remaining formatting diffs.

## 2. Red → green (failing-first, per spec)

RED evidence was captured before any production change (see
`tdd/cycle-log.md` for verbatim failure output):

| order | behavior | red proof | green proof |
| --- | --- | --- | --- |
| 1 | no silent empty success | `Which: printed nothing` (2 tests) on the pristine plugin | `test/plugins/service/service_plugin_skip_verdict_test.dart` — 4/4 green; the decline now prints the skip reason + `--> fix:` and returns `[]`, keeping the CLI #769 zero-file guard armed |
| 2 | schema ≡ grammar | `configSchema does not advertise: {params, returns, type, init}`; `--init` unparseable; no `type` enum (4 tests red) | `service_schema_grammar_parity_test.dart` — 5/5 green, including the both-directions mini treaty and the `--init` end-to-end lifecycle check |
| 3 | make-triad e2e | service artifact was `abstract class ProductService {}` — a hollow interface on the flat path while the usecases imported the entity path and called `_service.toggle` (1 test red) | `make_service_triad_test.dart` — 2/2 green: entity-path interface with the get/update/toggle surface, provider implements it (methods extracted from the interface), `di/services/product_service_di.dart` registers the pair, proof.v1 receipt digest covers the service file, `zfa proof check --format=json` → `"ok":true` |
| 4 | method-append | coverage gap — no test existed; the new tests landed green on the unchanged code (recorded honestly: the bug was the missing test, not broken behavior) | `service_method_append_test.dart` — 2/2 green: hand-written members/doc comments preserved, new method appended, action `updated`, idempotent re-append, no `import augment` |
| 5 | --json verdict | `Actual: <null>` — no verdict object; error path had no `--> fix:` (3 tests red) | `service_create_json_verdict_test.dart` — 4/4 green: `{schema:1, ok, file, methods[], type}` envelope, flag/JSON merge, ok:false + `fix` + `--> fix:` + exit 64 on missing name, prose mode regression-guard |

New-test totals: **17 tests, all green** (5 files under `test/plugins/service/`,
all fast-tier — untagged, so the chunked runner proves them).

## 3. Mutation spot-check (REAL manual mutants, 4/4 killed)

Method: targeted manual mutants on the changed files (the same legacy
spot-check technique specs 041/075 use before machine mutation), each
applied to the GREEN code, run against its test file, then reverted:

| mutant | edit | killed by | evidence |
| --- | --- | --- | --- |
| A | silence the skip note (restore the silent decline) | skip-verdict test | `Which: printed nothing` → 2 tests fail |
| B | drop `init` from `configSchema` (schema drift) | parity test | `configSchema must advertise init` + treaty reports `{init}` drift → 2 tests fail |
| C | strip `verdict` from the create execute result | json verdict test | `Actual: <null>` on the success/merge tests (error-path still passes — its verdict comes from CapabilityCommand, not the capability) → 2 tests fail |
| D | drop the entity-methods default (hollow triad returns) | make-triad test | interface regresses to the empty shell → 1 test fails |

**Honest process note**: during the first mutation pass I reverted mutants
with `git checkout <file>`, which restored the pristine index version and
wiped my (then-unstaged) GREEN edits to `service_plugin.dart` and
`create_service_capability.dart`. Mutants A and C were clean kills on GREEN
code; B and D had accidentally become "GREEN-code-absent" kills (logically
equivalent signal, mechanically sloppy). I rewrote both files to the exact
GREEN content, re-verified the full service suite (25/25), then **re-ran
mutants B and D properly** with copy-based backup/restore (`cp` + asserted
`python` replace + `cp` restore) — both applied with verified pattern
matches and both killed. After restoration the service suite is 25/25
green and the repo diff is byte-identical to the pre-mutation GREEN state
(4 files, +226/−12).

## 4. Acceptance-criteria coverage matrix

| Criterion (spec 978) | Evidence | Status |
| --- | --- | --- |
| AC-1: Legacy config path never yields silent empty success — tested | skip-verdict test (plugin path + make-context path + no-regression guard); the empty return keeps CapabilityCommand's #769 guard armed (exit 1) | **VERIFIED** |
| AC-2: Schema/grammar parity test green | parity test: configSchema ⊇/⊆ grammar knobs, `--init` synthesized, type enum agreement, both-directions treaty | **VERIFIED** |
| AC-3: Make-pipeline test green (service + DI + provider verified by content) | make-triad test: interface members, provider `implements ProductService` with extracted methods, DI registration content, receipt digest, proof-check green | **VERIFIED** |
| AC-4: Append test green; --json envelope asserted | method-append tests (2/2) + json verdict tests (4/4, envelope decoded and field-by-field asserted) | **VERIFIED** |
| Hard constraint: triad activation logic in make untouched | `git diff` touches no make/plan_resolver file; the triad (usecase+service+provider via `--service`, from plan_resolver.dart) is *tested*, not rewired | **VERIFIED** |

## 5. Misfire-stop audit

- Every service decline path prints a `--> fix:` line (plugin skip note,
  CapabilityCommand missing-args path, machine-mode ok:false verdicts).
- `zfa service create --json '{}'` (missing name) exits 64 with
  `{"schema":1,"ok":false,...,"fix":"zfa service create --name <name>"}`
  and the `--> fix:` line — no `✅ Success` framing anywhere on error paths.
- Prose mode (no `--json`) is byte-for-byte unchanged behavior for every
  pre-existing test (regression guards green; MockCapability-based
  capability_command tests unaffected — the verdict hook is gated on
  machine mode + `data['verdict']`).

## 6. Honest limitations

- The mutation evidence is a 4-mutant targeted spot-check, not the full
  machine-generated audit (mutation-test.xml scopes machine mutation to the
  feature-041 TDD-plugin files; rewiring it for 978 is out of scope and the
  cloud disk budget forbids full-suite-per-mutant runs here).
- The `--json` verdict channel is exercised for the service create
  capability; other capabilities keep the prose path (by design — the hook
  is opt-in via `data['verdict']`).
- The make `--type` flag's allowed values are unioned across plugins at flag
  synthesis (usecase's enum wins registration order); the service-owned
  surfaces (command grammar, create subcommand, configSchema) are the ones
  under treaty here.
- Slow-tier suites (regression/integration/property/benchmark) were not run
  (excluded by design for cloud agents per `dart_test.yaml`); the fast tier
  — the suite the spec's chunked runner mandates — is fully green.
