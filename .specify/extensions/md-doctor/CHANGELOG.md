# Changelog

## 1.0.0 - 2026-08-31

- Initial release of `md-doctor`: a Spec Kit extension that diagnoses and grades
  the truthfulness of agent-written `.md` files against living ground truth.
- `md-doctor.init` — bootstrap config and snapshot the baseline ground truth
  (git HEAD, TDD verification verdicts, `.memsearch` daily records).
- `md-doctor.scan` (deep-diagnose) — for every tracked/untracked `.md` file,
  gather git creation/modification metadata, fact-check its claims against ground
  truth, grade truthfulness 0–100, and write per-file suggestions
  (`keep` / `update` / `delete` / `create`) plus a run report.
- `md-doctor.drift` (re-evaluate) — compute the week-over-week delta (git commits
  and changed files since the last run, new `.memsearch` records, refreshed TDD
  verdicts), re-score previously graded files, and report which past suggestions
  were resolved or are now stale/false/obsolete.
- `md-doctor.report` — render the health summary (average truthfulness, counts of
  truthful/stale/false/obsolete docs, and the update/delete/create action queue).
- `md-doctor.apply` — mechanically and safely apply suggestions: create stubs for
  missing docs and stamp verified docs by default; delete only with `--delete`.
- State lives under `.specify/md-doctor/` (`state/last-run.json`,
  `state/ground-truths.json`, `state/facts.json`, `reports/<run-id>.md`).
- Seamless TDD integration: reads `specs/*/tdd/verification.md` and
  `test-list.md` as ground truth (toggle via `tdd_integration`), and offers an
  optional `after_verify` hook to refresh ground truth after a TDD run.
