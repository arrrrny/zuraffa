# Spec 1005 — skin hand-written seam: contract + logging + login_view.dart as proof

GitHub issue: arrrrny/zuraffa#1005

## Problem

The skin half of a feature may be hand-written (or AI-written). Today the
loop only trusts its own generations: the widget lane reaches green via
the GENERATED minimal scaffold (`zfa tdd view`, issue #939), and the dream
runner treats a scaffolded view as an open-ended handcraft seam
(`skin=<feature>` branch, no verification). Nothing referees a
hand-written view:

- (a) nothing checks the view against the DECLARED contract — the
  `## Lanes` SKIN lane's `adaptive_slots` (issue #1000) are rendered into
  `04-SKIN.md` but never re-checked against the implementation;
- (b) nothing checks that widget tests for the skin behavior exist and
  actually execute;
- (c) nothing witnesses the red → green transition for a hand-written
  implementation — the author's claim is the only evidence;
- (d) no `_XRaySkinHandEdit` annotation exists, so a receipt cannot
  capture which behaviors were hand-edited, in which files, when;
- (e) there is no skin receipt — `04-skin-receipt.json` does not exist,
  and no SkinEvent stream feeds a digest.

Consequently `zfa tdd run-skin` does not exist at all: the `zfa tdd`
command surface has no skin-cycle driver.

## Deliverables

1. `zfa tdd run-skin <feature>` — the skin-cycle driver. The cycle
   accepts a SKIN behavior whose implementation file is hand-written iff
   (a) the view renders the declared platform slots (verified from the
   SkinEvent stream emitted while the tests run, not from source string
   matching), (b) widget tests exist and execute, (c) the tests go red
   before green — witnessed by the CYCLE via a stub-revert run (the
   mutation-audit pattern: capture the hand-written bytes, replace the
   view-builder with the inert stub, run the paired test, expect RED,
   restore the file byte-exact, run again, expect GREEN), and (d) the
   implementation file carries a
   `_XRaySkinHandEdit(behavior: "W1", file: "lib/...", logged_at: ...)`
   annotation — scanned, parsed, and cross-checked (behavior id == the
   row's id, file == the record's project-relative subject path,
   logged_at == ISO-8601) by the cycle, never trusted from the author.
2. `specs/<feature>/tdd/04-skin-receipt.json` (schema `skin.v1`):
   per-behavior `conformance: true|false`, `platform_slot_fills`
   (the union of slots observed in the green run's SkinEvent stream),
   `hand_edits: [{behavior, file, logged_at}]`, and
   `skin_event_trace_digest` (sha256 over the canonical SkinEvent trace
   captured across the red and green runs).
3. The login view is the first hand-written skin to re-split under the
   new contract: `example/lib/src/presentation/pages/login/login_view.dart`
   — a hand-written adaptive view (mobile/ios/android/macos slot
   branches) whose paired widget test
   `example/test/presentation/pages/login/login_view_test.dart` pumps
   the platform matrix and whose skin events fill all four declared
   slots.

## Design

### The `_XRaySkinHandEdit` annotation

A source-level, cycle-scanned annotation (the `@XRayMock` regex-scan
precedent — a real Dart identifier would need an import the hand-written
file must not be forced to carry):

```dart
/// _XRaySkinHandEdit(behavior: "W1",
///   file: "lib/src/presentation/pages/login/login_view.dart",
///   logged_at: "2026-09-05T00:00:00Z")
```

The scanner accepts the fields in the fixed order `behavior`, `file`,
`logged_at`, double-quoted, tolerant of line breaks and `///` comment
continuations between the fields. Conformance requires at least one
annotation whose `behavior` equals the behavior row id and whose `file`
equals the project-relative POSIX subject path recorded in the registry;
`logged_at` must parse as ISO-8601.

### The SkinEvent stream

The skin emits machine-greppable event lines while the tests run:

```text
skin-event: behavior=W1 slot=mobile
```

`SkinEventTrace.parse` extracts them from the runner transcript (both
`dart test` and `flutter test` forward prints to stdout). The cycle tags
each parsed event with the phase it was observed in (`red`/`green`), so
the full trace is the ordered `(behavior, slot, phase)` triples across
the two runs. `skin_event_trace_digest` = sha256 over the canonical
newline-joined `behavior|slot|phase` lines — deterministic, no
timestamps inside the events.

### The red witness (stub-revert, the mutation-audit pattern)

Per skin behavior, the cycle:

1. parses the paired TEST source for the view-builder target
   (`subject.<name>(` — the immutable test defines the contract, never
   the author's implementation);
2. captures the implementation file's bytes + sha256
   (`SourceRestorer`);
3. replaces ONLY the view-builder function (expression or block body,
   parens/braces depth-matched) with
   `Widget <name>() => throw UnimplementedError('zfa tdd run-skin: temporary inert stub — the issue #1005 red witness; restored verbatim after the run');`
4. runs the paired test through the TDD profile's `single` template —
   it MUST fail (RED; the generated widget-test guard turns the thrown
   `UnimplementedError` into an assertion failure);
5. restores the implementation byte-exact and verifies the sha256;
6. runs the paired test again — it MUST pass (GREEN), and its transcript
   yields the platform slot fills.

The test file is NEVER edited (the spec 044 FR-022 rule). A builder the
cycle cannot find, or a file it cannot restore byte-exact, is an honest
conformance failure — never a crash, never a fake green.

### The command surface

```text
zfa tdd run-skin <feature> [--project <dir>] [--timeout <min>] [--json]
```

Machine contract (the final stdout line):

```text
run-skin: feature=<f> result=<complete|stopped> behaviors=<n>
conformed=<n> slots=<fills/declared> hand_edits=<n>
```

Exit 0 iff every SKIN behavior conforms. `--json` emits the verdict.v1
envelope (VISION §5, issue #964), matching `run`/`view`.

### The receipt (schema `skin.v1`)

```json
{
  "schema": "skin.v1",
  "feature": "004-login-ui",
  "command": "zfa tdd run-skin 004-login-ui",
  "behaviors": [
    {
      "behavior": "W1",
      "conformance": true,
      "test": "test/presentation/pages/login/login_view_test.dart",
      "subject": "lib/src/presentation/pages/login/login_view.dart",
      "platform_slot_fills": ["mobile", "ios", "android", "macos"]
    }
  ],
  "platform_slot_fills": ["mobile", "ios", "android", "macos"],
  "hand_edits": [
    {
      "behavior": "W1",
      "file": "lib/src/presentation/pages/login/login_view.dart",
      "logged_at": "2026-09-05T00:00:00Z"
    }
  ],
  "skin_event_trace_digest": "<sha256 hex>",
  "red_witness": true,
  "generated_at": "2026-09-05T00:00:00Z"
}
```

Written to `specs/<feature>/tdd/04-skin-receipt.json` after every run
(green or stopped — a stopped run records the honest partial state).

## Testing

- FAST tier (pure logic, no spawns): annotation scanner tolerance +
  cross-checks; SkinEvent parse + digest determinism; receipt round-trip;
  stub-revert replacement on expression and block bodies.
- SLOW tier (real `dart test` spawns in a TddFixture, the
  `verify_red_command_test` pattern): the full cycle per behavior —
  red witness, byte-exact restore, green run, cycle-log evidence entries
  (the schema-1 hash chain), receipt bytes, summary line, exit codes.
- The REAL acceptance (this branch, Flutter 3.47.2): `zfa tdd run-skin
  004-login-ui --project example` is green with the hand-written
  `login_view.dart`; the receipt records 4 platform slot fills and the
  hand-edit annotation; `login_view.dart` compiles in the example app.

## Success Criteria

- `zfa tdd run-skin 004-login-ui` (against `example/`) is green with
  hand-written views.
- `04-skin-receipt.json` records 4 platform slot fills and at least one
  hand-edit annotation.
- `login_view.dart` carries a `_XRaySkinHandEdit` annotation and
  compiles.
- The full existing fast suite passes with zero semantic change to
  existing skin tests.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [FR-001..FR-006 implementation rows]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1-W4]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3 (acceptance: the skin seam accepts hand-written views)]
    flutter_allowed: conditionally
```
