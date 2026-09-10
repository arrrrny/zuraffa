# TDD Verification — Spec 1382 — Verdict: PASS (2026-09-09)

- Test-first: the pin was run against the untagged tree (stash-verified
  `+2 -1`) before the tags landed.
- Suite: `+3 All tests passed!`; analyze clean; format clean.
- Mutation sampling (executed): M1 — one file's regression tag removed →
  B1 red (killed). 0 survivors.
- Rejected alternative recorded: the spawn-based mismatch guard —
  inside the targeted tier it cannot distinguish the invocation shape and
  would recurse; the static pin + the documented preset are the honest
  pair.
- Epic-side follow-up: update exit criterion 1 to
  `dart test --preset=regression` (recorded on the issue).
- AC coverage: AS-1→tier-existence, AS-2→B1, AS-3→B2.
