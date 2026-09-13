# Cycle Log: tdd-doctor-feature-positional (#1585)

Fixture: `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` (@Tags(['slow']);
run via `--preset=all`, the only lane that includes the slow tier).

## Cycle: baseline — the issue's repro on the pre-fix tree (helper passes `--feature`)

- behavior: U1585-1 (helper invocation form)
- kind: red
- classification: usage error (`Could not find an option named "--feature"`)
- test: test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
- exit: 1
- at: 2026-09-13 (macOS, Dart 3.13.x)
- output:
```
02:38 +9 -4: Some tests failed.

  ❌ Could not find an option named "--feature".
  Usage: zfa tdd doctor <feature> [--repair] [--project <path>]
  ...
  test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart 429:7  main.<fn>.<fn>

Failing tests:
  ... doctor detects a tampered hash chain and prescribes a fix
  ... a pending journal is reported as an interrupted transaction with a fix line
  ... doctor exits 0 on consistent stores
  ... doctor reports a green claim without evidence as drift and prescribes the resume fix
```
- result: red for the RIGHT reason — `DoctorCommand` declares only `--json` / `--repair` /
  `--project` and reads the feature from `argResults.rest`; the helper's `--feature`
  never reaches the drift logic. Introduced by the `b6afda42` (#840) rework that moved
  doctor from `--feature` to the positional form; this helper (born at `1183009e`) was
  never updated. Every other caller in the repo already passes the feature positionally.

## Cycle: post-helper-fix — two deeper disagreements surface (pre-fix for 3c / the envelope pin)

- behavior: U1585-3 (restored chain walk), U1585-4 (envelope-form healthy pin)
- kind: red
- classification: missing drift detection (tamper invisible) / stale output-format assertion
- test: test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` (helper fixed, doctor unchanged)
- exit: 1
- at: 2026-09-13
- output:
```
02:16 +11 -2: Some tests failed.

  zfa tdd doctor (drift reporting with fix lines) bug 828 RED: doctor exits 0 on consistent stores [E]
    Expected: contains 'drifts=0'
      Actual: 'zfa tdd doctor: feature 090-bug-828 (specs/090-bug-828/tdd)\n'
                '  stores agree — no drift detected\n'
                '{"command":"doctor","feature":"090-bug-828","verdict":"healthy","prescription":"none","drifts":[]}\n'
       Which: does not contain 'drifts=0'
    test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart 333:7

  versioned evidence schema with per-behavior hash chain bug 828 RED: doctor detects a tampered hash chain and prescribes a fix [E]
    Expected: <1>
      Actual: <0>
    zfa tdd doctor: feature 090-bug-828 (specs/090-bug-828/tdd)
      stores agree — no drift detected
    {"command":"doctor","feature":"090-bug-828","verdict":"healthy","prescription":"none","drifts":[]}
    test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart 430:7
```
- result: the usage error had masked TWO deeper defects:
  1. `doctor` no longer verifies the evidence hash chain — a tampered schema-1 entry
     (`- exit: 1` → `- exit: 2`) reads as "stores agree". The walk existed at
     `1183009e` (`_verifyChain`: every `prev-hash` must link, every `hash` must equal
     the recomputed digest) and was dropped by the `b6afda42` rework; the surviving
     `cycle_log.dart` doc still promises it ("The doctor recomputes this from the
     parsed entry and reports any mismatch as drift with a fix line") and
     `payloadFromFields` is documented as "the doctor's view of a rendered entry".
  2. the `doctor: feature=<f> drifts=<n>` summary line was replaced by the verdict
     envelope (bug #840 / issue #969) — the zero-drift pin must read `drifts: []`
     from the final machine line, the idiom every sibling doctor suite uses.

## Cycle: GREEN — the fix on the working tree (13/13)

- behavior: U1585-1 … U1585-5
- kind: green
- classification: pass
- test: test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
- exit: 0
- at: 2026-09-13
- output:
```
04:42 +8: ... doctor reports a green claim without evidence as drift and prescribes the resume fix
04:46 +9: ... doctor exits 0 on consistent stores
04:50 +10: ... a pending journal is reported as an interrupted transaction with a fix line
04:55 +11: ... entries written through CycleLog carry schema + hash chain lines and chain per behavior (red -> green)
05:00 +12: ... doctor detects a tampered hash chain and prescribes a fix
05:05 +13: All tests passed!
```
- result: 13/13 — the four usage-error tests now exercise the drift logic; the
  tampered entry is caught by the restored walk (`hash chain broken … recomputed
  hash … != recorded …`), and the consistent-store pin reads the envelope.

## Cycle: static analysis + format

- command: `dart analyze lib/src/plugins/tdd/commands/doctor_command.dart test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
- output: `No issues found!`
- command: `dart format lib/src/plugins/tdd/commands/doctor_command.dart test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
- output: `Formatted 2 files (0 changed) in 0.18 seconds.`

## Cycle: verification — mutation sampling on the restored walk

Changed-file mutant sampling (`tdd.verify` Phase 4 fallback; no mutation tool
wired in CI — see `.specify/memory/tdd-profile.md`).

### M2 — linkage arm dropped (`if (false && entry.prevHash != prev)`)

- behavior: U1585-6 (linkage pin, added during verification)
- kind: verify
- classification: mutant KILLED
- command: `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart --plain-name "broken prev-hash LINKAGE"`
- output:
```
  Expected: <1>
    Actual: <0>
  zfa tdd doctor: feature 090-bug-828 (specs/090-bug-828/tdd)
    stores agree — no drift detected
00:05 +0 -1: Some tests failed.
```
- result: killed — with the linkage arm gone the severed trail reads healthy
  (the content arm alone cannot see it, because the walk's local `prev` is
  still genesis). Mutant reverted; pin re-run green.

### M1 — the whole gate disabled (`chainDrifts = <String>[]`)

- behavior: U1585-3 + U1585-6
- kind: verify
- classification: mutant KILLED
- command: `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart --plain-name "hash chain"`
- output:
```
exit=1
Failing tests:
  ... doctor detects a broken prev-hash LINKAGE (the reordered/edited trail) and prescribes a fix
  ... doctor detects a tampered hash chain and prescribes a fix
```
- result: killed — both hash pins fail with the walk removed. Mutant reverted.

### Final green on the reverted tree

- command: `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
- exit: 0
- output:
```
04:47 +11: ... entries written through CycleLog carry schema + hash chain lines and chain per behavior (red -> green)
04:50 +12: ... doctor detects a tampered hash chain and prescribes a fix
04:54 +13: ... doctor detects a broken prev-hash LINKAGE (the reordered/edited trail) and prescribes a fix
04:57 +14: All tests passed!
```
- result: 14/14 (the 13 pre-existing behaviors + U1585-6).
