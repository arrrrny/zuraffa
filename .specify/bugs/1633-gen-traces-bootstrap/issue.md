# Issue — 1633 (bug_1388 B1 is unpassable as written)

GitHub: https://github.com/arrrrny/zuraffa/issues/1633

## Symptom

`test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart`
B1 ("traces drift forces regeneration carrying the new routing") was red
on master — it failed in the #1628 and #1629 merge runs — and was
unfixable as written, so it shipped `skip:`-ped until this rewrite.

```dart
expect(exitCode, 0, reason: output);            // passes — gen exits 0
final testFile = File(...).readAsStringSync();  // the file gen owns
expect(testFile, contains('adaptive_layouts')); // FAILS — guard-only stub
```

## Root cause

B1 seeded the registry **by hand** (`TddFixture.registerBehavior`), which
writes a record with **no `gen_fingerprint`** — and the #1388 gate
deliberately requires one:

```dart
// gen_command.dart — "Records written before the fingerprint existed
// carry none — the gate stays open for them"
final fingerprintDrift =
    record.genFingerprint != null && record.genFingerprint != genFingerprint;
```

A no-fingerprint record is a **legacy record**, and keeping reuse for
those is the shipped contract (the sibling suite pins it:
`issue_1388_gen_reuse_fingerprint_test.dart` U6 — "legacy records keep
byte-identical `reused` reuse"). For B1's fixture, gen correctly kept
reuse and the drift could never fire — regardless of the traces cell.

The sibling suite avoids this by bootstrapping through a **real plan +
gen** (`seedGuardOnlyPair`: spec.md → `tdd plan` → `tdd gen` — the
created record arms the fingerprint), then mutating the routing and
re-running gen.

## Fix direction taken (test-side, the issue's preferred option)

Rewrite B1/B2 to the sibling's bootstrap. See `fix.md`.
