# Bug Assessment: TDD Plugin --json Verdict Envelopes + Receipts + Finder-Kind Gaps

- **Slug**: `tdd-plugin-json-verdict-receipts-finder-kind`
- **Created**: 2026-09-04
- **Source**: pasted text (referencing issues #964/#965)
- **Verdict**: valid — multiple real gaps; parts already shipped, parts missing
- **Severity**: high

## Report (verbatim or summarized)

The TDD plugin has three surface gaps:

1. **`--json` verdict envelope missing on all 25 verbs.** Only `gen` and `reset` emit JSON verdicts (unconditionally). The other 23 commands (`run`, `plan`, `make`, `view`, `realize`, `verify`, `verify_red`, `init`, `compose`, `refactor`, `reset`, `wire`, `fake`, `func`, `referee`, `corpus*`, `diff_check`, `replay`, `migrate_paths`) emit only plain-text `key=value` format. No `--json` flag is registered on any command.

2. **Receipts only on `realize`.** The nuance receipt system (`NuanceReceipts`) is integrated only into `realize_command.dart`. The `gen`, `make`, and `view` commands produce no provenance receipts — their output is invisible to the #807 proof-carrying ledger.

3. **Issue #964 (finder-kind taxonomy): ALREADY SHIPPED.** `FinderTaxonomy` at `lib/src/plugins/tdd/services/finder_taxonomy.dart:123` implements the full verb→assertion class mapping (presence, absence, routeOutcome, enabledState, sequence). It is already integrated into `behavior_test_writer.dart:282` and `view_command.dart:259`. The "widget lane degrades to presence assertions" defect is fixed.

4. **Issue #965 (i18n-keyed widget contracts): OPEN ENHANCEMENT.** The widget lane still emits hardcoded EN literals (`Text('ZikZak')`) rather than i18n keys (`t.app.name`). This blocks the zero-edit merge contract for i18n-heavy host projects. The `FinderTaxonomy.LiteralKind` enum already reserves `key` and `label` kinds but the generator does not use them yet.

## Symptom

- `zfa tdd run --json` does not work — the `--json` flag does not exist. CI/CD pipelines cannot machine-parse verdict outcomes without parsing ambiguous key=value text.
- Only `realize` writes provenance receipts; `gen`, `make`, `view` output is untracked in the #807 ledger.
- The i18n integration (#965) is a known open enhancement, not a regression.

## Reproduction

1. Run `zfa tdd plan --json` → unknown flag error (no `--json` registered).
2. Run `zfa tdd gen <id>` → no receipt in `.zfa/receipts/`.
3. Run `zfa tdd realize --hand-delta ...` → receipt written (the only command that does).
4. Run `zfa tdd view <widget-id>` → generated view has `Text('ZikZak')` hardcoded.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/*.dart` — all 25 command files lack `argParser.addFlag('json', ...)` and the JSON-verdict output branch
- `lib/src/plugins/tdd/commands/gen_command.dart:531` — already emits JSON via `_printBatchVerdict` (unconditionally, no flag guard)
- `lib/src/plugins/tdd/commands/reset_command.dart:165` — already emits JSON via `_printVerdict` (unconditionally, no flag guard)
- `lib/src/plugins/tdd/commands/realize_command.dart:239-300` — only receipt integration point
- `lib/src/plugins/tdd/services/nuance_receipts.dart` — receipt infrastructure (ready, not wired elsewhere)
- `lib/src/plugins/tdd/services/finder_taxonomy.dart:64` — `LiteralKind.key` reserved but unused in generator

## Root Cause Hypothesis

**Medium confidence.** The `--json` flag was never implemented as a cross-cutting concern — `gen` and `reset` were each given independent JSON output for their specific needs, without a shared verdict-envelope contract. Receipts were only wired to `realize` because it is the hand-delta gate, not a general provenance surface. The i18n gap (#965) is an open design-level enhancement that requires the slang test shell and key-resolution infrastructure.

## Proposed Remediation

**Preferred**: Three-phase implementation:

### Phase 1: Verdict Envelope Contract (all 22+ verbs)
- Define a shared `VerdictEnvelope` model in `lib/src/plugins/tdd/models/verdict_envelope.dart`:
  ```dart
  class VerdictEnvelope {
    final String command;
    final String feature;
    final String verdict; // pass | fail | stopped | error
    final Map<String, dynamic> details;
    final String schema; // "verdict.v1"
    final String timestamp;
  }
  ```
- Add `argParser.addFlag('json', negatable: false, help: '...')` to all 25 TDD command argParsers
- When `--json` is present, suppress the human-readable output and emit `jsonEncode(VerdictEnvelope(...))` as the final stdout line
- Refactor `gen_command._printBatchVerdict` and `reset_command._printVerdict` to emit through `VerdictEnvelope`
- The other 21 commands get a `_printVerdict` method that reads their existing state into the envelope

**Files likely to change**:
- `lib/src/plugins/tdd/models/verdict_envelope.dart` (new)
- `lib/src/plugins/tdd/commands/gen_command.dart` (refactor existing JSON through envelope)
- `lib/src/plugins/tdd/commands/reset_command.dart` (refactor existing JSON through envelope)
- `lib/src/plugins/tdd/commands/run_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/plan_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/make_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/view_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/realize_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/verify_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/verify_red_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/init_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/compose_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/refactor_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/wire_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/fake_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/func_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/referee_command.dart` (add --json to run/gate subcommands)
- `lib/src/plugins/tdd/commands/corpus_run_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/corpus_status_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/corpus_audit_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/corpus_differential_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/diff_check_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/replay_command.dart` (add --json flag + envelope)
- `lib/src/plugins/tdd/commands/migrate_paths_command.dart` (add --json flag + envelope)

### Phase 2: Receipts on gen/make/view
- Wire `NuanceReceipts.record()` into `gen_command`, `make_command`, and `view_command` after their artifact writes
- The `recordedBy` field identifies the originating command
- Receipt scope: each generated/scaffolded file gets a receipt entry

**Files likely to change**:
- `lib/src/plugins/tdd/commands/gen_command.dart`
- `lib/src/plugins/tdd/commands/make_command.dart`
- `lib/src/plugins/tdd/commands/view_command.dart`

### Phase 3: Finder-Kind i18n (issue #965 — out of scope for this fix, tracked separately)
- This is an open enhancement that requires the slang test shell infrastructure
- The `LiteralKind.key` kind in `FinderTaxonomy` is reserved but unused
- Tracked by issue #965 as an independent enhancement

## Risks & Considerations

- **Backward compatibility**: adding `--json` is non-breaking; existing consumers that parse key=value text are unaffected when `--json` is not passed
- **gen/reset existing JSON**: those two commands currently emit JSON unconditionally; the `--json` flag should guard this behavior (emit JSON only when `--json` is passed, revert to key=value otherwise) — this is a **breaking change** for consumers relying on unconditional JSON from `gen`/`reset`
- **Receipt volume**: wiring receipts to gen/make/view will create more ledger entries; the existing #807 infrastructure handles this
- **Issue #965 is out of scope**: i18n key contracts are a separate design-level enhancement

## Open Questions

- [NEEDS CLARIFICATION: Should `gen` and `reset` change from unconditional JSON to `--json`-gated JSON? This would be a breaking change for existing consumers.]
- [NEEDS CLARIFICATION: The user said "22 verbs" — should the `corpus` parent command and `referee` parent command also get `--json`, or only their subcommands?]
- [NEEDS CLARIFICATION: Is the i18n issue (#965) in scope for this bug fix, or should it remain tracked as a separate open enhancement?]
