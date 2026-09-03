# Bug Issue: [TDD-130] UI-intent classifier misses past-tense outcome verbs (rendered/navigated/displayed/shown) — widget scenarios silently route to the plain-function lane

- **Slug**: ui-past-tense-verbs-missed
- **Fetched**: 2026-09-03
- **Issue**: 936
- **URL**: https://github.com/arrrrny/zuraffa/issues/936
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: (none)

## Body

The UI-intent classifier in the spec parser checks only imperative verbs ("render", "navigate", "display", "show"). When acceptance scenarios describe outcomes in past tense — "the task list is rendered", "the user is navigated to", "the label is displayed", "the banner is shown" — the classifier misses them and the widget scenario silently routes to the plain-function (func) lane instead of the widget lane.

## Comments

None.
