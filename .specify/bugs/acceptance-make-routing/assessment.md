# Bug Assessment: acceptance behavior routed to `zfa make <BehaviorId>` (no --no-entity) — regression of #696 family

- **Slug**: acceptance-make-routing
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/873
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

On a wave-1 rebuilt project (commit 17a40434 lineage), spec 004-dependency-injection after a fully-complete spec 001: behaviors A1 ("all data sources are registered...") and A2 ("all repositories are registered...") defer as `unexpressible` (phase 2), but A3 ("all use cases are registered as factories") gets a 4-step generation plan whose index-1 step spawns `zfa make A3` — the behavior ID as an entity name, WITHOUT `--no-entity` — and dies with the #496 fail-fast ("no entity source file was found"). Reported by arrrrny; no comments.

## Symptom

`zfa tdd make --feature 004-dependency-injection A3` prints `plan: 4 step(s)` then `generation step failed at index 1 ... command: zfa make A3 ... exit: 1`. The acceptance behavior's own ID reaches the real CLI as an entity name — the #696/#718 family on a NEW path (the acceptance path), this time without the `--no-entity` guard the unit routing gained post-#728.

## Reproduction

1. Fresh `zfa setup --platforms=macos`
2. Run spec 001 to completion (done=21)
3. Copy spec 004, plan, run → stops at `A3:make generation-error`

Unit-level mirror: `GenerationPlanner.plan()` fed the real gen composite description segment (`A3 — all use cases are registered as factories`) returns an EXPRESSIBLE 4-step plan: `entity create -n A3 | make A3 | tdd wire A3 --entity A3 | build`.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart` — `_descriptionFor(ArtifactRecord)` splits the registry composite `file::id::description` and returns segment 2 as "the description". But the REAL gen composite's description segment is the GENERATED TEST NAME (`<id> — <description>`, per `behavior_test_writer.dart`), so the planner receives the leading behavior id embedded in prose.
- `lib/src/plugins/tdd/services/generation_planner.dart` — the acceptance keyword branch (`desc.contains('use case')` etc.) needs an entity name: `summary.target ?? _extractEntityName(...) ?? _extractCapitalizedTrace(...)`. `_extractCapitalizedTrace` scans for the first capitalized token; the leading `A3` (the behavior's own id, straight from the test-name convention) matches first, yields a non-null derived name, which (a) skips the #758 unexpressible refusal that A1/A2 correctly hit, and (b) drops `--no-entity` because a non-null derived name makes the plan pass a concrete entity — hence `zfa make A3` with no flag.

## Root Cause Hypothesis

**Confidence: high.**

The generated test name `<id> — <description>` (behavior_test_writer.dart) leaks into the registry's description segment; `_descriptionFor` documents "extract the description segment" but with the test-name convention in place, segment 2 is `A3 — all use cases are registered as factories`. The planner's capitalized-trace extraction then reads the behavior's OWN id as the "entity named in the description". An entity must be named by the SPEC, never inherited from the test-name convention — the id is a naming-convention token, not spec prose. This is the #696/#718 family resurfacing because the id-echo never reached the acceptance path's description-keyed callers before.

Deliberate scope guard (issue #872 interplay): only the behavior's OWN id is filtered (case-insensitively, wherever it appears in the description) — NOT a blanket `^A\d+$` skip. Digit-bearing names (`A1`, `Node2`, `SHA256`) remain legal derived entity names when the SPEC's prose names them; and a real entity behind the id prefix ("A1 — the Todo repository service ...") still resolves to `Todo`. Direct user invocation (`zfa entity create -n A1; zfa make A1`) is untouched — the fix lives in the planner's extraction, not in `make`'s entity resolution.

## Proposed Remediation

**Defense in depth at the consumer side (this fix), complementary to the producer-side root fix in PR #886 (issue #871):**

1. `make_command.dart` `_descriptionFor`: strip the record's own `<id> — ` test-name prefix before handing the description to the planner, so description-keyed callers key on the spec's actual prose.
2. `generation_planner.dart` `_extractCapitalizedTrace`: refuse the behavior's own id (case-insensitive) as an extracted entity name, wherever it appears in the description — the last-line guard if any caller still passes an id-prefixed composite.

Result for the #873 repro: the extraction returns null, the #758 unexpressible refusal engages (the SAME honest deferral A1/A2 already get), and make's composition fallback (#642) can engage for features holding composable green unit subjects — never `zfa make <BehaviorId>`, never `entity create -n <BehaviorId>`.

## Relationship to sibling issues / PRs

- **#871 / PR #886** — producer-side: gen writes the composite with the id embedded exactly once and the generated test name becomes the pure description; legacy registries are handled by `ArtifactRecord.descriptionSegment`/`plainTestName`. PR #886 deliberately does NOT harden `_extractCapitalizedTrace` (out of caution for #872); this fix hardens it narrowly (own id only), so the two merge cleanly in intent: even with #886, the planner-side guard keeps the #696 family unreachable from any future id-echo regression.
- **#829 / PR #885** — the expected contract this fix restores for the acceptance path: compose (phase 2) or a REAL entity from Key Entities, never `zfa make <BehaviorId>`.
- **#872** — the reason the filter must be narrow: digit-bearing entity names are legal; only the behavior's own id is a naming convention, never a spec-named entity.
