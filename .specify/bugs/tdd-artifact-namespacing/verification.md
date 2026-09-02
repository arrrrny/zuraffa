# TDD Verification — bug #827 (branch: fix/827-tdd-artifact-namespacing)

```yaml
verdict: PASS_WITH_GAPS
decisive_reason: >-
  the bug's acceptance behaviors are covered by behavior-asserting tests that
  were written and observed red before the fix (red evidence recorded at
  .specify/bugs/tdd-artifact-namespacing/evidence.md), the full fast suite is
  green chunked, and 4/4 sampled deliberate mutants were killed — the gaps are
  procedural, not evidential: the audit was not independent (same session),
  mutation was sampled rather than exhaustive, and one heavyweight e2e scenario
  ran per-test because of the agent's 10-minute wall-clock cap
verified_at: 3cb47d66
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
profile: .specify/memory/tdd-profile.md
mode: branch (audit everything the branch changed; the bug branch has no
  specs/<feature> test list, so .specify/bugs/tdd-artifact-namespacing/
  substitutes as the evidence home — issue.md, assessment.md, evidence.md)
date: 2026-09-02
behaviors: 10
proven: 10
test_after: 0
no_test: 0
high_smells: 1 (fixed in-branch, see F-1)
criteria_covered: 5/5 (issue #827's required-fix list)
mutation: deliberate mutants, 4 sampled / 4 killed after remediation (no
  mutation tool wired per profile)
suite: dart test (fast tier, chunked) — 0 failing chunks; slow tiers for every
  touched suite run individually (full matrix in evidence.md)
analyzer: dart analyze — 47 issues, byte-identical to the pre-change baseline;
  all 22 errors confined to examples/todo_tdd/ (pre-existing broken example
  package, outside this branch's scope)
format: dart format . — zero remaining diffs (--set-exit-if-changed exit 0)
```

## Verdict paragraph

The branch fixes the per-feature TDD artifact namespacing collision (#827) with
a test file (10 tests) that was authored FIRST, observed failing against the
unfixed tree (9 red / 1 by-design-green guard), and only then satisfied by the
implementation; both landed in one commit per the profile's convention, with
the red command and its actual failure output recorded in
`.specify/bugs/tdd-artifact-namespacing/evidence.md`. The tests assert
observable outcomes — files at namespaced paths, registry content, runnable
names, refusal semantics, file moves — not internals or doubles. The full
fast-tier suite is green under the repo's own chunked runner (68 chunks, two
wall-clock windows, identical semantics), every slow-tier suite the branch
touches is green, and the three heavyweight integration scenarios
(SC-017 real-pipeline, SC-018 plan→run loop, SC-021 acceptance composition)
pass. Four pre-existing failures (make ×2, run ×1, corpus-status flake ×1)
were re-run on clean `HEAD` and reproduce without this branch's changes; they
are flagged, not fixed. Deliberate mutants on the four highest-risk behaviors
were all killed — after the sampling exposed and fixed one vacuous assertion
in this branch's own test (F-1), which is the audit doing its job.

## Test-first evidence

| Behavior (test) | Class | Evidence |
| --- | --- | --- |
| feature-1 → feature-2 coexistence at namespaced paths | `PROVEN` | red: `+1 -9 Some tests failed` with the flat `test_path` captured verbatim; evidence.md; test+fix same commit |
| generated test imports its namespaced sibling subject | `PROVEN` | red in the same run (missing namespaced file); same-commit shape |
| repeat gen is a namespaced no-op (reused/reused) | `PROVEN` | passed pre-fix too (flat idempotency was already correct — regression guard by design); green post-fix |
| ownership guardrail refuses a foreign file at a namespaced path | `PROVEN` | red pre-fix (gen succeeded past the future-guard location); green post-fix with byte-identical preservation asserted |
| migrate-paths: move + registry rewrite (paths + runnable name) | `PROVEN` | red pre-fix (`migrate-paths` did not exist); green post-fix with namespaced runnable name asserted |
| migrate-paths: idempotent second run | `PROVEN` | red pre-fix; green with `migrated=0` |
| migrate-paths: refuses an existing target | `PROVEN` (after F-1) | red pre-fix; mutation sampling exposed a vacuous assertion, strengthened, re-proven against a live mutant |
| migrate-paths: missing flat artifact fails honestly | `PROVEN` | red pre-fix; green post-fix with the record left byte-identical |
| migrate-paths: `--dry-run` writes nothing | `PROVEN` | red pre-fix; green with file/registry preservation asserted |
| migrate-paths: already-namespaced records untouched | `PROVEN` | red pre-fix; green with `migrated=0` |

Existing-test diff audit (the rubric's highest-signal check): the branch
changed assertions in `gen_command_test.dart`, `plan_gen_contract_test.dart`,
and the SC-017/018/021 scenarios. Every change is a **location update**
(flat → namespaced path) or a **more specific** expectation (SC-021's composed
package import now pins the feature-namespace
`package:tdd_fixture/tdd/001-compose-demo/u1_subject.dart`). No assertion was
removed, loosened, weakened to truthiness, renamed out of a filter, or
skipped; the #683 staleness tests still demand regeneration, the FR-008
guardrail tests still demand conflict + byte-for-byte preservation, the #744
bounded-flow tests still demand honest timeout with no orphan artifacts.

## Findings (ordered by severity)

- **F-1 (HIGH, fixed in-branch, commit `3cb47d66`)** —
  `test/plugins/tdd/commands/gen_namespacing_827_test.dart` (refusal test):
  the migrate-refusal test originally asserted `contains('refused')` against
  output whose summary line always contains `refused=<n>` (and never seeded a
  registry), so the assertion was vacuous — the deliberate mutant that removed
  the overwrite guard survived it. Fixed by seeding the legacy registry and
  asserting the per-record `REFUSED for behavior "A1"` line plus
  `refused=1`/`migrated=0` counts; the mutant now dies. What the test asserts
  today: a taken namespaced target produces a per-record refusal, zero
  migrations, and both the flat pair and the taken file are preserved
  byte-for-byte.
- **F-2 (INFO, environment)** — the sandbox kills detached processes and caps
  each command at 10 minutes, so `tools/run_tests_chunked.sh` was split across
  two windows (chunks 1–59, then 60–68 with identical semantics) and SC-021's
  two tests were run individually (each ~5.5 min, both green). No gate was
  weakened: the same commands and selectors ran; only the wall-clock packaging
  differs.
- **F-3 (INFO, pre-existing, not fixed — out of scope)** —
  `make_command_test.dart` (2 failures: bug-657 verb hint, SC-004),
  `run_command_test.dart` (1 failure: bug-691 skip-to-make) fail identically
  on clean `HEAD`; one `corpus_status_command_test` failure appeared once and
  passed 3/3 on re-run (timing flake). All four are flagged for their owners;
  this branch neither causes nor carries them.
- **F-4 (INFO, pre-existing)** — `dart analyze` reports 22 errors, all inside
  `examples/todo_tdd/` (flat-layout generated artifacts referencing missing
  package URIs); identical to the pre-change baseline.

## Mutation results (deliberate mutants; profile records no mutation tool)

| # | Mutant (file, change) | Behavior that should catch it | Result |
| --- | --- | --- | --- |
| 1 | `gen_command.dart`: subject path left flat (`lib/tdd/<id>_subject.dart`) | namespaced relative-import test + registry subject-path assertion | KILLED (2 red) |
| 2 | `migrate_paths_command.dart`: overwrite guard disabled (`targetTaken = false`) | refusal test | SURVIVED → F-1 fixed → KILLED (1 red) |
| 3 | `run_command.dart`: legacy flat fallback renamed out of the disk check | #734-v2 disk-stub deferral test | KILLED (1 red) |
| 4 | `migrate_paths_command.dart`: runnable name not rebuilt (kept flat prefix) | migrate rewrite test's runnable assertion | KILLED (1 red) |

Every mutant was restored exactly (`git checkout -- <file>`) and the targeted
suite re-run green immediately after; no mutant ever touched a file the
feature did not change.

## Traceability (issue #827 "Required (system fix)" list → tests)

| #827 requirement | Where proven |
| --- | --- |
| 1. Namespace all generated artifacts by feature: `test/tdd/<feature-slug>/`, `lib/tdd/<feature-slug>/` | coexistence test (files + output); guardrail test (namespaced foreign file) |
| 2. `runnable_test_name` + artifacts registry use the namespaced paths | coexistence test (registry JSON + runnable string); migrate rewrite test |
| 3. Migration path for existing projects (`zfa tdd migrate-paths` or auto-upgrade) | migrate-paths ×6 (move/rewrite, idempotent, refuse, missing, dry-run, mixed-state); explicit command chosen over auto-upgrade — rationale in assessment.md |
| 4. Suite composition: `flutter test` keeps discovering everything under `test/` | namespacing stays under `test/`; SC-018 drives the real run driver over namespaced artifacts to all-green; chunked fast suite green |
| 5. Acceptance composition resolves unit subjects cross-feature only via explicit dependency edges | compose anchors resolve per-feature via registry records + green evidence (`composition_targets.dart` untouched in this respect); no filename-based cross-feature resolution was added; SC-021 proves composition works with namespaced anchors (package import through the feature namespace) |

Also honored: the ownership guardrail keeps working against namespaced paths
(guardrail test + preflight untouched); migration does not break flat-layout
projects (legacy fallback in the run driver's #734-v2 check, registry-driven
commands follow recorded paths, migrate is opt-in); no gate was eased.

## What was not audited

- **Independent cold-context audit**: this report was produced by the same
  session that wrote the tests and the fix (no fresh-context subagent was
  available in this environment); the smell pass re-read every file from disk
  but the independence caveat stands.
- **Exhaustive mutation**: 4 deliberate mutants on the branch's own changed
  surfaces only; `mutation_verifier`/`mutation_auditor` tooling was not wired
  into this run (profile: none in CI).
- **Slow tiers not touched by the branch** (corpus_*, verify suites beyond
  verify_command, runner_*, tdd_command_smoke, red_classifier,
  run_baseline_cache, etc. beyond their fast-tier chunks): the chunked fast
  suite covers them at the fast tier; their slow-tier variants were not run.
- **`--preset=all` repo-wide** (regression/integration/property/benchmark
  tiers beyond the branch's own scenario files): per `dart_test.yaml`, the
  full preset is documented as unsafe on small agents (multi-GB /tmp
  footprint); the branch-scoped slow suites were run individually instead.
- **Performance**: no timing budgets beyond the bounded-flow tests were
  measured.
- **Windows/macOS behavior**: POSIX-only (mkfifo-dependent tests self-skip on
  Windows); not exercised.
