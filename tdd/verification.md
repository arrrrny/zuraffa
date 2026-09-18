# tdd.verify — EPIC 3 (#1134): Presentation — contracted views + adaptive layouts + coverage ledger

- **Verified**: 2026-09-18, this session, on
  `feat/1134-presentation-contracted-views` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart
  3.13+" floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: 4 lanes (one commit each) —
  `f0e49911` (lane 1, adaptive layout contract),
  `03472077` (lane 2, view pipeline cleanup),
  `118a8a79` (lane 3, typed UI coverage ledger),
  `26ab2fe0` (lane 4, shadcn vocabulary gate) — plus the format pass
  and the e2e evidence script.

## Verdict: PASS

All three epic exit criteria PROVED by real CLI runs
(`scripts/e2e_1134_exit_criteria.sh`, this session: **PASS=20 FAIL=0**);
every new behavior observed RED for the missing-behavior reason before
its lane's code landed, and GREEN after; all touched suites green;
`dart analyze` clean on every changed file; `dart format .` reports
0 changed.

## 1. TDD discipline (red → green → verify)

The 23 behaviors of `tdd/test-list.md` were pinned BEFORE
implementation. Per lane, the red set was observed failing for the
missing-behavior reason (never a setup error), then going green on the
lane's code. Verbatim red evidence from this session:

- **Lane 1** (adaptive layout contract):
  `dart test test/plugins/tdd/services/platform_layout_contract_1134_test.dart`
  → *"Error: Member not found: 'PlatformLayoutContract.resolve'"*
  (5×) — the API did not exist; and
  `view_command_skin_contract_slots_test.dart` U-1134-a4 failed with
  the command's own output showing
  *"layouts: no platform slots declared — single-layout view"*
  (the Skin Contract fallback did not exist) while U-1134-a6 saw
  `Expected: <1> Actual: <0>` (the malformed-contract refusal did not
  exist). Green after `f0e49911`: 8/8.
- **Lane 2** (view pipeline cleanup):
  `view_generation_contract_test.dart` → *"Error when reading
  'lib/src/tdd/services/view_generation_contract.dart': No such file
  or directory"* — the shared seam did not exist; the command-level
  run captured the pre-port output
  (`'✅ Success! Created/Modified:\n'` — no machine summary line, no
  already-implemented verdict). Green after `03472077`: 8/8.
- **Lane 3** (typed UI coverage ledger): 22 load errors across the
  four new suites (*"Failed to load … typed_ledger_projection_test /
  typed_platform_ledger_test / xray_platform_heatmap_1134_test"* —
  the modules did not exist) and
  `plan_typed_ledger_1134_test.dart` 0/3. Green after `118a8a79`:
  11/11.
- **Lane 4** (vocabulary gate): 17 load errors
  (*"Failed to load … widget_vocabulary_gate_test /
  skin_builder_layout_refusal_test / plan_vocabulary_gate_1134_test /
  view_vocabulary_gate_test"* — the gate module and refusals did not
  exist). Green after `26ab2fe0`: 14/14.

One guard pin was updated deliberately (documented in the lane-3
commit): `bug_1141_login_ui_regeneration_test` pinned the old
single-layout shape for a contract-only fixture; lane 1's
contract-driven generation (the epic's intent) emits the 4-slot
AdaptiveViewState skeleton there — the test now excludes the generator
TODO seam markers from its zero-hardcoded-strings criterion (exactly
like the audit's `markerLiterals`) and ADDITIONALLY pins the
contract-driven 4-slot skeleton (`W1ViewMobileLayout` …
`W1ViewMacosLayout`).

## 2. Exit criteria (epic #1134) — PROVED by real runs

`bash scripts/e2e_1134_exit_criteria.sh` drives the REAL CLI
(`dart run bin/zfa.dart …`) against hermetic temp projects. This
session's run: **PASS=20 FAIL=0**.

**EC-1 — 004-login-ui: mobile + macOS layout slots in the same
generated output.** `zfa tdd view W9` on a 004-login-ui fixture whose
Presentation contract declares `adaptive_layouts: mobile, macos`
(the example corpus's declaration) scaffolded a subject carrying
`class W9ViewMobileLayout` + `class W9ViewMacosLayout` + the slot keys
`Key('w9-slot-mobile')` / `Key('w9-slot-macos')` + `_resolveSlot` —
5/5 checks PASS. (Contract-driven generation — a feature with a
`## Skin Contract` and no Presentation bullet — is additionally proved
by U-1134-a4: the contract's slots drive the same skeleton.)

**EC-2 — XRay overlay shows a per-layout kind-coverage heatmap.**
`zfa tdd plan` on a five-kind fixture declaring
`adaptive_layouts: mobile, macos` wrote
`tdd/typed-ledger.md` with the `## Per-layout kind coverage heatmap`
section (kind × slot grid, all five kinds) and `typed-ledger.json`
carrying `"status":"untraced"` (the plan-time inventory); the XRay
overlay binding (real invocation over the plan's own JSON) rendered:

```
xray: per-layout kind coverage (macos, mobile)
macos HIGHLIGHT presence 0/4
mobile HIGHLIGHT presence 0/4
macos HIGHLIGHT absence 0/1
...
deck: mobile presence 0/4 [untraced]
```

8/8 checks PASS — kind coverage per layout, HIGHLIGHT on zero-traced
cells, deck badges per (slot, kind).

**EC-3 — no view generator emits unchecked grid/table layout code.**
Three live refusals: `zfa tdd plan` on `ShadGrid`/`table` Presentation
tokens exits 2 writing NO artifacts (naming both tokens, grid/table as
not implemented, and the `zfa ui schema` fix); `zfa tdd view` on the
same tokens exits 1 with the subject byte-untouched; `SkinBuilder`
with `layout: grid` refuses BY NAME ("not implemented — the
implemented layouts are `list` and `form`") and generates 0 files (the
silent list fall-through is gone). 7/7 checks PASS.

## 3. Verification runs (this session, actual counts)

New/changed suites (the 23 behaviors + the updated guard pin):

```
dart test <the 13 changed/new suites>  → 00:22 +44: All tests passed!
```

Guard pins (chunked per the repo's cloud-agent protocol —
`dart_test.yaml`'s kernel-cache guidance; kernel cache cleared between
chunks):

| suite | result |
| --- | --- |
| test/plugins/tdd/commands/ | 564 passed |
| test/plugins/tdd/services/ | 1168 passed |
| test/skin/ + test/plugins/skin/ | 160 passed |
| test/commands/ | 390 passed |
| test/tdd/ (corpus, chunked; 077 is slow-tier-excluded) | 160 passed |
| test/tdd/{0966,1334,075} ledger libraries | 38 passed |
| test/plugins/view/ | 22 passed (view_compile_test excluded: needs the Flutter SDK — pre-existing env gap, untouched by this epic) |

Static analysis + formatting:

```
dart analyze <9 changed lib files + 13 changed test files>
  → No issues found!
dart format .
  → Formatted 2959 files (0 changed)
```

Pre-existing failures flagged (NOT from this epic):
`test/plugins/view/view_compile_test.dart` requires the Flutter SDK
(`flutter pub get` — not installed in this cloud agent); it fails at
setUpAll on master too.

## 4. The /speckit.tdd.verify audit

Step 0 (engine detection): `zfa --version` resolves (the repo IS the
engine) but no `.zfa.json` exists at the repo root → the extension's
documented fallback to the LLM-guided audit. Step 2 dispatch attempt
(`zfa tdd verify --feature 1134-presentation-contracted-views`), after
clearing this session's untracked test-run receipt residue under
`.zfa/receipts/` (gitignored; receipts persisted by capability-wrapper
test runs against deleted tmp fixtures — not repo state):

```
receipt preflight: skipped (no receipts shipped — proof-carrying generation not in use)
zfa tdd verify: running mutation audit...
   feature: 1134-presentation-contracted-views
   gate: not_assessed
   reason: no behavior artifacts registered
   killed: 0  survived: 0
```

The deterministic mutation audit is `not_assessed` for the honest
reason it names: this epic's subject is the CLI itself — the behaviors
are proven by the repo's `test/` suites (the 1769-test guard runs
above) and the e2e script's exit-coded CLI checks, not by a
`specs/<feature>` behavior corpus with `lib/tdd` subjects. The
LLM-guided fallback audit this file records: red→green per lane
(§1), the exit criteria (§2), and the full green runs (§3) — every
number above is from a real run in this session.

## 5. Determinism spot-checks

- The tdd view machine line is byte-stable across re-runs
  (`view: behavior=W9 outcome=scaffolded feature=004-login-ui`).
- The mainline machine line renders deterministically
  (`view: entity=Login outcome=scaffolded|already-implemented|error
  files=<n>` — U-1134-v2/v4 pin the exact bytes).
- Plan artifacts are byte-stable across re-runs of the same spec
  (no timestamps ride the ledger writes).
