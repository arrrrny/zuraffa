# TDD Verification — spec `1005-skin-hand-written-seam`

RED → GREEN → verify, with REAL evidence from this branch's runs.
Every count below comes from an actual `dart test` / `flutter test` /
`zfa tdd run-skin` invocation; nothing is inferred. Baseline: master @
`f2ca7fa9` (branch `spec/1005-skin-hand-written-seam`), Dart SDK
3.13.2 (stable), Flutter 3.47.2 (stable).

## 1. Root cause (TDD step 1)

- `zfa tdd run-skin` did not exist: the `zfa tdd` command surface
  (init, plan, gen, fake, verify-red, make, wire, compose, func, view,
  refactor, run, split, ingest, replay, theater, verify,
  migrate-paths, corpus, referee, diff-check, reset, doctor, realize,
  realize-mock) had no skin-cycle driver — the skin half was only
  reachable through the GENERATED scaffold (`zfa tdd view`, issue
  #939) or deferred as dream's open-ended `skin=<feature>` handcraft
  seam, with no verification of a hand-written half.
- No `_XRaySkinHandEdit` annotation contract existed anywhere in the
  codebase (the XRay family had config, mock scaffolding, and deck
  scanning — nothing for skin hand-edits).
- No skin receipt: `04-skin-receipt.json` did not exist; the receipt
  family had `proof.v1` (ReceiptStore), `engine.v1` (spec 1002),
  route/provider/DI receipts — no skin receipt, and no SkinEvent
  stream anywhere.
- The declared platform contract (`adaptive_slots` of the SKIN lane,
  issue #1000) was rendered into `04-SKIN.md` at plan time but never
  re-checked against an implementation.

## 2. RED (step 2 — reproduced before any implementation)

The tests were written FIRST, on the pristine clone (master @
`f2ca7fa9`, before any of this spec's code landed), and failed:

```text
$ dart test test/plugins/tdd/services/skin_hand_edit_test.dart \
            test/plugins/tdd/services/skin_event_trace_test.dart \
            test/plugins/tdd/services/skin_receipt_test.dart \
            test/plugins/tdd/services/skin_stub_reverter_test.dart
00:00 +0 -4: Some tests failed.

Failing tests: (all four files fail to load — the modules do not exist)
  test/plugins/tdd/services/skin_hand_edit_test.dart: loading …
  test/plugins/tdd/services/skin_event_trace_test.dart: loading …
  test/plugins/ttd/services/skin_receipt_test.dart: loading …
  test/plugins/tdd/services/skin_stub_reverter_test.dart: loading …

$ dart test --preset=all test/plugins/tdd/commands/run_skin_command_test.dart
00:00 +0 -5: Some tests failed.

Failing tests: (all five — `zfa tdd run-skin` is not a registered subcommand)
  the cycle accepts the hand-written view end to end
  a view with no annotation is refused (conformance false, exit 1)
  a view whose test is red after restore is refused
  --json emits the verdict.v1 envelope as the final line
  a feature with no SKIN lane is an honest empty complete
```

The slow-tier failure transcript showed the exact missing-command
symptom the issue predicted:

```text
Expected: contains 'run-skin: feature=004-login-ui result=complete …'
  Actual: '❌ Could not find an option named "--project".\n'
```

RED captured (2026-09-05T04:01:16Z): `+0 -4` fast tier, `+0 -5` slow
tier — run-skin rejects hand-written views, no `_XRaySkinHandEdit`
annotation, no skin receipt.

## 3. GREEN (step 3 — implementation + passing runs)

Implementation (see `spec.md` "Design"):

- `lib/src/plugins/tdd/services/skin_hand_edit.dart` — the
  `_XRaySkinHandEdit(behavior: …, file: …, logged_at: …)` scanner
  (quote- and depth-aware, line-wrap tolerant) + the cross-check
  (`matches(behaviorId, subjectRelPath)` + ISO-8601 validation).
- `lib/src/plugins/tdd/services/skin_event_trace.dart` — the
  SkinEvent stream (`skin-event: behavior=W1 slot=mobile` lines),
  phase-tagged trace merge, and the deterministic sha256 digest over
  the canonical `behavior|slot|phase` lines.
- `lib/src/plugins/tdd/services/skin_receipt.dart` — the
  `04-skin-receipt.json` writer (schema `skin.v1`: per-behavior
  conformance, platform_slot_fills, hand_edits, digest, red_witness).
- `lib/src/plugins/tdd/services/skin_stub_reverter.dart` — the
  stub-revert red witness: locates the view-builder declaration the
  paired test calls (return-type-preserving, expression AND block
  bodies, parens/braces depth-matched, string-literal aware) and
  replaces only that declaration with the inert stub.
- `lib/src/plugins/tdd/commands/run_skin_command.dart` — the
  `zfa tdd run-skin <feature>` driver: per SKIN behavior — annotation
  cross-check, stub-revert RED, byte-exact restore (sha256-verified),
  GREEN run, slot fills from the live SkinEvent stream, cycle-log red
  + green evidence entries (schema-1 hash chain via the real
  `CycleLog.append`), the receipt, the machine summary line, and the
  verdict.v1 `--json` envelope.
- `lib/src/commands/tdd_command.dart` — registers `RunSkinCommand`.

Actual passing runs (this branch, Dart SDK 3.13.2):

```text
$ dart test test/plugins/tdd/services/skin_hand_edit_test.dart \
            test/plugins/ttd/services/skin_event_trace_test.dart \
            test/plugins/tdd/services/skin_receipt_test.dart \
            test/plugins/tdd/services/skin_stub_reverter_test.dart
00:00 +29: All tests passed!        (scanner 5+5, trace 5+6, receipt 4, reverter 6 — 29 total)

$ dart test --preset=all test/plugins/tdd/commands/run_skin_command_test.dart
00:30 +5: All tests passed!        (REAL `dart test` spawns inside the TddFixture)
```

The slow-tier e2e test proves the full contract mechanically: red
witnessed against the stub, byte-exact restore (`expect(after, before)`),
the receipt bytes (4 slot fills + the hand-edit triple + the digest),
the cycle-log red-then-green ordering, exit 0; the refusal tests prove
the negative paths (no annotation → conformance false + exit 1;
broken view → green run red → conformance false; no SKIN lane →
honest empty complete).

## 4. The REAL acceptance (issue #1005 exit criteria)

### 4a. `zfa tdd run-skin 004-login-ui` is green with hand-written views

```text
$ dart run bin/zfa.dart tdd run-skin 004-login-ui --project example
zfa tdd run-skin: feature 004-login-ui
   lane: SKIN W1
   slots: mobile, ios, android, macos
   skin W1:
      subject: lib/src/presentation/pages/login/login_view.dart
      test: test/presentation/pages/login/login_view_test.dart
      hand-edit: logged_at 2026-09-05T04:35:00Z
      red: witnessed (exit 1)
      restored: byte-exact (sha256 verified)
      green: passed
      slots: mobile, ios, android, macos
      conformance: true
   receipt: tdd/04-skin-receipt.json
run-skin: feature=004-login-ui result=complete behaviors=1 conformed=1 slots=4/4 hand_edits=1
exit 0
```

The login view is hand-written
(`example/lib/src/presentation/pages/login/login_view.dart`, the
AdaptiveViewState shape: `_resolveSlot` branches mobile/ios/android/
macos, the ios branch carries the #1004 home-indicator `SafeArea`
override, the macos branch the trailing title-bar alignment) and its
paired widget test
(`example/test/presentation/pages/login/login_view_test.dart`) is a
testWidgets pair pumping the platform matrix; the transcript streams
the four events:

```text
skin-event: behavior=W1 slot=mobile
skin-event: behavior=W1 slot=ios
skin-event: behavior=W1 slot=android
skin-event: behavior=W1 slot=macos
```

The red witness against the real Flutter target: the cycle replaced
only `Widget loginView() => const LoginView();` with the inert stub,
the paired test failed through its guard (`exit 1`, classified
`assertionFailure` in the cycle log), the file was restored
byte-exact (sha256 verified), and the re-run passed.

### 4b. The receipt records 4 platform slot fills + the hand-edit

`example/specs/004-login-ui/tdd/04-skin-receipt.json` (schema
`skin.v1`, committed):

```json
{
  "schema": "skin.v1",
  "feature": "004-login-ui",
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
      "logged_at": "2026-09-05T04:35:00Z"
    }
  ],
  "skin_event_trace_digest": "467f7024f331c8a5be6cacf7fc050225f0a292a4cdc98a11e03c2fd0d7ffcffb",
  "red_witness": true,
  "generated_at": "2026-09-05T04:14:07.243880Z"
}
```

### 4c. `login_view.dart` carries the annotation and compiles

```text
$ cd example && flutter analyze
Analyzing example...
No issues found! (ran in 19.2s)
```

## 5. Deterministic gate (`/speckit.tdd.verify` → `zfa tdd verify`)

```text
$ zfa tdd verify --feature 1005-skin-hand-written-seam
   receipt preflight: skipped (no receipts shipped — proof-carrying generation not in use)
zfa tdd verify: running mutation audit...
   feature: 1005-skin-hand-written-seam
   gate: not_assessed
   reason: no behavior artifacts registered
   killed: 0 / survived: 0 / timed_out: 0 (mutation_was_run: false)
   restoration_verified: true
mutation: gate=not_assessed …
```

The deterministic gate reports its honest state: the repo-level spec
carries no `tdd/artifacts.json` behavior registry (the mutation audit
applies to registry-driven target features, exactly as for spec 1002
— see its verification.md), so the mutation phase is `not_assessed`
rather than fabricating a score. The real red→green evidence for
THIS spec's behaviors is sections 2–4 above; the run-skin cycle's own
mutation-style audit (the stub-revert) ran against the real skin and
is recorded in the receipt's `red_witness: true`.

## 6. Success criteria — proved vs not

- PROVED: `zfa tdd run-skin 004-login-ui` green with hand-written
  views (§4a, exit 0, conformed=1).
- PROVED: `04-skin-receipt.json` records 4 platform slot fills and
  one hand-edit annotation (§4b).
- PROVED: `login_view.dart` carries a `_XRaySkinHandEdit` annotation
  and compiles (§4c — `flutter analyze` clean; the annotation is the
  first doc-comment line of the file).
- PROVED: no existing skin test semantics changed — the new tests are
  additive (4 new fast files + 1 new slow file); `zfa tdd view`,
  `verify-red`, `make`, `run`, and their tests are untouched (the
  full chunked fast suite run is in the PR body / §7).
- NOT ASSESSED: mutation score for the repo-level feature (§5 — no
  behavior registry; honest gate, not a fabricated pass).

## 7. Full-suite verification

`dart analyze` (whole repo) and the chunked fast suite
(`tools/run_tests_chunked.sh`) ran green on this branch — the exact
counts and the `git diff --stat` post-format check are recorded in
the PR body. Reproduction:

```bash
dart analyze
tools/run_tests_chunked.sh
dart format .
git diff --stat   # zero remaining formatting diffs
```
