# Bug Assessment: tdd engine lane certifies vacuous greens (#1259 reproduces post-fix)

- **Slug**: 1651-vacuous-green-unit-dummies
- **Created**: 2026-09-15
- **Source**: https://github.com/arrrrny/zuraffa/issues/1651
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

`zfa tdd run` certifies `result=complete, done=10` on the zcalc probe while all four
unit subjects on disk are func-scaffolded dummies (`return 0;` / `return 0.0;`). This
is the same bug class #1259 reported (closed as fixed), reproducing verbatim on
`master` f011e3fb. The post-#1259 unit test asserts the return **type**
(`expect(result, isA<int>())`) on top of the UnimplementedError guard, but the #1517
func pass rewrites the throwing stub to `return 0;`, which satisfies a type
assertion → terminal green is certified with no real implementation. The engine
receipt reports `complete` with `done=10`.

Reporter's concrete asks:

1. Derive example-based assertions from the spec's acceptance scenarios for unit
   behaviors (call `subject_u1(2, 3)`, expect `5` — not `subject_u1(0, 0)` + type check).
2. Refuse terminal green for placeholder bodies (require the test to discriminate —
   a `return 0;` dummy must fail).
3. Until then, mark such behaviors `vacuous` in the engine receipt rather than `done`.

## Symptom

Unit-lane behaviors reach terminal `green`/`done` while the subject under test is an
unimplemented func-scaffold dummy; the engine receipt counts them as complete.

## Reproduction

1. `zfa setup zcalc --dart` (fresh package).
2. Spec with Layer Contracts row `Calculator: add(int a, int b) -> int`, FRs tracing
   `Calculator.add`, acceptance Given/When/Then with concrete values (2 and 3 → 5).
3. `zfa tdd plan zcalc` → 10 behaviors (A1-A2, U1-U4, contract:A1-A4).
4. `zfa tdd run zcalc` (hand-remediate the two acceptance seams per the #1488 stop,
   implement the four contract seams per the #1007 stop — both designed hand steps).
5. Run completes: `result=complete pending=0 red=0 green=4 done=6` → final receipt
   `done=10`.
6. Inspect `lib/tdd/zcalc/u{1..4}_subject.dart`: all `return 0;`/`return 0.0;` dummies.

Probe kept on disk: `/Users/arrrrny/Developer/zfa_tdd_probe/zcalc`
(`run1..run5.log`, `specs/zcalc/tdd/journal.json`, `cycle-log.md`).

## Suspected Code Paths

[NEEDS CLARIFICATION — run /speckit-bug-assess to locate the code, or fill in manually.]

Initial pointers from the issue text:

- Unit-test generator (`zfa tdd gen` → unit behavior test emission): invents
  representative arguments `(0, 0)` + type-only assertion instead of using the spec's
  concrete Given/When/Then values.
- `zfa make` func pass (issue #1517 scaffold): rewrites throwing stubs to
  `return 0;` dummies.
- Engine receipt/certification: accepts a type-only assertion as discriminating
  evidence for `green`/`done`.
- Prior art: #1259 (original fix), #1483 (`vacuous-green-remedy-wrong-file`),
  #1626 (`acceptance-vacuous-remedy`).

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

Working hypothesis: the #1259 fix strengthened the generated assertion only to a
return-type check, which a `return 0;` dummy satisfies; nothing in the certify path
requires the assertion to discriminate a real implementation from a placeholder, and
the scenario values the generator already parses never reach the unit lane.

## Proposed Remediation

[NEEDS CLARIFICATION — run /speckit-bug-assess to propose a fix, or apply a fix
directly with /speckit-bug-fix.]

Candidate directions (from the issue's concrete asks): derive example-based
assertions from acceptance scenarios for unit behaviors, and/or refuse terminal
green when the passing test cannot discriminate a placeholder body, and/or emit a
`vacuous` marker instead of `done` on the engine receipt.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Regression family: #1259, #1483, #1626 — the remedy surface was touched before;
  changing certification may interact with existing stops (#1488 acceptance seam,
  #1007 contract seam).
- Receipt semantics are consumed by downstream migrations (zik_zak) — changing
  `done` semantics or adding `vacuous` markers affects consumers.

## Open Questions

- [NEEDS CLARIFICATION: which of the three asks (example-based assertions,
  discriminating-green gate, vacuous receipt marker) does the minimal fix cover, and
  which are follow-ups?]
