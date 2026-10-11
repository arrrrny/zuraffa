# Bug Issue: zuraffa spec authoring grammar never reaches a spec-kit project

- **Slug**: 1480-spec-grammar-propagation
- **Fetched**: 2026-09-10T22:29:32Z
- **Issue**: 1480
- **URL**: https://github.com/arrrrny/zuraffa/issues/1480
- **State**: open
- **Severity**: critical (task brief; no severity:* label — labels: bug, tdd, track-tdd-loop, spec-drift, missing-integration)
- **Author**: arrrrny
- **Labels**: bug, tdd, track-tdd-loop, spec-drift, missing-integration

## Body

## Summary

zuraffa's spec authoring grammar (`## Layer Contracts` + indented `traces:` continuation lines) **never reaches a project scaffolded by spec-kit**. The `.specify/templates/spec-template.md` that `speckit-specify` installs is the stock spec-kit template and contains none of the grammar, and no zfa verb installs zuraffa's own template into a consumer project.

Consequence: a spec authored strictly per the installed template — passing every spec-kit specification-quality gate — is guaranteed to dead-end the unit lane. Nothing warns the author until ~28 minutes into `zfa tdd run`.

## Repro

Fresh Flutter project, spec authored end-to-end by the spec-kit chain (`speckit-specify` → `speckit-plan` → `speckit-tasks`), feature `001-todo-app` (21 FRs, 21 acceptance criteria, "classic todo app").

```bash
# The template the project actually receives:
grep -c '## Layer Contracts' .specify/templates/spec-template.md   # 0
grep -c 'traces:'            .specify/templates/spec-template.md   # 0
wc -c .specify/templates/spec-template.md                          # 4556  (stock spec-kit)

# zuraffa's own template, which DOES have the grammar:
wc -c <zuraffa-repo>/.specify/templates/spec-template.md           # 9272

zfa tdd plan 001-todo-app
zfa tdd run  001-todo-app --timeout 25
```

## Expected

Either the grammar template is installed into the project when zfa wires it up (so `speckit-specify` authors transitively get the contract/trace sections), or the spec↔contract mapping is held somewhere other than `spec.md` so that a spec-kit-authored spec works out of the box.

## Actual

All 42 behaviors fallback-route, then the run dies on the first unit `make`:

```
run: feature=001-todo-app result=stopped pending=20 red=19 green=1 done=0 stopped_at=U1:make
```

journal `engine/drive`: `started_at 21:27:01.456999Z` → `finished_at 21:55:03.685677Z` (**27m41s**), `counts total=40 red=19 green=1 done=0`.

```
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
[run] U1 gen -> ok
[run] U1 verify-red -> certified
[run] U1 make -> vacuous-green
```

## Root cause

The declared-routing path reads contract rows only from `spec.md` (`## Layer Contracts`, the `## Key Entities` pipe table, `## External Dependencies & Contracts`). No zfa verb ships or installs a template carrying those sections into a spec-kit project. `#1183` and `#1186` were closed by editing **zuraffa's own repo-local** `.specify/templates/spec-template.md` (PR #1217, PR #1227); nothing propagates that template to a consumer. `#1417` and `#1466` cover spec-kit boundary *scripts*, not the authoring grammar.

The asymmetry is the sharp part: the **acceptance lane self-heals** — the planner's one-time `**Type**:` marker migration writes the missing markers — but the **unit lane can never self-heal**, because a contract row name is authoring intent that no classifier can invent. `doc/BREAKING_CHANGES.md:62-73` says as much: *"Unit behaviors still need an author-declared contract trace: a classifier cannot invent a row name."* An FR is mandatory and always derives a unit row (`spec_parser.dart:249`), so **every** spec-kit-authored spec is guaranteed to hit this.

## Suggested fix

The maintainer's stated preference, recorded verbatim: *"I want a seamless tdd cycle, that works out of the box with specify specs, zfa tdd custom parsing and expectations should be either held in a different file mapping to spec or some other mechanism."*

Concretely, in rough order of leverage:

1. **Decouple the mapping from `spec.md`.** Read the spec↔contract mapping from a separate file (see the companion issue about `contracts/*.md`, which the planning phase already writes) instead of requiring hand-authored zuraffa grammar inside the spec body.
2. **Make `zfa tdd plan` fail fast** when any unit behavior would fallback-route (see the companion issue on plan exiting 0 on an all-fallback spec), so the author learns in seconds, not after a 28-minute run.
3. If the grammar must stay in `spec.md`, **install zuraffa's authoring template** into the project at wiring time and assert on it, rather than relying on docs the author never opens.

## Environment

zfa v6.2.2 / zuraffa 6.2.2 · Flutter 3.47.2 · Dart SDK ^3.13.2 · macOS · project scaffolded by spec-kit
Related: #1183 (CLOSED), #1186 (CLOSED), #1417 (OPEN), #1466 (OPEN), #1308 (CLOSED), #1259, #1320 (CLOSED)


## Comments

None.
