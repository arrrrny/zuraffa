# MD Doctor

Agents scatter `.md` files across projects — design docs, plans, handoffs,
decisions. They go stale, and then **false**. A new agent reads them as fact and
builds on a lie. MD Doctor diagnoses every tracked/untracked `.md` in a repo, grades
how truthful it is against *living* ground truth, and remembers each run so a later
run re-evaluates what actually changed.

Ground truth is not the docs — it is:

- **git** — what was really committed, and when (creation + last-modified dates).
- **`.memsearch`** — the daily records of what agents actually did.
- **TDD** (optional) — `specs/*/tdd/verification.md` verdicts and `test-list.md`
  behaviors. A doc claiming a behavior TDD shows failing is marked **false**.

## Install

```bash
# From a checked-out copy of speckit-extensions (dev install):
specify extension add --dev md-doctor

# Then, inside a project:
specify init
```

Or register this repo's `catalog.json` as a custom catalog and run
`specify extension install md-doctor` once published. The `tdd` extension is pulled
in automatically when `tdd_integration` is on (the default).

## Usage

```
/speckit.md-doctor.init     # bootstrap config + snapshot baseline ground truth
/speckit.md-doctor.scan     # deep-diagnose: grade every .md 0-100, suggest actions
/speckit.md-doctor.drift    # re-evaluate since last run (git/.memsearch/tdd delta)
/speckit.md-doctor.report   # health summary + action queue
/speckit.md-doctor.apply    # apply suggestions (safe by default; --delete to remove)
```

Typical loop: `init` once, then `scan` any time docs may be stale, `drift` a week
later to see what moved, `report` for a glance, `apply` to act.

## How scoring works (truthfulness, 0–100)

For each file:

- **Freshness (0–40)** from the last-modified age: ≤7d → 40, ≤30d → 28, ≤90d → 16,
  ≤180d → 6, older → 0. Capped at the age of any newer TDD/`.memsearch` entry that
  supersedes the doc's claims.
- **Accuracy (0–60)** from claim-checking. Extract the doc's factual claims, then
  mark each `verified` / `unverifiable` / `contradicted` against ground truth.
  `accuracy = 60 * verified / total`, and **any** contradiction forces `accuracy = 0`.
- **Truthfulness = freshness + accuracy.**

Verdicts: `truthful` (≥80, no contradiction), `stale` (50–79), `false` (<50 or any
contradiction), `obsolete` (references code/features that no longer exist).

Suggested actions: `keep` / `update` / `delete` / `create` (a missing doc the repo
clearly expects).

## State

All under `.specify/md-doctor/`:

- `state/last-run.json` — last run's HEAD, timestamp, summary, actions taken.
- `state/ground-truths.json` — the baseline (HEAD, TDD verdicts, `.memsearch` files).
- `state/facts.json` — per-file grades, claims, verdicts, suggested actions.
- `reports/<run-id>.md` — one human report per run.

`drift` reads `last-run.json` + `facts.json` to compute the delta and re-grade, so it
knows exactly what was true last week, what shipped since, and which old suggestions
were resolved or ignored.

## TDD integration

When `tdd_integration: true` (default in `md-doctor-config.yml`), every `scan` and
`drift` reads the TDD extension's `verification.md` verdicts and `test-list.md`
behaviors as ground truth. There is also an optional `after_verify` hook that offers
to refresh ground truth with a `scan` right after `/speckit.tdd.verify` — off by
default, because it is a prompt, not a gate.

## Safety

`apply` is conservative: by default it only creates stubs for missing docs and stamps
verified ones. Deletion requires `--delete` (destructive, working-tree only until
committed). `scan` and `drift` never edit your `.md` files — they only read them and
write MD Doctor's own state.

## License

MIT. See [LICENSE](LICENSE).
