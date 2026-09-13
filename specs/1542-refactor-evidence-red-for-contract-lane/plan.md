**Template Version**: `zuraffa-1.0`

# Plan: 1542-refactor-evidence-red-for-contract-lane

## Technical Context

- **Language/toolchain**: pure Dart CLI (Dart SDK ^3.11.0); no Flutter SDK
  on this package's own test path. Tests run via `dart test`.
- **Feature surface** (two seams — issue #1542 hard constraint: the contract
  lane, the blocked verdict, and the state machine are untouched):
  - `lib/src/plugins/tdd/commands/run_driver_core.dart` —
    `_evidenceMisfire` (line ~2393), step `refactor`: currently demands
    `hasRed && hasGreen`. ADDS: a `BehaviorKind? kind` parameter (threaded
    from the `_driveBehavior` call site, which already holds `row`), and
    the two-part red-defined-out-of-existence exemption:
    (a) `kind == BehaviorKind.contract` — the #1007 BLOCKED-never-RED lane;
    (b) the journal probe `evidence.bornGreenCertified(behaviorId)` — the
    #1411 green-without-red certification, consulted only when green
    exists and red does not (no extra I/O on the happy path).
    The exemption NEVER waives the green half: `green: false` still
    misfires for every class. The misfire message stays byte-identical for
    the non-exempt classes (the pinned bug #682 suite).
  - `lib/src/plugins/tdd/services/cycle_evidence.dart` — `ParsedCycleEntry`
    ADDS the optional `evidence` field (the `- evidence:` line, rendered by
    `CycleLogEntry.toMarkdown` for red entries since issue #959 and by the
    born-green transition since issue #1411; parsed additively — legacy
    entries without it stay valid). ADDS `CycleEvidence.bornGreenCertified`:
    the LAST green entry for the behavior carries `bornGreenEvidenceMarker`
    in its `- evidence:` field (the append-order rule `lastEntryFor`
    already applies).
  - `lib/src/plugins/tdd/services/born_green.dart` — ADDS the shared
    constant `bornGreenEvidenceMarker` (the exact journal token `issue
    #1411 born-green hand transition`). ONE wording source for the writer
    and the reader (FR-005). The marker is outside the chain payload
    (`payloadFromFields` covers behavior/kind/exit/command/criterion/
    test/timestamp/prev-hash only) — the hash chain is untouched.
  - `lib/src/plugins/tdd/commands/make_command.dart` — the born-green
    transition block (after the green evidence append + generation
    receipt, before `_printSummary`): the text of the appended entry's
    `capturedOutput`/`redEvidence` now interpolates the shared constant
    (byte-identical output), and the run-state advancement lands:
    load `RunStateStore(target.featureDir)`; when a state file exists AND
    the behavior's recorded state is `BehaviorState.blocked`, save
    `state.advance(id, BehaviorState.done)` (atomic tmp+rename+fsync the
    store already provides) and print the advancement line (FR-004/FR-006).
    `pending`/`red`/`green`/`mocked`/`done` are left untouched — each has
    a sound re-entry window (`_reconcile` promotes pending+green to green;
    red re-enters at make; green/mocked re-enter at refactor; done skips).
    No state file → no-op: make never fabricates a run.
  - `test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart`
    (NEW) — the driver-level suites (SC-1, SC-2, SC-4) on the scripted
    fake zfa (`TddFixture`): contract-lane green-only completes; born-green
    journal marker completes; the marker-less twin misfires
    byte-identically; the full `blocked` + born-green-journal flow
    re-enters at refactor (never at make) and completes.
  - `test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart`
    (EXTENDS) — the make-level suites (SC-3): `--born-green` on a seeded
    `blocked` run-state flips it to `done` on disk and prints the
    advancement; with NO state file the transition still exits 0 and
    writes none; a `pending` state is left untouched (the reconciliation
    window owns it).

## Design Decisions

- **D1 — key the born-green exemption on the JOURNAL, not the state file**
  (FR-002): the cycle-log is append-only evidence; the run state is a
  resumable cache that resets, degrades (#1468), and drops (#1264). A
  certification that survives `zfa tdd reset` must be read from the same
  surface the other evidence halves are read from. This also makes the
  exemption honest under the #828 chain: the probed entry is a parsed,
  hash-linked certified fact.
- **D2 — exempt the CLASS, not a state** (FR-001/FR-002): `contract` is a
  lane (a row kind), born-green is a transition (a journal fact); neither
  is a run state. Exempting states would leak the exemption to behaviors
  that reached the state through ordinary red→green cycles and would break
  the moment the state machine re-enters (the hard constraint forbids
  touching the state machine — so the exemption must not depend on it).
- **D3 — advance ONLY `blocked → done`** (FR-004): `blocked` is the one
  state with NO sound re-entry window for a born-green behavior —
  `_stepsFor(blocked)` re-enters at verify-red, and make (spawned flagless)
  refuses `not-certified-red` before any skip transition can fire. Every
  other state already re-enters soundly (pending promotes through
  `_reconcile`'s evidence bootstrap, bug #682; green/mocked re-enter at
  refactor; red re-enters at make). `done` is what the reconciliation
  expects a completed behavior to claim; the next run's `_reconcile`
  downgrades green-only `done` to `green`, which re-enters at refactor —
  the run still proves the owed refactor step (with the #1542 exemption)
  and re-claims `done` honestly. No state-machine edit required.
- **D4 — the shared marker constant is the drift kill** (FR-005): the
  writer and the reader key on ONE token. The make append's prose around
  the token may evolve; the token may not (the driver probe and the
  doctor's drift input both read it).

## Verification Plan

- Red-first: the new suites are written and captured RED against pristine
  `HEAD` (the driver suites show the `incomplete` misfire / the wedge; the
  make suite shows `blocked` surviving the transition), then the two seams
  land and the same suites go green (see `tdd/cycle-log.md`).
- Regression: the pinned bug #682 green-only honesty suite
  (`test/plugins/tdd/run_command_test.dart`) and the full
  `test/plugins/tdd/` fast tier stay green; `dart analyze` on the changed
  files reports zero new findings.
