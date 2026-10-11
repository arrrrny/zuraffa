# Spec 1113 — [LOOP] Unified TDD journal + JournalReader: glue for engine/skin receipts, status, prove

Issue: https://github.com/arrrrny/zuraffa/issues/1113
Branch: `spec/1113-unified-tdd-journal`

## Problem

The two-cycle driver shipped (#1008, merged as PR #1092). The gap is the
journal — the unified, machine-parseable record of `run-engine` then
`run-skin` that downstream tooling (`zfa tdd theater` #1006, `zfa tdd
status`, `zfa tdd prove` #1013) reads to render state:

- Each cycle writes its own `tdd/cycle-log.md` prose and its own lane
  receipt (`tdd/04-engine-receipt.json` / `tdd/04-skin-receipt.json`);
  nothing stitches them into ONE machine-parseable stream per feature.
- `zfa tdd status` reads the two receipts directly — no unified view
  (mock certification, platforms, violations), and every consumer
  re-implements its own file parsing (theater parses the cycle-log
  again, status parses receipts again).

## What was built

1. **Unified journal schema** — `tdd/journal.schema.json` (draft
   2020-12), generated from the model (`JournalSchema.document`, the
   skin-contract "generated, never hand-maintained" pattern). Every
   cycle (engine/skin/meta) writes `tdd/cycle-log.md` (existing,
   unchanged) AND appends a structured entry to
   `specs/<feature>/tdd/journal.json`. Entry fields:
   `{feature, cycle: engine|skin|meta, phase: gate|drive|aggregate|prove,
   started_at, finished_at, gate_state: green|red|preflight_red|not_assessed,
   receipts: [...], violations: [...], refs: {engine_receipt, skin_receipt,
   contract_schema}}` plus additive extras (`result`, `behaviors`,
   `counts`, `stopped_at`, `mocks`, `fingerprints`).
2. **`JournalReader` API** — `package:zuraffa` exports it
   (`lib/zuraffa.dart`). One canonical stream per feature: journal
   entries, the receipts its refs point at, the cycle-log content, the
   per-behavior green evidence, the registered behaviors, and the
   derived one-line verdict. Theater, status, and prove read this API —
   no journal file I/O in their code.
3. **`zfa tdd run` meta-driver** — engine then skin, fail-fast on
   engine red (unchanged, #1092), now writing one meta journal entry on
   every terminal outcome: green (both lanes green), red (engine or
   skin honest stop, `stopped_at` named as a violation),
   preflight_red (the cert-gate refused before any step spawned).
   `run-engine` / `run-skin` lane runs and the run-skin engine-gate
   refusal write their entries through the same writer.
4. **`zfa tdd prove <feature>`** — walks the journal via JournalReader,
   computes the delta: behaviors ungated since the LAST prove. The
   prove entry records per-behavior file fingerprints (sha256 of the
   registered subject + test files); the next prove recomputes and
   reports only behaviors whose files changed (plus behaviors with no
   green evidence). Incremental — no test re-run, no full re-drive.
5. **`zfa tdd status <feature>`** — keeps the merged machine line
   (`status: feature=<f> engine=<v> skin=<v>`) and adds the journal's
   one-line verdict:
   `<feature> | engine ✅ <done>/<total> | skin ✅ <done>/<total>
   (<n> platforms) | mocks <certified>/<total> certified | <n> violations`,
   sourced from the journal via JournalReader. Exit 0 iff both lanes
   green (unchanged rule, unchanged exit codes).

## Cross-references

- `refs.engine_receipt` → `tdd/04-engine-receipt.json` (#1008/#1109)
- `refs.skin_receipt` → `tdd/04-skin-receipt.json` (#1008 lane-schema
  or #1005 skin.v1 shape — both journaled)
- `refs.contract_schema` → `tdd/04-skin-contract.schema.json` (#1111)
- One journal, one feature, three structured artifacts — the
  engine/skin split's "decoupled, contract-glued" promise in
  machine-parseable form.

## Success criteria (from the issue, all PROVED in tdd/verification.md)

- `zfa tdd run 004-login-ui` writes `tdd/journal.json` schema-valid.
- `zfa tdd status 004-login-ui` prints the one-line verdict from the
  journal, exit 0 on green.
- `zfa tdd prove 004-login-ui` after editing one skin view reports only
  the changed behavior is ungated (test confirms it).
- Theater (#1006), status, prove all use JournalReader — no journal
  file I/O in their code.

Hard constraint: one PR for this spec. Closes #1113.
