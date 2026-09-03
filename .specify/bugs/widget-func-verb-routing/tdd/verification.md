feature: widget-func-verb-routing (bug #950, slug widget-func-verb-routing)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: fix/widget-func-verb-routing @ 9abc40e4 (audit + strengthened pin committed after)
behaviors: 6
proven: 6
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 2/3 caught + 1 judged # deliberate mutants (no mutation tool in profile): guard-kind disabled CAUGHT (+3 -5, all five guard pins); reason-rewording-that-still-names-view SURVIVED (+8, judged non-load-bearing — the fallback triggers on summary.kind, not reason prose, and the assertions intentionally pin behavior + route naming, not phrasing); wrong-route-command in the reason CAUGHT (+7 -1) after pin 3 was strengthened during this audit. All restorations byte-exact (git checkout / diff = the 40-line fix only), suite re-green after each.
mutants_survived: 1 # the judged phrasing mutant above
suite: tdd plugin fast tier 879/879 (two full runs at HEAD, 0 failed); new fast pins 8/8; slow pins W-A1 1/1 and #939 regression lane 4/4 (--preset=all, single-file scoped); dart analyze on touched files clean

# TDD Verification: bug #950 — widget-kind rows never route to tdd func (kind outranks prose)

**Verdict: PASS.** All six behaviors' tests landed in git history BEFORE
the fix (test-only commit `becca94b` → fix commit `9abc40e4`), the
issue's exact CLI failure shape was reproduced at the real `zfa tdd
make` surface pre-fix and flips to certified green post-fix, no HIGH
smells, and the acceptance criteria are fully covered. One LOW finding
was found and remediated inside the audit (pin 3 strengthened to pin
the route command itself).

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| W-A1 — a widget-kind make whose description says "renders" reaches green through the view-builder lane (tdd view dispatched, never tdd func, exit 0) | PROVEN | RED pre-fix: `+0 -1` with the issue's exact shape (`plan: 2 step(s)` → `tdd func` → `outcome=generation-error`, exit 1; ./tdd/red-evidence.md + cycle-log). History: test-only `becca94b` precedes fix `9abc40e4`. Post-fix: `+1` green — `widget lane: view-builder generation`, dispatch `[tdd view A-100 …, build]`, no `tdd func` anywhere, `## Cycle: A-100 (green)` appended |
| W-U1 — planner returns unexpressible for widget-kind + renders (all inflections); reason names the view lane | PROVEN | RED pre-fix `+4 -5` (`Expected: false Actual: <true>` — the row WAS expressible as a func scaffold); post-fix green; `render`/`rendered`/`rendering` all pinned off the func surface |
| W-U2 — the widget guard outranks the `U<n>` id-prefix dispatch | PROVEN | RED pre-fix (U-id widget row expressible via func); post-fix unexpressible with the widget reason |
| W-U3 — the widget guard outranks the entity/CRUD description branches | PROVEN | RED pre-fix (passed only via the #758 stop whose reason lacked the widget naming — the discriminator assertion failed); post-fix the guard's own reason is asserted; prose chosen with no "widget"/"view" literal so the pin cannot pass on embedded description text |
| W-U4 — a unit-kind row with "renders" still routes to the func surface (assessment pin #2) | PROVEN | Green at BOTH trees (regression pin): routing unchanged; asserts `tdd` + `func` steps present post-fix |
| W-U5 — a kindless summary with "renders" keeps the legacy branch-3 func routing | PROVEN | Green at BOTH trees: pre-#835 call sites and unreadable lists unchanged |

No existing test was weakened, skipped, renamed out of a filter's reach,
or excluded by config: the branch's entire test diff vs master is the
two NEW files (+306 lines); the source diff is the 40-line guard + one
doc bullet.

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | LOW (resolved in-audit) | Pin 3's first strengthening asserted `contains('tdd view')`, which the prose "tdd **view** lane" satisfied — a mutant placing the WRONG route command (`zfa tdd compose`) in the reason survived `+8`. Fixed during the audit by pinning the command form itself (`contains('` + backtick + `zfa tdd view')`); the mutant now dies `+7 -1` | Cycle-log mutation entry; the audit's mutant run transcript |
| 2 | LOW (out of scope, filed as follow-up) | The same kind-vs-prose collision class exists for `theme`/`platform` kinds (e.g. a theme-kind row with "renders" still routes to `tdd func` today); no make-fallback lane exists for them, so the guard was scoped to `widget` per the issue's contract | fix.md Deviations + Follow-ups |
| 3 | INFO | The reporter's home project (`~/zik_zak_test`) was not available in this environment; the reproduction was exercised at the real `zfa tdd make` CLI entry point against a fixture reproducing the issue's exact scenario literal, kind row, and gen-shaped stub — the shape `tdd func` refuses verbatim | ./tdd/red-evidence.md slow-tier section |

## Mutation results

No mutation tool in the profile (`.specify/memory/tdd-profile.md`:
"none wired in CI"); deliberate mutants per the rubric, restored
byte-exact after each (git checkout; `git status`/`--stat` clean;
suite re-green).

| Mutant | Behavior | Survived | Judgment |
| --- | --- | --- | --- |
| `generation_planner.dart` — guard kind-check disabled (`== BehaviorKind.widget` → `== BehaviorKind.theme`) | W-U1/U2/U3 | No | Caught by all five guard pins (`+3 -5`); a first sampling run (`+4 -4`) exposed pin 3's embedded-description weakness, sharpened refactor-while-green |
| `generation_planner.dart` — reason reworded, still names `tdd view` | W-U1 | Yes | Judged non-load-bearing: the fallback routes on `summary.kind`, not reason text; the pins intentionally assert behavior + route naming, not phrasing |
| `generation_planner.dart` — reason names the WRONG route command (`zfa tdd compose`) | W-U1 | No (after Finding 1 remediation) | Caught by pin 3's command-form assertion (`+7 -1`) |

## Rubric answers

1. **Tests first?** Yes — test-only commit `becca94b` precedes the fix
   commit `9abc40e4`; the RED state of every pin is recorded with
   commands and verbatim failure output at the pre-fix tree
   (./tdd/red-evidence.md, ./tdd/cycle-log.md).
2. **Behavior asserted?** Yes — pins assert the observable contracts:
   plan expressibility, step argv, refusal reasons, make summary lines
   and exit codes, fake-bin dispatch order, and cycle-log evidence. No
   double-configured-return or internal-state assertions.
3. **Would they catch a bug?** Yes — the routing-regression mutant is
   caught by 5 pins; the observability mutant is caught after in-audit
   remediation; the single surviving mutant targets unpinned phrasing
   by design.
4. **Every requirement covered?** Yes — AC1 (W-U1 group + W-A1 at the
   CLI surface), AC2 (W-U4), AC3 (W-U5), AC4 (W-U2, W-U3); 4/4 criteria
   reach tests exercising the real planner/CLI entry points.
5. **Worth keeping?** Yes — deterministic (temp fixtures disposed, no
   clocks/network), fast (fast pins <1s, slow pin ~17s), sentence names,
   and consistent with the neighboring #835/#939 suites they mirror.
