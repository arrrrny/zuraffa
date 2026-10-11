# TDD Verification — SPEC 1106: close residual `--json` gaps on verify-gate commands

Feature: `1106-verify-json-gaps` (branch `spec/1106-verify-json-gaps`)
Scope: `zfa di verify --json`, `zfa datasource check --json`, and the
codebase-wide sweep proving no verify-gate command lacks `--json`.
Toolchain: Dart 3.13.3 (stable), package:test. Every number below comes
from an actual run on this branch (or, where stated, on a stashed
pristine-master checkout of the same clone); nothing is projected or
assumed.

## 1. Root cause (TDD step 1)

- `zfa di verify` was auto-registered as a `CapabilityCommand`, whose
  ctor owns `--json` as a JSON-**input** *option*
  (`capability_command.dart:30`). Bare `--json` therefore failed arg
  parsing ("Missing argument"), and even a valued call emitted no
  machine verdict: DI verify's `toData()` carried no `verdict` key, so
  the #978 machine branch (`capability_command.dart:291-302`) never
  fired. Human output was `--> fix:` prose + exit code only.
- `zfa datasource check` (spec #977 parity gate) had **no argParser at
  all** — no `--json`, no envelope.
- The repo's own precedent for this exact collision is documented in
  `cache_verify_command.dart:18-21`: register the gate manually via the
  `manualSubcommandNames` hook (issue #761) so `--json` can select JSON
  *output*. `route verify`, `cache verify` and `provider verify` all
  took that seam; `di verify` predates it and never migrated.
- The canonical envelope is `verdict.v1`
  (`lib/src/plugins/tdd/models/verdict_envelope.dart`; machine contract
  `zfa tdd verdicts --schema` + `bug_969_json_verdict_envelope_test.dart`).
  The literal string `zuraffa.verdict.v1` (issue #1106's shorthand for
  "the zuraffa canonical verdict envelope") exists nowhere in the repo,
  and the referenced #1104 (json-envelope-audit) carries no envelope
  definition — the in-repo `verdict.v1` treaty IS the canonical
  envelope, so this spec extends it rather than forking the schema name
  (forking would break `zfa tdd verdicts --schema` and the #969
  treaty tests).

## 2. RED evidence (before implementation)

### CLI (2026-09-05, unmodified master @ `512a818`)

```text
$ zfa di verify --json
❌ Missing argument for "--json".          # flag exists as JSON-input only

$ zfa datasource check --json Product
❌ Could not find an option named "--json". # no flag at all
```

### Failing-first tests (written before implementation)

- `test/plugins/di/di_verify_test.dart` — new SPEC 1106 group:
  **RED-by-compile** (`Error: Method not found: 'DiVerifyCommand'`).
- `test/plugins/datasource/datasource_check_command_test.dart` — new
  SPEC 1106 group: **+8 / −5** (all 5 new envelope tests failed: no
  `--json` flag to pass).
- `test/commands/verify_gate_json_sweep_test.dart` — new: **−4** (the
  sweep could not find `di_verify_command.dart`;
  `datasource_check_command.dart` referenced no `'json'`; both live
  spot-checks failed to dispatch bare `--json`).

## 3. GREEN evidence (after implementation)

- `dart test test/plugins/di/di_verify_test.dart` → **+10: All tests
  passed!** (5 pre-existing capability tests untouched + 5 new envelope
  tests: exact key set `{schema, command, verdict, exit_class, subject,
  findings, drifts, details, timestamp}`, `schema == 'verdict.v1'`,
  `command == 'di verify'`, verdict/exit_class pass/fail × ok/fail,
  `subject.kind == 'di'`, `findings[*]` keys exactly `{kind, file,
  member, fix}`, `details.danglingClasses[]` / `details.deadImports[]`,
  and the no-envelope prose path unchanged without `--json`.)
- `dart test test/plugins/datasource/datasource_check_command_test.dart`
  → **+14: All tests passed!** (9 pre-existing + 5 new envelope tests:
  parity pass envelope with `subject {kind: 'datasource', entity:
  'Product'}`; drift envelope with `findings[*].kind == 'missing
  interface method'` / `'undeclared override'`, `exit_class == 'drift'`;
  missing-interface envelope; `--json` usage refusal → `verdict:
  'error'`, `exit_class: 'insufficient-input'`, exit 64; prose path
  unchanged without `--json`.)
- `dart test test/commands/verify_gate_json_sweep_test.dart` → **+4:
  All tests passed!** (discovery inventory, per-file `--json` grep, and
  two live spot-checks dispatching bare `--json` through `CliRunner`
  and asserting the canonical envelope as the last stdout line.)
- Post-`dart format` re-run of all four spec-adjacent test files →
  **+34: All tests passed!**

### CLI (live, this branch)

```text
$ zfa di verify --json
{"schema":"verdict.v1","command":"di verify","verdict":"pass","exit_class":"ok",
 "subject":{"kind":"di","entity":"lib/src/di"},"findings":[],"drifts":[],
 "details":{"danglingClasses":[],"deadImports":[],"filesScanned":0,
 "bindingsChecked":0},"timestamp":"2026-09-05T08:11:11.367011Z"}   # exit 0

$ zfa datasource check --json          # no entity → usage refusal envelope
{"schema":"verdict.v1","command":"datasource check","verdict":"error",
 "exit_class":"insufficient-input","subject":{"kind":"datasource"},
 "drifts":[],"details":{"fix":"zfa datasource check <Entity>"},
 "timestamp":"2026-09-05T08:11:33.331663Z"}                        # exit 64
```

## 4. The sweep (deliverable, not a list)

Commands named by the issue and their `--json` status on this branch:

| Command | Status |
|---|---|
| `zfa di verify` | **repaired** (new manual command + envelope) |
| `zfa datasource check` | **repaired** (flag + envelope) |
| `zfa route verify` | already ships `--json` (schema-1 envelope) — untouched |
| `zfa cache verify` | already ships `--json` (`cache.verify.v1`) — untouched |
| `zfa provider verify` | already ships `--json` (schema-1) — untouched |
| `zfa slice verify` | already ships a JSON verdict via its input schema — untouched |
| `zfa tdd verify` / `verify-red` / `diff-check` / `doctor` / `referee` / `corpus audit` / `corpus differential` | already ship the canonical `verdict.v1` envelope — untouched |
| `zfa engine check`, `zfa proof check`, `zfa doctor` | already ship `--json` / `--format json` (non-canonical shapes, pre-existing; out of scope per "do not touch commands that already ship `--json`") |
| `zfa service verify` | **does not exist** (grep over `lib/` — nothing to repair) |
| `zfa xray deck` | not a verify-gate; the re-grade's complaint there is non-compiling Dart output, a separate defect from `--json` |

The greppable assertion lives at
`test/commands/verify_gate_json_sweep_test.dart`: it discovers every
`*verify*` command file under `lib/src/commands/` and
`lib/src/plugins/tdd/commands/`, pins `datasource_check_command.dart`
explicitly (its gate does not carry "verify" in the file name), requires
the discovered set to cover the known gate inventory, and requires every
discovered file to reference the `'json'` flag — a future verify gate
without `--json` fails this test on the exact file.

## 5. Envelope design decision (recorded)

`VerdictEnvelope` gained two OPTIONAL keys — `subject`
(`{kind, entity}`) and `findings` (`{kind, file, member, fix}` records)
— omitted from the JSON when null, so every tdd verb's emitted shape is
byte-identical (the #969 treaty key set was extended accordingly in
`bug_969_json_verdict_envelope_test.dart`; the verbs' assertions are
unchanged). `di verify` moved from capability auto-registration to a
manual subcommand (`ModularDiCommand.manualSubcommandNames = {'verify'}`)
reusing the same seam as cache/route/provider verify; the capability
itself stays registered (wiring test still asserts `plugin.capabilities`
contains `'verify'`) and the text-mode output is byte-identical to the
old `CapabilityCommand` path. Exit codes are unchanged everywhere
(0/1/64).

## 6. Full verification

- `dart analyze` → **333 issues / 33 errors — identical to the
  pre-change baseline** (all 33 pre-exist on master in
  `examples/todo_tdd/**` and `lib/src/domain/services/barcode_service.dart`;
  zero new issues introduced).
- `tools/run_tests_chunked.sh` chunk list executed to completion via a
  resumable driver with identical chunk semantics: **76 chunks OK**,
  4 SKIP (no fast-tier tests: `test/benchmark`, `test/core/dependencies`,
  `test/integration`, `test/plugins/tdd/scenarios`), **4 FAIL — all
  accounted for as pre-existing or flaky, none introduced here**:
  - `test/plugins/cache` (+44 −2): receipt-filename assertions
    (`cache-adapter` vs `cache adapter`) — **fails identically on a
    stashed pristine-master checkout** of this clone (reproduced before
    restoring the working tree).
  - `test/plugins/state` (+20 −1) and `test/plugins/usecase` (+39 −1):
    **fail identically on master** (same counts re-verified on the
    stashed checkout).
  - `test/tdd/073-slice-isolation`: recorded FAIL once inside the long
    chunked run, then **passed 3/3 consecutive isolated runs with this
    branch's changes** and passes on master — a known
    `Directory.current` race family (see master HEAD commit `512a818`,
    "cross-suite Directory.current race"), not a regression of this
    spec.
  - `test/plugins/tdd/bug_969_json_verdict_envelope_test.dart` →
    **+25 −3 before AND after the change** (the 3 failures are
    pre-existing master dispatch flakes, proven by the same stash
    procedure); `verdict_envelope_test.dart` → all pass.
- `dart format .` → 6 files canonicalized; `dart format
  --output=none --set-exit-if-changed .` → **exit 0** (zero remaining
  formatting diffs), and `git status` confirms only this spec's files
  changed.
