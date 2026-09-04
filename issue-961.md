## Summary

The **slice plugin** (feature 043 — `cut`/`export`/`merge`/`verify` capabilities, "context-isolated codebase extraction") has never been used on a real project. It is exactly the missing piece for the ZikZak rebuild: **develop a feature in an isolated, runnable sandbox — never boot the whole app — then merge back**.

## The workflow this issue delivers

```
zfa slice cut --feature login --from zik_zak
  → sandbox project: app shell + login's spec/tdd artifacts + certified mocks
  → agent drives the FULL tdd loop there (plan/gen/red/make/view/refactor)
  → suite green in isolation; no whole-app runs, no unrelated breakage

zfa slice verify
  → contract check: the slice is self-contained, mocks certified, coverage complete

zfa slice merge --into zik_zak
  → lands behind the host's DI + router; host conformance gates run
```

## What exists vs what's missing

- Slice capabilities exist (`lib/src/plugins/slice/capabilities/`: cut, export, merge, verify) — **unproven on ZikZak**, never exercised end to end.
- The tdd loop, mock-first make, `tdd view`, corpus baseline reuse (#953) — proven this week on the login rail.
- Missing: the cut step producing a **runnable** sandbox (app shell + go_router harness + mock DI so `flutter run`/widget tests work standalone), the verify step asserting slice self-containment, and the orchestration tying slice ↔ tdd (a feature developed in a slice should carry its journal/registry through merge).

## Acceptance (prove with login)

1. `zfa slice cut` on the login feature yields a sandbox where `zfa tdd run <feature>` completes and `flutter run -d macos` boots the feature on certified mocks alone.
2. `zfa slice verify` exits 0 with a JSON verdict (self-containment, mock certification, suite state).
3. `zfa slice merge` lands login in the host repo with zero hand-edits; host suite green after merge.
4. The whole flow works for an agent with no knowledge of the host app beyond the spec — isolation is the point.

## Why

Feature development against a 44-spec app means every loop step pays the whole-app suite tax and every mistake risks unrelated breakage. Isolation makes agents parallel-safe and the loop fast. The plugin is already built — this is a proving + completion pass, not new invention.

VISION: §5 (token economics — the loop sees only its slice), §6 (the repo is memory — journals travel with the slice), §9 (simulation worlds).

