# Bug Assessment: [TDD-130] UI-intent classifier misses past-tense outcome verbs

- **Slug**: ui-past-tense-verbs-missed
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/936
- **Verdict**: likely valid, needs reproduction
- **Severity**: high (silent misrouting weakens generated widget coverage)

## Report

The UI-intent classifier `SpecParser.uiAcceptanceIntent` checks only imperative/present-tense verbs (`renders?`, `navigat(?:es|ion|ing)`). Past-tense Then-clauses — the dominant convention in Given/When/Then specs — silently fail to match, so widget scenarios land in the plain-function acceptance lane.

## Symptom

Acceptance scenarios like "an error message is rendered", "I am navigated to the home screen", "a loading indicator is shown", "the label is displayed" route to `## Outer loop: acceptance behaviors` instead of `## Outer loop: widget behaviors`. No error surfaces; the generated suite just loses its widget tests.

## Reproduction

`zfa tdd plan` on a spec whose Then-clauses use "is shown / is rendered / is displayed / is navigated": those rows land in the acceptance section while present-tense siblings ("renders", "navigates") land in the widget section.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/spec_parser.dart` — `uiAcceptanceIntent` regex:
  `r'\b(renders?|sidebar|bottom nav|tab bar|app bar|app shell|themes?|widgets?|navigat(?:es|ion|ing))\b'`
- `test/plugins/tdd/bug_830_widget_subject_kind_test.dart` — existing classifier coverage to extend.

## Root Cause Hypothesis

1. `renders?` followed by `\b` cannot match `rendered` (no boundary between `render` and `ed`).
2. `navigat(?:es|ion|ing)` lacks the `ed` conjugation.
3. `display(ed|s|ing)` and `shown|shows?` are absent from the alternation entirely.

## Proposed Remediation

Extend the alternation in `uiAcceptanceIntent`:

- `render(?:s|ed|ing)?`
- `navigat(?:e|es|ed|ion|ing)`
- add `display(?:s|ed|ing)?` and `shows?|shown`

Keep the `\b` word boundaries. No concept-set widening: "navigation" already matched; this only completes the verb conjugations and adds the two missing outcome verbs.

## Verification Plan

1. Past-tense fixture rows ("is rendered", "is navigated", "is shown", "is displayed") land in the widget section.
2. Present-tense siblings still route to widget (no regression).
3. A non-UI past-tense sentence ("the result is returned") still routes to the acceptance lane.
4. `dart test test/plugins/tdd/` green; `dart analyze` clean.

## Risks & Considerations

- Over-matching prose that merely mentions "shown" in a non-UI context (e.g. "the receipt is shown in logs") — acceptable per issue: the widget lane is the honest lane for display outcomes; wording stays in the spec author's control.

## Open Questions

- None blocking.
