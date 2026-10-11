# Bug Issue: tdd make hard-stops with generation-error on planner-declared hand-step behaviors

- **Slug**: 1568-hand-step-hard-stop
- **Fetched**: 2026-09-13
- **Issue**: 1568
- **URL**: https://github.com/arrrrny/zuraffa/issues/1568
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

### Dogfood evidence

zxscan (fresh barcode-scan host). The planner announces the hand-step up front:

```
zfa tdd plan: Seam cost: 10 of 14 unit behaviors will hand-step because return is an entity.
```

Driving those behaviors, `make` then hard-stops on the first one:

```
zfa tdd make: behavior U1
   …
   target test exit: 1
zfa tdd make: target test still fails after generation (exit 1).
make: behavior=U1 outcome=generation-error
run: result=stopped pending=18 red=1 green=12 done=0 stopped_at=U1:make
```

The subject is a `gen` contract-derived stub (`ScanSession scan() => throw UnimplementedError(…)`, issue #1259) and there is no generated implementation step for an entity-returning contract subject — unlike the entity pipeline's `wire` + certified mock (#1498/#1500), which greens entity-anchored units mechanically. So the test failing "after generation" is the expected, **pre-declared** hand-step state — not a generation defect.

### What's wrong

The planner and the driver disagree about the same behavior:

- **Planner**: predicts `hand-step` (and even quantifies it: 10 of 14).
- **Driver/`make`**: treats the same condition as `generation-error` and stops the entire run (`fail fast`).

Consequences:

1. A feature with any hand-step behavior can never drive its *mechanical* behaviors — the run stops at the first hand-step, so the remaining units/contracts are unreachable.
2. The operator gets `generation-error` for a condition the tool itself already classified as expected work — the classification tells them to look for a generation bug that does not exist.
3. Resume re-drives everything up to the same wall (see #1544's blocked-contract sibling: the run's resume semantics amplify every hard stop).

### Suggested fix

1. **First-class run state for hand-steps**: when the planner marked a behavior hand-step (entity-return contract subject, no mechanical implementation surface), `make` should report `outcome=hand-step` (or `parked`) — a non-fatal verdict that leaves the behavior PENDING with its honest red, records it in the run summary (`hand_steps=N`), and lets the run continue to the next behavior.
2. **Honest classification**: if a hand-step is out of scope for a given run configuration, that should be a `deferred`-style transition (like `unexpressible` → `deferred (phase 2)`), never `generation-error`.
3. **Report the count at run end**: name the hand-step behaviors in the final summary so the operator can implement them deliberately — the planner already knows which ones they are.

### Related

- #1565 — the scaffold-step refusal that masked this one (fixed on branch `fix/1565-func-contract-derived-noop`).
- #1544 — the run parks forever on a blocked contract (same "hard stop on an expected non-green state" family).
- #1551 — acceptance compose hard-stops when its anchor precondition is unmet (same family).

## Comments

**arrrrny**: Status check on master while triaging my filed issues — **leaving this one OPEN**, with a refined scope.

**What exists now (make level):** a designed hand-step path — `handStepHeader(id)` attestation + `make --born-green` (`make_command.dart:802`, models reference the #1308 hand-step contract, #1411 born-green gate). So an author can hand-implement a subject, mark the test with the attestation header, and certify it deliberately. That is a real improvement over the hard stop.

**What is still missing (run level):** no hand-step handling in `step_runner.dart` / `run_command.dart` — the driver still treats a hand-step behavior's `make` failure as `generation-error` and stops the run, so the mechanical behaviors scheduled behind it remain unreachable in a single pass (observed on the dogfood host: the run stopped at the first entity-return contract subject and could not proceed to the remaining units/contracts without out-of-band `wire` commands).

Scope for this issue is therefore narrowed to: give the planner's hand-step verdict a run-level state (parked/hand-step) so a feature with hand-steps still drives its mechanical behaviors in the same run, with the count named in the final summary.
