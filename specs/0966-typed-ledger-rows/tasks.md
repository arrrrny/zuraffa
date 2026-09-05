# Tasks: 0966-typed-ledger-rows (issue #966, extends #963)

**Input**: GitHub issue #966 (sole input) · **Cycle**: red → green → refactor → verify

## Phase 1: Behaviors (TDD — red first)

- [x] T001 **RED** — Typed ledger row schema: `LedgerRowKind`
      (presence/absence/navigation/state/sequence + advisory golden), `TypedLedgerRow`,
      `TypedLedgerBuilder.derive`, and gap detection — a test proving **untraced kinds
      are flagged as gaps** by the typed gate. Red evidence: `tdd/evidence/t001-red.txt`
      (UnimplementedError from the gate); green: `t001-green.txt`.
- [x] T002 **GREEN** — Absence assertions in the ledger: an absence row
      (`notRenderedIn: initial`, "error banner hidden initially") is **traced when
      hidden** — the tracing behavior is green ⇒ DONE, the kind gap clears; a
      permanently-rendered view cannot satisfy it; a malformed absence assertion
      (no state pinned) never counts. Evidence: `t002-red.txt` / `t002-green.txt`.
- [x] T003 **GREEN** — Sequence rows: a sequence row records the chain
      (tap → loading → resolve → navigate) and is **traced as a chain end-to-end** when
      the chain's tracing behavior is green; an unrecorded chain never counts.
      Evidence: `t003-red.txt` / `t003-green.txt`.
- [x] T004 **GREEN** — State rows: a state row records the asserted attribute
      (buttons disabled while in flight — FR-005-class) and is **traced end-to-end in
      004-login-ui** when the attribute's tracing behavior is green; an unrecorded
      attribute never counts. Evidence: `t004-red.txt` / `t004-green.txt`.
- [x] T005 **GREEN** — XRay overlay renders **kind coverage per screen**; the
      all-9-literals-`Column` view **fails the gate** (absence + sequence untraced) and
      shows as partially traced; golden rows are advisory and never block the gate.
      Evidence: `t005-red.txt` / `t005-green.txt`.
- [x] T005b **remediation** — T6 (goldens advisory + navigation kind;
      `t006-red.txt`/`t006-green.txt`), T7 (full verb→kind matrix; `t007-green.txt`),
      T8 (artifact strength pins; `t008-green.txt`).

## Phase 2: Verification

- [x] T006 **REFACTOR + VERIFY** — cleanup via tooling: `dart format .` zero-diff
      (1858 files, 0 changed); `dart analyze` — no new issues (18 info-level lints,
      the same classes the 075 corpus harness carries); chunked fast suite —
      **no NEW failures** (all chunks green, 0966 chunk 8/8); mutation audit:
      `zfa tdd verify` real runs (pass 1: 96/203, pass 2 after subject pins:
      171/280) + deliberate production-code audit 108/118 (91.5%, Success —
      `tdd/evidence/deliberate-mutation-report.md`); then `/speckit.tdd.verify` →
      `tdd/verification.md` generated fresh from the final real run.

## Acceptance targets (from the issue)

- [x] The all-9-literals-`Column` view fails the ledger gate (absence + sequence rows
  untraced) — T1/T5.
- [x] FR-005-class behaviors are expressible and traced end-to-end in 004-login-ui —
  T4 (full honest 004-login-ui ledger: presence + absence + sequence + state all
  traced, verdict passed).
- [x] XRay overlay distinguishes kind coverage per screen — T5 (`/login` partially
  traced vs `/deal_list` fully traced), T8 (polarity pins).
