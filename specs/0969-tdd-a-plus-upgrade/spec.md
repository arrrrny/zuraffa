**Template Version**: `zuraffa-1.0`

# Spec 0969 — tdd A+ upgrade: --json verdict envelope on all verbs + proof.v1 receipts on every generation verb + openwiki presence

## Mission

Make `tdd` an **A+ plugin** (flagship, A 4.50/5). It is already honest at
the core — finish the machine contract and the proof surface. Zero lying
surfaces, machine-parseable verdicts everywhere, receipts on every
generation verb.

## Acceptance Scenarios

1. **Given** a feature driven through the TDD loop **When** an agent
   invokes any `zfa tdd` verb with `--json` **Then** the final stdout
   line is exactly one versioned `verdict.v1` envelope carrying
   `command`, `feature`, `verdict`, `exit_class`, `fix`, `drifts`,
   `details` and `timestamp`.
2. **Given** a consumer needs to pin the machine contract **When** it
   runs `zfa tdd verdicts --schema` **Then** the output is
   diff-stable (byte-identical across runs and machines).
3. **Given** a full plan→gen→verify-red→make cycle **When** every
   generation verb finishes **Then** each generated artifact is
   digest-bound by a proof.v1 receipt under `.zfa/receipts/`, and
   `zfa proof check` exits 0 on the fresh cycle and exits 1 when an
   artifact is hand-edited afterwards.
4. **Given** a receipted artifact was hand-edited **When** `zfa tdd
   verify` runs **Then** the proof preflight refuses with a
   `NOT_ASSESSED` verdict, a non-zero exit and a `--> fix:` line
   BEFORE the mutation audit starts.
5. **Given** a documentation consumer **When** it reads openwiki **Then**
   `cli.md` carries the full `zfa tdd` command table and
   `testing.md` links the cycle flow.

## Functional Requirements

- **FR-001**: Every `zfa tdd` subcommand accepts `--json` and, when the
  flag is set, emits the versioned verdict envelope as the FINAL stdout
  line on every exit path (success, refusal, error). When the flag is
  absent, the human output is byte-identical to the pre-#969 behavior.
- **FR-002**: The envelope schema is `verdict.v1` with the keys
  `schema`, `command`, `feature` (optional), `verdict`
  (pass/fail/stopped/error), `exit_class`, `fix` (optional), `drifts`,
  `details`, `timestamp`. The envelope never changes an exit-code
  taxonomy: `exit_class` carries the verb's shipped taxonomy label.
- **FR-003**: A test asserts the exact envelope schema for at least
  plan, gen, verify-red, make, run and realize, and asserts the grammar
  is uniform (same required key set) across every verb.
- **FR-004**: `zfa tdd verdicts --schema` prints the envelope schema
  (verbs, key types, verdict categories) diff-stably, asserted by test.
- **FR-005**: The generation verbs gen, make, view, func, wire and
  compose write proof.v1 receipts (the `ReceiptStore` machinery
  `realize` already uses) covering every file they wrote; plan and
  verify-red receipt their generated artifacts so the full cycle is
  self-certifying.
- **FR-006**: `zfa tdd verify` runs the proof preflight (`zfa proof
  check` semantics over the feature's receipts) before the mutation
  audit; digest drift → `NOT_ASSESSED` verdict, exit 3, `--> fix:` line.
- **FR-007**: The last-line machine grammar is unified: exactly one
  machine verdict line under `--json` (the legacy doctor raw-JSON line
  and reset raw-JSON line fold into the envelope; gen's batch verdict
  becomes the wrapper envelope).
- **FR-008**: openwiki `cli.md` documents the tdd command table and
  `testing.md` documents the TDD cycle flow, including the receipt
  surface and the hand-edit detection contract.

## Constraints

- Do NOT touch the widget-lane finder semantics (#964/#965/#966).
- Do not change exit-code taxonomies already shipped
  (`run_command.dart` 0/1/2/3/4).
- Every new behavior lands with a failing-first test under
  `test/plugins/tdd/`.
- Validation: `dart analyze` + `dart test test/plugins/tdd/` + the fast
  suite for touched commands; never `dart test --preset=all`.

## Key Entities

- **VerdictEnvelope**: the versioned verdict model — command, feature,
  outcome, exitClass, fix, drifts, details, timestamp; emits one
  compact JSON line.
- **VerdictContext**: per-invocation carrier a command body populates
  (feature, outcome, exitClass, fix, drifts, details, emitted).
- **TddGenerationReceipts**: proof.v1 receipt writer binding each
  written file's sha256 digest into `.zfa/receipts/` with the feature
  scope in `input`.
