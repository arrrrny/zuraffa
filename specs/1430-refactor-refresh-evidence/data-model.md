# Data Model: 1430-refactor-refresh-evidence

## Entity: `CycleLogEntry` (extended)

Append-only row of `tdd/cycle-log.md` (`lib/src/plugins/tdd/models/cycle_entry.dart`).

| Field | Type | Change |
| ----- | ---- | ------ |
| `kind` | `CycleEntryKind` | **gains `refresh`** — one entry per touched certified behavior, appended by the refactor command after a green re-proof covering the behavior's test |
| `subjectHash` | `String?` | carried by refresh entries: the sha256 of the post-rewrite subject (the same field red/green entries carry; renders as `- subject-hash:`) |
| `behaviorId` | `String` | the REAL behavior id (unlike feature-level refactor entries' `<feature>-refactor`) so `lastEntryFor(<id>, kind: 'refresh')` resolves |
| `runnerCommand` | `String` | the re-proof command that witnessed the new shape green |
| `exitCode` | `int` | the re-proof exit (0) |
| `capturedOutput` | `String` | a short refresh note (touched subject path, old→new hash, re-proof verdict) |
| `sourceCriterion` | `String` | the behavior's criterion (same value its green entry carries, when resolvable) |
| `testPath` | `String` | the re-proof scope actually run |
| `classification` | — | null (only red entries carry one; the ctor assert stays `kind != red \|\| classification != null`) |

Rendering: `## Cycle: <id> (refresh)` + the standard field lines; the
`generation:`/`suite:` blocks stay green-only; `actions:` stays
refactor-only. Chain participation: `CycleLog.append` hash-chains it like
any entry (`lastHashFor` already matches any hashed entry per behavior).

## Entity: `ParsedCycleEntry` (no change)

`cycle_evidence.dart` parses `- kind: (\S+)` generically and carries
`subjectHash` already — a `refresh` entry parses with zero parser edits.
New read: `lastEntryFor(<id>, kind: 'refresh')` (existing API, new kind
argument).

## Entity: `MakeCommand._subjectDriftRefusal` state machine (extended)

```
currentHash = sha256(subject on disk)            (null → fail open, unchanged)
certified   = lastGreen.subjectHash ?? lastRed.subjectHash
            (both null → fail open, unchanged)   (unchanged)
currentHash == certified → ACCEPT                (unchanged)
+ NEW (issue #1430): lastRefresh = lastEntryFor(id, kind: 'refresh')
+     accept when lastRefresh.subjectHash == currentHash
+       AND refresh.at parses AND refresh.at > basis.at
+       (any parse failure → keep the refusal, fail closed)
+     acceptance prints the #1430 provenance note
red-basis #1162 fail-open (implemented-subject)   (unchanged, order preserved)
born-green placeholder / tombstone #1331 hatches  (unchanged)
refusal text (basis, hashes, #1036, #1162 remedy) (unchanged)
```

## State transitions of a behavior's subject evidence

```
certify green(hash H1)
  └─ refactor pass rewrites subject → disk hash H2
       ├─ OLD: resume → subject-drift refusal (stale-artifacts dead end)
       └─ NEW: pass appends refresh(H2) after green re-proof
            └─ resume → guard accepts (H2 == refresh.subjectHash, newer than green)
                 └─ out-of-band edit → disk hash H3 ≠ refresh H2 → refusal (unchanged)
```

## Invariants

- I1: cycle-log history is never edited; reconciliation is append-only.
- I2: a `refresh` entry never satisfies `greenEvidence()` / red+green
  certification contracts (#1329 precedent).
- I3: no refresh without a green re-proof covering the touched behavior's
  test (touched certified subjects force the full re-proof).
- I4: every refusal that fires today fires identically after this feature
  except the loop-caused drift the refresh entry proves green.
