# Feature Specification: `zfa tdd theater` — read-only replay TUI for the TDD journal

**Feature Branch**: `1006-tdd-theater-replay-tui`

**Created**: 2026-09-05

**Status**: Draft

**Input**: Issue [#1006](https://github.com/arrrrny/zuraffa/issues/1006) — "[VISION] `zfa tdd theater <feature>` — replay TUI for the TDD journal". Part of the proof-carrying pillar: receipts (#807) and the cycle-log (#828 evidence chain) are the heartbeat of the proof system, but they are files on disk — invisible unless opened by hand.

## Mission

Everything the TDD pipeline certifies — red classifications, green evidence,
generation receipts, hash chains — lands in two places: `.zfa/receipts/` (the
#807 proof-carrying generation ledger) and `specs/<feature>/tdd/cycle-log.md`
(the tamper-evident journal). Both are honest, and both are invisible: a human
has to `cat` raw JSON and markdown to see the honesty. This feature makes the
honesty *visible* in the cheapest possible engineering: a read-only three-pane
terminal UI that renders the recorded journal for one feature — spec
annotation cards on the left, the cycle-log timeline on the right, a live
status line at the bottom — with click-to-drill interactions that surface the
receipt (action, evidence, file), the cycle evidence (command, exit, captured
output), and the classifier verdict (`[?]`).

The theater is a *replay projector*, not a driver: it mutates nothing, owns no
state of its own, and derives every pixel from the receipts and cycle-log that
already exist. That read-only constraint is the feature's identity — the
theater can never become a second source of truth, because it cannot write
anything at all.

**Runtime decision**: the issue names "the tui runtime at `lib/src/tui/`".
That path does not exist; the repo's TUI runtime lives in
`lib/src/plugins/tui/` (spec 017) as the nocterm engine wrapper for the *app
code-generation* pipeline. No cross-plugin import exists anywhere in `lib/`
(tdd never imports tui, tui never imports tdd), and the tui plugin's
`ZuraffaTui.run` is bound to its generator-facing `Screen`/DI abstractions.
The theater therefore takes the issue's sanctioned fallback — "a standalone
minimal TUI otherwise" — built directly on **nocterm** (the same pure-Dart
terminal engine the tui runtime itself wraps, `pubspec.yaml` nocterm ^0.9.0),
self-contained inside the tdd plugin. The TTY discipline of the tui runtime
(non-TTY stdout refuses to start with an actionable message, FR-009 of
017-tui-plugin) is mirrored exactly.

## Hard Constraints

- **Read-only**: the theater performs zero writes — no file, no registry, no
  state store, no run-state. Verification hashes the project tree before and
  after and requires byte-identity.
- **Driven from existing evidence**: every rendered field comes from
  `.zfa/receipts/` and `specs/<feature>/tdd/` (registry + test-list +
  cycle-log). No separate state, no re-derivation, no re-execution.
- **Receipt layouts**: receipts are read from `.zfa/receipts/<feature>/*.json`
  (the per-feature layout the issue names) *and* the flat `.zfa/receipts/*.json`
  store `ReceiptStore` actually writes today — flat receipts are attributed to
  the feature by matching their recorded file paths against the feature's
  registered subject/test paths (the same attribution
  `FeatureProvenanceReader` uses). Latest-wins per path.
- **One PR** for this spec, closing #1006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — `zfa tdd theater <feature>` opens a three-pane read-only replay (Priority: P1)

An operator finishes (or walks back into) a feature driven through the TDD
pipeline and runs `zfa tdd theater 004-login-ui` from a real terminal. A
three-pane TUI takes over the screen: the left pane lists one annotation card
per registered behavior (id, criterion, description, proof status), scrollable,
click-to-expand; the right pane shows the cycle-log timeline — every recorded
red/green/refactor entry in file order with its kind, exit and timestamp; the
bottom line is a live status bar (behavior/green/red counts, cycle count,
receipt count) plus the key map. Every registered behavior of the feature is
rendered. Quitting (`q`) restores the terminal and prints the machine summary
line `theater: feature=<f> behaviors=<n> cycles=<m> receipts=<k> result=opened`.

**Why this priority**: this is the deliverable's first bullet — the TUI itself.

**Independent test**: a fixture project with feature `004-login-ui` carrying a
registry, a test-list, a cycle-log seeded through the real `CycleLog.append`
writer and receipts in `.zfa/receipts/`: pumping `TheaterScreen` with the data
loaded by `TheaterData` renders every behavior id and the timeline; on a
non-TTY stdout the command refuses with an actionable message and exit 1.

### User Story 2 — click a behavior → its receipt; click a cycle → its diff (Priority: P1)

With the theater open, the operator clicks (or arrows-to + Enter) a behavior
card on the left: the card expands inline (description, test path, subject
path) and the right pane shows the behavior's **receipt** — the derived proof
`action:` (satisfied when green evidence exists, red when only red evidence,
pending when neither), the `evidence:` line (the recorded green test + exit +
timestamp, or the honest absence), and the `file:` line (the registered subject
path, plus the #807 receipt action/bytes/sha256 when a generation receipt
covers it). Clicking a cycle in the timeline instead shows the cycle's
evidence diff: command, exit, criterion, test, the captured output block, the
generation steps (green) and the chain hashes.

**Why this priority**: "the receipt is the heartbeat" — this is the honesty
becoming visible.

**Independent test**: `NoctermTester` taps a behavior card → the receipt pane
contains `action: satisfied`, the evidence line and the `file:` line; taps a
timeline cycle → the pane contains the recorded command and captured output.

### User Story 3 — `[?]` opens the classifier verdict for the selected behavior (Priority: P2)

The operator selects a behavior whose red the classifier already judged and
presses `?`. An overlay opens showing the classifier verdict: the
classification label (kebab-case, the `RedClassification` vocabulary),
the remediation hint for that class, and the failing-assertion evidence when
the red entry recorded one. Any key closes the overlay.

**Independent test**: `NoctermTester` selects a behavior with a classified red
entry, sends `?` → the overlay renders the classification label and remediation
hint; send any key → the overlay is gone.

### User Story 4 — the theater is provably read-only and failure-honest (Priority: P1)

Run in CI (non-TTY), the command never writes: hashing the whole project tree
before and after `zfa tdd theater <feature>` (including `.zfa/` and
`specs/`) yields byte-identical trees. An unknown feature id exits 1 with the
id named. A feature with a registry but no cycle-log still opens (every
behavior renders `pending`) — absence of evidence is not an error. A missing
registry exits 1 naming the feature and the missing artifact.

**Why this priority**: the read-only constraint is the feature's identity; the
failure paths keep the marketing claim honest.

**Independent test**: `TreeSnapshot` before/after byte-identity through
`CliRunner.runCapturing`; unknown-feature and no-cycle-log paths exit 1/0 with
the named ids.

## Design Summary

- `lib/src/plugins/tdd/services/theater_data.dart` — `TheaterData.load`:
  the read-only loader + snapshot model (`TheaterSnapshot`,
  `TheaterBehavior`, `TheaterCycle`, `TheaterReceipt`, `TheaterVerdict`).
  Parses the registry (`ArtifactRecord`), the test-list rows
  (`TestListReader`), the cycle-log sections (superset of
  `CycleEvidence.parseEntries`: classification, evidence, output block,
  generation steps, refactor actions), and receipts (per-feature dir + flat
  attributed store, latest-wins, `GenerationReceipt.fromJson`).
- `lib/src/plugins/tdd/widgets/theater_screen.dart` — `TheaterScreen`: a
  standalone nocterm `StatefulComponent` (three panes, keyboard + mouse,
  read-only by construction — it holds only transient selection state).
- `lib/src/plugins/tdd/commands/theater_command.dart` — the CLI surface
  (feature resolution mirroring `replay`, TTY guard, nocterm `runApp`, machine
  summary line).
