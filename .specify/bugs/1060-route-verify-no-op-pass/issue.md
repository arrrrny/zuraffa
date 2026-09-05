# Issue: [HONESTY] zfa route verify is a permanent no-op PASS — drift walkers never landed

- **Issue**: #1060
- **Severity**: critical
- **Epic**: #1011 (TRUTH-FLOOR invariant)
- **Status**: fixed by this branch

## Bug

`zfa route verify` (PR #1025) has the right surface — `RouteDriftDetector`
compares CLI vs DDA `RouteEntry` tables by path and returns per-overlap
drift — but the verdict pipeline never distinguishes honest outcomes. On any
real project:

- a project with **no route inputs at all** prints `routes: 0, drift: 0`
  and exits 0 — a PASS;
- a project with **only one system present** prints `routes: N, drift: 0`
  and exits 0 — a PASS;
- a project with **drift but without `--strict`** exits 0 — a PASS.

A lie-certifying PASS — exactly what the TRUTH-FLOOR invariant (epic #1011)
forbids.

## Verified state (this repo, branch point 77e69f24)

- `RouteDriftDetector` is pure and tested (U2.1–U2.5) — overlap = finding.
- The file-discovery walkers landed with spec 0971 (commit 31e7b012):
  `zfa_router.g.dart` → DDA side, `*_routes.dart` (≠ `app_routes.dart`) →
  CLI side. What never landed is the **verdict layer**: no verdict set, no
  per-verdict exit codes, no one-sided path findings, no `--strict`
  escalation for missing inputs, no missing-input naming. Reproduced on
  this branch's base (see tdd/cycle-log.md, Baseline RED evidence).
- `*_shell.dart` modules emitted by `zfa route shell` contain
  `StatefulShellRoute` branch `GoRoute(path: ...)` declarations that the
  walker ignored — CLI-emitted registrations invisible to verify.

## Orders

1. Implement the two walkers feeding `RouteDriftDetector`:
   CLI-side — parse generated route registrations
   (`zfa_router.g.dart` or wherever `zfa route` emits);
   DDA-side — parse hand-written `*_routes.dart` (go_router configuration).
   Both must tolerate the project not having one side: that is a drift-class
   finding or an explicit insufficient-input verdict — never a silent PASS.
2. Define the honest verdict set: `match | drift | insufficient-input`,
   each with distinct exit codes (document in help output).
   `insufficient-input` MUST be distinguishable from `match` in both text
   and `--json` output.
3. Make `--strict` meaningful: with `--strict`, `insufficient-input` fails
   the run.
4. Tests: fixture project with (a) matching systems → match, (b) path
   present in one system only → drift with offending path named, (c) missing
   either input → insufficient-input. Assert exit codes for all three.
5. Run ONLY route plugin scoped suite plus new tests:
   `dart test test/plugins/route/`. Do NOT run full suite.

## Hard constraints

- No new dependencies; hand-rolled parsing consistent with existing route
  plugin code.
- Do not change `RouteDriftDetector`'s pure API — feed it.
- This closes the loop on #971 (route A+): #1046 builds on verify.

## Acceptance criteria

- verify detects real drift on fixture with mismatched route tables
- verify emits insufficient-input (not PASS) when inputs missing, with
  distinct exit code
- All three verdict classes covered by tests, exit codes pinned
- Scoped route suite green
