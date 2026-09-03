feature: 071-declared-intent-routing (issue #951)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: branch 071-declared-intent-routing @ 88e04ac4 (audit live-mutants run after)
behaviors: 8
proven: 8
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 13
criteria_covered: 13
mutation_score: 2/2 live mutants caught # (1) strict gate disarmed at plan (`strict: strict` -> `strict: false`) -> +8 -1, the A4 refusal pin dies; (2) marker lookup disabled in the resolver -> +13 -2, the precedence pin and a strict pin die. In-loop mutants additionally recorded in cycle-log (U1 guard/A2 func: caught; one pin sharpened during the fix stage). All restorations byte-exact via git checkout; suites re-green after each.
mutants_survived: 0
suite: tdd plugin fast tier 923/923 (879 pre-feature + 44 new pins); slow widget suites #939 4/4 + #950 1/1; dart analyze lib/ + test/ clean; dart format clean on touched files

# TDD Verification: declared-intent routing (eliminate keyword-based matching)

**Verdict: PASS.** All eight behaviors' tests were written first and
recorded RED before their implementation (cycle-log carries the red
commands and outputs; commits pair each behavior's test + implementation
per the per-cycle shape the rubric accepts), the five defect-class
replays are pinned, no HIGH smells, and every FR/AC is covered. Two
live mutants caught post-implementation; restorations byte-exact.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| U1 — RoutingResolver ladder (precedence, per-aspect, refusals, strict, determinism) | PROVEN | RED: load failure pre-implementation (`+0 -1`); cycle-log; green `+15` |
| U2 — `**Type**` marker parsing (ids, lines, duplicates, unknown kinds, manual) | PROVEN | RED: load failure, then 2 line-number expectations corrected (test-side arithmetic); green `+6` |
| U3 — Function contracts bullet → rows + signatures; malformed refused | PROVEN | RED: load failure; green `+4` (one iteration: signature parsing widened to all layer rows per the #919 grammar) |
| U4 — Persistence marking from `[persistent]` tag / storage trace; vocabulary unmarked | PROVEN | RED: `+1 -2` (tag unparsed; AC2 vocabulary marked by the keyword trigger); green `+3` + #833 family 14/14 |
| A1 — declared lanes end-to-end; prose never overrides; reworded prose identical; undeclared keeps legacy | PROVEN | RED: `+2 -2` for the right reasons (declaration ignored); green `+10` |
| A2 — surfaces/signatures/entity from contract rows; function row beats entity-bait prose; undeclared legacy | PROVEN | RED: planner load failure + func pin `String` vs declared `bool`; green `+5` / `+10` |
| A3 — `route:` provenance lines (stdout + artifact block) | PROVEN | RED: `+4 -3` (no route lines); green `+7` (two in-green fixes recorded: print vs stdout capture; sniffer kind never presented as declared) |
| A4 — strict mode refuses undeclared (exit 1, fix hint, no artifact); declared specs clean | PROVEN | RED: `+7 -2` unknown option; green `+9` (strict threaded to resolver after the first green attempt disarmed it — caught by the pins themselves) |

No pre-existing test was weakened or skipped. The one intentional
contract change — `plan_persistence_marking_833_test.dart`'s keyword
pins — is spec-sanctioned (FR-006/AC2 retire the keyword trigger), is
documented in that file's header, keeps the #833 mark shape/idempotency
assertions, and ADDS an explicit vocabulary-unmarked pin.

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | LOW (fixed in-loop) | Quickstart validation surfaced that multiple strict refusals collided on a shared `__refused__` key — earlier refusals were overwritten (U1's dangling refusal vanished). Fixed: refusals accumulate; both now print with exit 1 | cycle-log T031; the fix commit 88e04ac4 |
| 2 | LOW (fixed in-loop) | `_provenanceLines` initially did not pass `strict` into the resolver — the strict gate was silently disarmed at plan time. Caught by the A4 pins (exit 0 + artifact written); fixed | cycle-log A4; live mutant re-confirmed the pin catches it |
| 3 | LOW (fixed in-loop) | `_provenanceLines` initially passed the parse-time sniffer kind as the resolver's rung-3 declared kind — the fallback outcome would have been labeled declared. Fixed: only the marker's kind is presented as declared | cycle-log A3 |
| 4 | INFO | `PersistenceMarker.matchesKeywords` is now unreferenced by plan_command; retained (read-side `extract` is live). Removal is a follow-up cleanup | fix.md/verification follow-ups |

## Mutation results

Deliberate mutants per the profile (no mutation tool in CI), restored
byte-exact (git checkout; suites re-green after each).

| Mutant | Behavior | Survived | Judgment |
| --- | --- | --- | --- |
| `plan_command.dart` — strict disarmed at plan (`strict: false` in the provenance resolve) | A4 | No | Caught by the refusal pin (`+8 -1`: exit 0 + fallback lines instead of refusal) |
| `routing_resolver.dart` — marker lookup disabled (rung 1 removed) | U1/U2 | No | Caught by the precedence pin and a strict pin (`+13 -2`) |
| In-loop: guard kind-check disabled (#950 file, earlier stage of this branch) | W pins | No | `+3 -5` — all five guard pins (recorded in the widget-func-verb-routing bug record) |

## Rubric answers

1. **Tests first?** Yes — every behavior's RED command + output is in
   cycle-log/red evidence; history pairs each behavior's test and
   implementation in the same commit with the red recorded (the
   rubric's per-cycle shape).
2. **Behavior asserted?** Yes — pins assert plan exit codes, rendered
   test-list rows, route-line provenance, refusal messages, subject
   scaffold types, dispatch logs, and fake-pipeline invocation
   emptiness — observable CLI/artifact contracts throughout.
3. **Would they catch a bug?** Yes — 2/2 live mutants caught this
   audit; in-loop mutants (strict disarmed, precedence broken, wrong
   route command, marker-ignored resolver) all caught.
4. **Every requirement covered?** Yes — FR-001..FR-013 map to behaviors
   A1–A4/U1–U4 (FR-012 structural-parsing preservation is pinned by the
   untouched pre-existing parser suites staying green; FR-008/FR-009 by
   A3/U-pins; FR-010/FR-011 by A4); 13/13 criteria.
5. **Worth keeping?** Yes — deterministic temp fixtures, fast pins,
   sentence names, consistent with the neighboring #835/#939/#950
   suites.

## Remediation

None required (PASS). Findings 1–3 were remediated inside the loop and
are recorded above with their evidence.
