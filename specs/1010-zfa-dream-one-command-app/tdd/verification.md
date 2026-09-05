# TDD Verification — feature `1010-zfa-dream-one-command-app`

Generated fresh by `zfa tdd verify --feature 1010-zfa-dream-one-command-app`.

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

---

# Delivery evidence (the honest fallback, per the 0806 precedent)

**Date**: 2026-09-05 · **Branch**: `spec/1010-zfa-dream-one-command-app` · **Dart**: 3.13.2 (stable, the CI-pinned version)
**Method**: test-first TDD via the tdd extension — every behavior below was written and observed RED before the implementation that turned it green. Evidence entries live in `tdd/cycle-log.md`.

The mutation audit derives its scope from the feature's pipeline-registered
behavior artifacts (`artifacts.json`); this feature's tests are repo-level
unit/scenario suites (the spec 0806 delivery hit the same wall), so the
evidence below is from the real `dart analyze` / `dart test` / live
`zfa dream` runs of THIS session.

## /speckit.tdd.verify dispatch (step 7) — REAL output

```text
zfa tdd verify --feature 1010-zfa-dream-one-command-app
zfa tdd verify: running mutation audit...
   feature: 1010-zfa-dream-one-command-app
   gate: not_assessed
   reason: no behavior artifacts registered
   killed: 0
   survived: 0
   timed_out: 0
   mutation_was_run: false
   restoration_verified: true
mutation: gate=not_assessed killed=0 survived=0 timed_out=0 mutation_was_run=false
❌ mutation audit gate: not_assessed (no behavior artifacts registered)
```

Exit 64 — the gate refuses honestly instead of green-washing (the
sections above this line are the command's real output, kept verbatim).

## Test-first evidence (RED, pre-implementation — this session)

```text
$ dart test test/plugins/tdd/commands/ingest_command_test.dart \
           test/plugins/mcp/dream_draft_spec_tool_test.dart \
           test/commands/dream_command_test.dart
00:00 +0 -12: Some tests failed.  (+ 2 loading errors)
  ingest:  ❌ Could not find an option named "--draft".        (usage, exit 64)
  dream:   Error: Error when reading '.../services/dream_runner.dart': No such file or directory
           ❌ Could not find a command named "dream"           (top-level, exit 64)
  v2 tool: v2ToolDefinitions has 11 tools (no dream_draft_spec)
```

Red entry recorded in `tdd/cycle-log.md` (`1010-dream-RED`).

## Green evidence (this run — real numbers)

| Suite | Result |
|---|---|
| NEW: `test/plugins/tdd/commands/ingest_command_test.dart` (U1–U4) | **10 passed, 0 failed** |
| NEW: `test/plugins/mcp/dream_draft_spec_tool_test.dart` (U5–U8) | **6 passed, 0 failed** |
| NEW: `test/commands/dream_command_test.dart` (A1, A2, A3, U9-fast) | **4 passed, 0 failed** |
| NEW: `test/integration/dream_cli_integration_test.dart` (U9, real CLI) | **1 passed, 0 failed** (68 s, `--preset=integration`) |
| AMENDED: `test/plugins/mcp/mcp_v2_test.dart` | **14 passed, 0 failed** (11→12 tools + `dream_draft_spec`; the amendment is inlined in the test) |
| Chunked fast suite (`tools/run_tests_chunked.sh` semantics, 74 chunks) | **all 74 chunks PASS** (3 SKIP = no fast-tier tests: benchmark, tdd/scenarios, integration) |
| Chunker-skipped direct-file folders (the 0806 protocol: `test/commands` 136, `test/plugins/tdd` direct 240, `test/plugins/tdd/services` direct 529, `test/core` direct 401+1 skipped, `test/plugins` direct 8) | **all passed, 0 failed** |
| `dart analyze lib test --no-fatal-warnings` (the CI dart_core job) | **0 errors, 0 issues in every touched file** (314 pre-existing infos/warnings, none in the new code; baseline identical to master) |
| `dart format .` | **0 changed** (`git diff --stat` after format: only the intended files) |

## LIVE demo (SC1 / L1 — the issue #1010 exit criterion)

Scratch project `/tmp/dream_live3`: a real git repo (master) with a real
local bare remote (`git init --bare`), `gh` provided by a PATH shim that
logs its argv and returns a PR URL (no gh CLI in this sandbox — the git
machinery is all real), and the engine/skin phases driven by the
exec-forwarder fake zfa bin (the sc_018 pattern: `ingest`/`plan` exec the
REAL CLI; `run`/`view` are scripted outcomes — a real engine cycle is
covered by the run_command suites and SC-018).

```text
$ dart run bin/zfa.dart dream "A page that lists the user's favorite deals, sorted by expiration" \
    --project /tmp/dream_live3 --zfa-bin <exec-forwarder fake>
[dream] feature=001-favorite-deal project=/tmp/dream_live3
[dream] draft attempt 1/3 ...
[dream] drafter=deterministic
[dream] ingest accepted (attempt 1)
[dream] plan ok (tdd/test-list.md, tdd/traceability.md)
[dream] engine green (result=complete)
[dream] skin A1 scaffolded — the handcraft seam: a `skin/001-favorite-deal` branch will be opened
[dream] engine receipt: .zfa/receipts/…-dream-engine-001-favorite-deal.json
[dream] skin receipt: .zfa/receipts/…-dream-skin-001-favorite-deal.json
[dream] skin hand-edit branch opened: skin/001-favorite-deal
dream: feature=001-favorite-deal result=complete drafter=deterministic attempts=1 engine=green skin=hand-edit pr=https://github.com/arrrrny/zuraffa/pull/1234
exit 0
```

Artifacts on disk after the run (the exit-criterion set):

```text
git branch -a:        001-favorite-deal, master, * skin/001-favorite-deal
git ls-remote:        refs/heads/001-favorite-deal   (pushed for real)
git show --stat:      spec(001-favorite-deal): zfa dream — A page that lists the user's favorite deals, sorted by expiration
                      7 files, 243 insertions:
                        specs/001-favorite-deal/spec.md
                        specs/001-favorite-deal/plan.md
                        specs/001-favorite-deal/tdd/draft-spec.md
                        specs/001-favorite-deal/tdd/test-list.md
                        specs/001-favorite-deal/tdd/traceability.md
                        .zfa/receipts/…-dream-engine-001-favorite-deal.json
                        .zfa/receipts/…-dream-skin-001-favorite-deal.json
gh argv (shim log):   pr create --title "spec(001-favorite-deal): zfa dream — …"
                      --body "…Artifacts…Engine: green…" --head 001-favorite-deal
                      (no --draft: the engine is green)
```

That is: spec + 3 plan files (plan.md, tdd/test-list.md,
tdd/traceability.md — the last two produced by the REAL `zfa tdd plan`)
+ cycle-log (in the A1 test, where the fixture seeds the state a real
engine run leaves behind; the live fake-run demo has no cycle-log, and
the engine receipt lists only files that exist — no fabrication) + 2
engine/skin receipts, one PR, draft iff the engine is not green (proved
by A3: `--draft` present + exit 1 when the engine stops).

## Success criteria — PROVED vs not

- **SC1** (happy path artifact set + receipts + ready PR + exit 0): **PROVED** — A1 test + the LIVE demo above.
- **SC2** (colliding draft refused; refusal reaches the LLM re-prompt; renamed draft accepted; attempts=2): **PROVED** — A2 (the collision is the real bug #942 `Credentials` trap, detected through the real `FrameworkExportSurface` via a seeded probe surface, the framework_export_surface_test pattern).
- **SC3** (deterministic draft passes the REAL `zfa tdd plan`; 12 v2 tools): **PROVED** — U6 + U5 (amended count test).
- **SC4** (scaffolded skin → hand-edit branch + pending receipt; non-green engine → `--draft` PR + exit 1): **PROVED** — A3.
- **SC5** (gates): **PROVED** — analyze/format/chunked numbers above; this verification.md written from the real runs; tasks ticked.
- **NOT PROVED (honestly)**: the mutation audit (gate `not_assessed` — no pipeline-registered artifacts; same wall 0806 hit, no spot-check fallback invented); a REAL engine-green cycle inside a live dream run (the live demo's engine phase is the scripted fake — the real engine cycle to green is proven by the run_command/SC-018 suites, and the dream→run wiring is proven at the argv level by A1/A3 and the spawn log).

No assertion was weakened. One pre-existing test was AMENDED deliberately:
`test/plugins/mcp/mcp_v2_test.dart` "returns all 11 v2 tool definitions" →
"returns all 12" + `dream_draft_spec` in the names list, with the spec-1010
amendment note inlined (the #942 amendment precedent).
