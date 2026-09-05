# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 976-json-envelope (red)

- behavior: 976-json-envelope
- kind: red
- classification: assertionFailure
- criterion: SC-2
- test: test/plugins/state/state_create_json_receipt_test.dart
- command: `dart test test/plugins/state/state_create_json_receipt_test.dart`
- exit: 1
- at: 2026-09-04T23:12:27.161390Z
- output:
```
00:00 +0 -4: SC-2a: --json emits the {path, fields[], modes[], flavor, schema:1} envelope as the last stdout line [E]
  the last stdout line must be a single-line JSON envelope, got: "Run "zfa help" to see global options." (FormatException: Unexpected character (at character 1)
Failing tests:
  SC-2a: --json emits the {path, fields[], modes[], flavor, schema:1} envelope as the last stdout line
  SC-2b: a real generation ships a proof.v1 receipt at .zfa/receipts/state-<entity>.json binding the final bytes
  SC-2c: zfa proof check covers the state artifact (green on a fresh generation)
  SC-2d: proof check goes red when a receipted state artifact drifts
Root cause: `--json` on zfa state create is the generic CapabilityCommand
INPUT option ("Pass arguments as JSON string"); passing it bare dies with
"Missing argument for --json" — there is no OUTPUT verdict, and no state
receipt is ever written:
  SC-2c: Expected: a value greater than or equal to <1> / Actual: <0>
  proof check: {"schema":"proof.v1","ok":true,"receipts":0,"filesChecked":0,"findings":[]}
```

- schema: 1
- prev-hash: genesis
- hash: 1780f9a3e6a04d0cb8e9c8e1e0c95dcaebfacf3d00a41e07fd68c0ebfacaf0d9

## Cycle: 976-snapshot-goldens (red)

- behavior: 976-snapshot-goldens
- kind: red
- classification: assertionFailure
- criterion: SC-3
- test: test/plugins/state/state_snapshot_test.dart
- command: `dart test test/plugins/state/state_snapshot_test.dart`
- exit: 1
- at: 2026-09-04T23:12:27.161390Z
- output:
```
00:00 +0 -1: SC-3: the fixture matrix is byte-identical to the committed goldens (6 configs x 2 flavors) [E]
  Expected: true
    Actual: <false>
  goldens must be committed with the pre-dedupe baseline; regenerate ONLY on the pre-change builder with ZFA_STATE_UPDATE_GOLDENS=1
Failing tests:
  SC-3: the fixture matrix is byte-identical to the committed goldens
Root cause: the neutrality gate exists but the byte-identity baseline is
not checked in — before the dedupe lands, the pre-dedupe output must be
captured as committed goldens so the post-dedupe run proves byte-neutrality.
```

- schema: 1
- prev-hash: genesis
- hash: 111dc449245c732f60c9dae6b279eee608f670e948bd6e416564223b066f5d48

## Cycle: 976-output-schema (red)

- behavior: 976-output-schema
- kind: red
- classification: assertionFailure
- criterion: order-5
- test: test/plugins/state/state_output_schema_test.dart
- command: `dart test test/plugins/state/state_output_schema_test.dart`
- exit: 1
- at: 2026-09-04T23:12:27.161390Z
- output:
```
00:00 +0 -1: order 5: outputSchema declares the full actual return shape (success / files: string[] / data.generatedFiles objects) [E]
  Expected: true
    Actual: <false>
  test/plugins/state/state_output_schema_test.dart 52:7
Failing tests:
  order 5: outputSchema declares the full actual return shape
Root cause: CreateStateCapability.outputSchema declares only
{files: {array of string}} while execute() returns an ExecutionResult
that also carries data.generatedFiles objects (path/type/action/content)
— the declared schema misdescribes the actual return shape.
```

- schema: 1
- prev-hash: genesis
- hash: f3e8920d5c78bd356b7ff1b89097c2f2769c08522b50145c3ca8285071d2658a

## Cycle: 976-json-envelope (green)

- behavior: 976-json-envelope
- kind: green
- criterion: SC-2
- test: test/plugins/state/state_create_json_receipt_test.dart
- command: `dart test test/plugins/state/state_create_json_receipt_test.dart`
- exit: 0
- at: 2026-09-04T23:21:16.058591Z
- output:
```
00:00 +0: SC-2a: --json emits the {path, fields[], modes[], flavor, schema:1} envelope as the last stdout line
00:00 +1: SC-2b: a real generation ships a proof.v1 receipt at .zfa/receipts/state-<entity>.json binding the final bytes
00:00 +2: SC-2c: zfa proof check covers the state artifact (green on a fresh generation)
00:00 +3: SC-2d: proof check goes red when a receipted state artifact drifts
00:00 +4: SC-2e: without --json the human output is unchanged (no envelope)
00:00 +5: All tests passed!
Implementation: first-party StateCreateCommand (manual subcommand via
PluginCommand.manualSubcommandNames) replaces the generic CapabilityCommand
for `zfa state create`: --json becomes the OUTPUT verdict flag
{path, fields[], modes[], flavor, schema:1} as the last stdout line (fields
parsed from the emitted constructor's this.<field> tokens — zero drift
from the bytes), and every real generation ships a proof.v1 receipt at
.zfa/receipts/state-<Entity>.json (ReceiptStore.save fileName:) binding
the final on-disk sha256.
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 1780f9a3e6a04d0cb8e9c8e1e0c95dcaebfacf3d00a41e07fd68c0ebfacaf0d9
- hash: bc37d5bbeb3408eaab36caa3a16c898f701bedefc2fe42339116d2850f440b02

## Cycle: 976-snapshot-goldens (green)

- behavior: 976-snapshot-goldens
- kind: green
- criterion: SC-3
- test: test/plugins/state/state_snapshot_test.dart
- command: `dart test test/plugins/state/state_snapshot_test.dart`
- exit: 0
- at: 2026-09-04T23:21:16.058591Z
- output:
```
00:00 +0: SC-3: the fixture matrix is byte-identical to the committed goldens (6 configs x 2 flavors)
00:00 +1: All tests passed!
Sequence (the neutrality proof):
1. Goldens captured from the PRE-dedupe builder (ZFA_STATE_UPDATE_GOLDENS=1)
   — 12 files under test/plugins/state/golden/ (6 configs x 2 flavors).
2. Baseline run pre-dedupe: green (the suite captures the builder output
   exactly).
3. Dedupe applied: the 6 needsEntityField/needsEntityListField derivation
   sites (generate + the 5 custom-mode builders) collapsed into the single
   _resolveEntityFieldNeeds resolver.
4. Post-dedupe run: green — every regenerated file is byte-identical to
   its pre-dedupe golden. AC-3 proven.
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 111dc449245c732f60c9dae6b279eee608f670e948bd6e416564223b066f5d48
- hash: 8e55154cd29a02b57666f9c1d40eeff2aca478681270a79c21f862c4c2e6fb50

## Cycle: 976-output-schema (green)

- behavior: 976-output-schema
- kind: green
- criterion: order-5
- test: test/plugins/state/state_output_schema_test.dart
- command: `dart test test/plugins/state/state_output_schema_test.dart`
- exit: 0
- at: 2026-09-04T23:21:16.058591Z
- output:
```
00:00 +0: order 5: outputSchema declares the full actual return shape (success / files: string[] / data.generatedFiles objects)
00:00 +1: order 5: a real execute() result validates against the declared schema shape
00:00 +2: All tests passed!
Implementation: CreateStateCapability.outputSchema now declares
success: boolean, files: array<string>, and
data.generatedFiles: array of {path, type, action, content} — the actual
return shape of execute(); the second test validates a REAL execute()
result structurally against the declared schema.
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: f3e8920d5c78bd356b7ff1b89097c2f2769c08522b50145c3ca8285071d2658a
- hash: 41cb00811d39779c9110ae555c5b855e5f902d9dffac98f5427a72bc1192ac16

## Cycle: 976-make-drift-gate (green)

- behavior: 976-make-drift-gate
- kind: green
- criterion: SC-4
- test: test/plugins/state/state_make_drift_test.dart
- command: `dart test test/plugins/state/state_make_drift_test.dart`
- exit: 0
- at: 2026-09-04T23:21:16.058591Z
- output:
```
00:00 +0: SC-4: state create ≡ make --state for methods [get,update]
00:00 +1: SC-4: state create ≡ make --state for methods [get,getList]
00:00 +2: SC-4: state create ≡ make --state for methods [create,update,delete,watch]
00:00 +3: All tests passed!
The drift gate landed green on the baseline (both entry points already
drove the same StateBuilder for the same explicit config) and now pins
byte-identity across the method-set matrix so the two entry points can
never silently diverge.
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: genesis
- hash: d425a4d378b73dcaa8d537cd2773c486a214fd637901c99b0d6ad2f33decb2c6

## Cycle: 976-prop-compile (green)

- behavior: 976-prop-compile
- kind: green
- criterion: SC-1
- test: test/plugins/state/state_property_compile_test.dart
- command: `dart test test/plugins/state/state_property_compile_test.dart`
- exit: 0
- at: 2026-09-04T23:21:16.058591Z
- output:
```
00:03 +1: SC-1a: the method-set matrix compiles clean (dart analyze, 0 issues)
00:05 +2: SC-1b: copyWith/==/hashCode round-trip and pagination defaults hold at runtime
00:23 +3: SC-1c (negative control): a deliberately broken copyWith emission FAILS the compile tier
00:26 +4: All tests passed!
The property tier landed green on the baseline (the builder's emissions
do compile) — it is a regression gate, and SC-1c proves it can fail:
corrupting one emission's copyWith to reference an undefined name makes
dart analyze exit 3 naming the exact symbol.
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: genesis
- hash: f36aaf4179db712ec4a39ce20520674fba8f15b4053890b48663d7398c499665

