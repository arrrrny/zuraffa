# Contract: refactor-pass evidence refresh (issue #1430)

## CLI surfaces (unchanged shapes, new guarantees)

```console
$ zfa tdd run <feature> [--project <dir>]
$ zfa tdd refactor <behavior> --feature <feature> [--project <dir>] [--full-reproof]
$ zfa tdd make <behavior> --feature <feature> [--project <dir>]
```

No flags are added or removed. Exit codes are unchanged.

## `zfa tdd refactor` — post-re-proof reconciliation (new behavior)

When the pass registry's rewrite changed files, the command — after a GREEN
re-proof — maps every changed file under `lib/` to the feature's behavior
subject paths. For each mapped behavior that has certified green evidence
whose recorded subject-hash differs from the post-rewrite hash, it appends
one `refresh` cycle-log entry per behavior:

```markdown
## Cycle: <id> (refresh)

- behavior: <id>
- kind: refresh
- subject-hash: <post-rewrite sha256>
- criterion: <criterion>
- test: <re-proof scope actually run>
- command: `<re-proof command>`
- exit: 0
- at: <ISO-8601 UTC>
- output:
```
refresh (issue #1430): the pass rewrote <subject path> (hash <old8>… →
<new8>…); the re-proof above proved the suite green over the new shape —
the certified evidence re-binds to it.
```
```

Preconditions, per touched behavior:

- the behavior has certified green evidence (`kind: green` entry);
- the recorded hash differs from the post-rewrite hash (equal → nothing to
  reconcile, no entry);
- the re-proof ran green over a scope covering the behavior's test. The
  scope decision is the pre-#1430 one, unchanged: when the pass is scoped,
  the covering-test mapping sends every changed registered subject to its
  OWN paired test (each candidate's test exercised by construction); every
  other green path is the full suite.
- the re-proof failed → the existing failure path fires unchanged; NO
  refresh entry is written (no green-washing).

Behaviors with no certified green evidence (pending/red) are never
refreshed. A pass that changes no certified subject writes exactly what it
writes today (FR-005). A refused, misfired, or regressed pass reconciles
nothing — every failure path returns before the reconciliation.

## `zfa tdd make` — the #1036 guard consults the refresh (new accept path)

`_subjectDriftRefusal` keeps today's rule order and adds one arm before the
refusal: when the behavior's LAST `kind: refresh` entry carries a
`subject-hash` equal to the current on-disk hash AND is newer than the
certified basis entry (ISO-8601 `at`; unparseable → refusal stands), the
skip proceeds, printing:

```text
   subject drift accepted (issue #1430): the current subject shape is the
   one the loop's refactor pass re-proved green (refresh evidence at <at>)
   — the certified evidence re-binds to it.
```

Every refusal that fires today still fires byte-identically otherwise:
out-of-band edits, born-green placeholders (#1036), tombstone re-drives
(#1331), and red-basis implemented-drift (#1162) semantics are unchanged.

## Cycle-log grammar (additive)

`- kind: refresh` joins `red | green | refactor | error` in the
`## Cycle:` sections. Parsing (`parseEntries`), the hash chain, and
`lastEntryFor` accept it with no grammar change. Certification contracts
keyed on red+green never observe it (#1329 precedent: a refresh entry is
never a green entry).

## Invariant summary

1. Append-only: no cycle-log history is ever edited.
2. No proof, no refresh: the only new accept path is witnessed by a green
   re-proof recorded in the same feature's cycle log.
3. Freshness: a refresh re-binds only shapes newer than the certification
   it reconciles; an older refresh never overrides a newer green.
