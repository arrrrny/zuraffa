# Test List: 1430-refactor-refresh-evidence

Derived from spec.md + plan.md (speckit.tdd.plan fallback — the repo has no
`.zfa.json`, so the LLM-guided derivation applies). Every behavior gets a
failing test BEFORE its implementation lands (red-green-refactor).

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-1430-1 | a behavior certified green whose subject the refactor pass rewrote and whose re-proof ran green over a covering scope RESUMES clean: the make already-green transition accepts the reformatted subject and prints the `subject drift accepted (issue #1430)` provenance note — no `subject-drift` refusal, no manual `--re-certify` | FR-001, FR-002 | PENDING |
| A-1430-2 | after the refactor pass, the last green-or-refresh evidence hash for every touched certified behavior equals the on-disk subject's sha256 — the certified evidence and the disk never disagree about a rewrite the loop performed and re-proved | FR-001 | PENDING |
| A-1430-3 | a certified subject changed after certification by anything OTHER than the loop's refactor pass still refuses with the byte-identical `subject-drift` diagnosis (basis, certified vs current hash, issue #1036 citation, #1162 remedy) | FR-003 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1430-1 | after a GREEN re-proof whose scope covers a touched behavior's test, the refactor command appends one `## Cycle: <id> (refresh)` entry per rewritten certified subject carrying the post-rewrite `subject-hash`, the re-proof command/scope, and the behavior's criterion; when any certified subject was touched the re-proof is forced FULL with the `[refactor] certified subject(s) rewritten — forcing full re-proof (issue #1430)` note | FR-002, FR-005 | PENDING |
| U-1430-2 | a refactor rewrite that breaks the suite stops via the existing re-proof failure reporting and appends NO refresh entry — no green-washing | FR-004 | PENDING |
| U-1430-3 | a refactor pass that touches no certified subject produces exactly today's observable effects (the refactor cycle entry, receipts refresh) and zero refresh entries, with no forced full re-proof | FR-005 | PENDING |
| U-1430-4 | the subject of a NOT-certified (pending or red-only) behavior touched by the pass lands no refresh entry; the next certify stamps the then-current hash naturally | FR-002, FR-005 | PENDING |
| U-1430-5 | several certified subjects rewritten in one pass → one refresh entry per touched behavior under the same green-re-proof gate | FR-001, FR-002 | PENDING |
| U-1430-6 | the guard's honesty edges: a refresh entry older than the live green certification does not accept (out-of-band edit back to a previously refreshed shape refuses); a refresh whose hash ≠ the current hash refuses; the #1162 red-basis implemented-drift fail-open, the born-green placeholder refusal, and the #1331 tombstone re-drive behave unchanged | FR-003, FR-006 | PENDING |

## Layer contracts

```yaml
# fr: FR-002, FR-004, FR-005
refactor_command.dart: post-re-proof refresh reconciliation (changed-file → certified-subject map, refresh appends, full-re-proof forcing)
# fr: FR-003, FR-006
make_command.dart: _subjectDriftRefusal refresh consult (hash match + ISO-8601 freshness, fail closed)
# fr: FR-001, FR-002
cycle_entry.dart: CycleEntryKind.refresh + label + rendering (subject-hash field line; never generation/suite/actions blocks)
```

## Key entities

```yaml
CycleLogEntry: kind gains refresh; subjectHash carries the post-rewrite sha256; behaviorId is the real behavior id (unlike feature-level refactor entries)
ParsedCycleEntry: unchanged — the generic `- kind: (\S+)` parse already reads refresh
```

## Suite entry points

- `test/plugins/tdd/commands/bug_1430_refresh_evidence_test.dart` (new — all
  nine behaviors; hermetic temp feature fixtures per the 1432 pattern)
- Existing make/refactor/run-driver suites for the regression pins
  (T014/T015, U-1430-6 neighbors)
