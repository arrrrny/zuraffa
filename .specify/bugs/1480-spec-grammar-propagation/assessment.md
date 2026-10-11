# Bug Assessment: 1480 — zuraffa spec authoring grammar never reaches a spec-kit project

- **Slug**: 1480-spec-grammar-propagation
- **Created**: 2026-09-10T22:45:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1480 (allowlisted host github.com; fetched live via REST — `gh` unavailable)
- **Verdict**: valid
- **Severity**: critical

## Report (verbatim or summarized)

Issue #1480 (arrrrny, 2026-09-10, labels: bug, tdd, track-tdd-loop, spec-drift, missing-integration). zuraffa's spec authoring grammar (`## Layer Contracts` + indented `traces:` continuation lines) never reaches a project scaffolded by spec-kit: the installed `.specify/templates/spec-template.md` is the stock spec-kit template (4556 bytes, 0 `## Layer Contracts`, 0 `traces:`), and no zfa verb installs zuraffa's own template (9272 bytes, grammar present). A spec-kit-authored spec passing every speckit quality gate is guaranteed to dead-end the unit lane: 42 behaviors fallback-route, `zfa tdd run` dies at the first unit `make` with `vacuous-green` after 27m41s (`stopped_at=U1:make`). Maintainer preference recorded verbatim in the issue: *"I want a seamless tdd cycle, that works out of the box with specify specs, zfa tdd custom parsing and expectations should be either held in a different file mapping to spec or some other mechanism."*

## Symptom

`zfa tdd plan` on a spec-kit-authored spec exits 0 while every unit behavior fallback-routes through the legacy description classifier; the dead-end only surfaces ~28 minutes later inside `zfa tdd run` when `make` stops with vacuous-green. Expected: the plan-stage contract mapping works for speckit-authored specs out of the box, or the author is stopped at plan time in seconds with the exact rows to declare.

## Reproduction

1. `grep -c '## Layer Contracts' .specify/templates/spec-template.md` → 0 (stock spec-kit template; confirmed locally on the repo's file too — the repo-LOCAL template carries the grammar, but nothing ships it to consumers)
2. `grep -c 'traces:' .specify/templates/spec-template.md` → 0
3. Author a spec-kit-shaped spec (zuraffa-1.0 marker only — the #1183 pin) with FRs but no zuraffa grammar sections
4. `zfa tdd plan <feature>` → exit 0, all unit rows `[fallback: legacy description classifier matched — trace FR to a declared contract row]`
5. `zfa tdd run <feature>` → dies at first unit make (`vacuous-green`), minutes in

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/plan_command.dart:593-600` — `SpecDeclarations` assembled ONLY from `specMd`: `parseScenarioTypeMarkers(specMd)`, `parseContractRows(specMd)`, `parseFrContractTraces(specMd)`. No other source is consulted — a mapping held beside the spec is invisible to the declared-routing path.
- `lib/src/plugins/tdd/commands/plan_command.dart:626-699` — provenance computed, strict gate refuses only in `--strict-routing` mode; the non-strict path continues to write artifacts with unit rows labeled `[fallback: …]` (see `_provenanceLines`, lines 1650-1757: `fallbackKinds[currentId] = decision` records the classified kind — including `BehaviorKind.unit` — and nothing refuses it).
- `lib/src/plugins/tdd/services/spec_parser.dart:797` (`parseContractRows`) and `:1211` (`parseFrContractTraces`) — pure markdown-text parsers; both consume `specMd` only. They are reusable on any markdown document (section-anchored), which is what makes a separate contracts file a parser-level drop-in.
- `lib/src/plugins/tdd/commands/init_command.dart:82-279` — `zfa tdd init` is the wiring verb; it ensures the TDD baseline (tdd-profile, dart_test.yaml, smoke test, pubspec patches) via writers under `lib/src/cli/writers/tdd/` — there is NO spec-template writer. `grep -rn "spec-template" lib/` hits only a doc comment in `tdd_command.dart:96`. Confirmed: no verb installs or asserts the authoring template.
- `.specify/templates/spec-template.md` (this repo, 9272 bytes) — carries the full zuraffa-1.0 grammar (`## Layer Contracts`, `traces:` examples, `**Type**` markers, Key Entities 3-column table). Issues #1183/#1186 fixed THIS repo-local copy (PR #1217, #1227); nothing propagates it to a consumer project.
- `lib/src/plugins/tdd/services/spec_marker_emitter.dart` + `plan_command.dart:821-828` — the #1186 one-time migration emits `**Type**` markers into SCENARIO blocks only (acceptance lane self-heal). Unit behaviors derive from FR bullets, not scenarios — there is no place to emit a contract row name, so the unit lane can never self-heal. `doc/BREAKING_CHANGES.md:62-73` states it: "Unit behaviors still need an author-declared contract trace: a classifier cannot invent a row name."
- `lib/src/plugins/tdd/services/vacuous_guard.dart` / make path — where the dead-end finally surfaces (honest stop, `U1:make vacuous-green`), untouched by this fix (engine cycle, gen/make pipeline and verify gate are out of scope per the task constraints).

## Root Cause Hypothesis

High confidence (code-read + local repro of steps 1-2 + template size check). Three compounding gaps, all in the authoring/wiring layer (never the engine): (1) the declared-routing path reads contract rows and FR traces exclusively from `spec.md`, so a mapping held anywhere else is unreachable; (2) the stock spec-kit template a consumer project actually receives carries none of the zuraffa grammar, and no `zfa` verb installs or asserts zuraffa's own template at wiring time; (3) the unit-lane fallback is unfixable by the machine (a contract row name is authoring intent), yet plan treats it like the acceptance-lane fallback — labeled, exited 0, migrated never — so the guaranteed dead-end surfaces only inside the 28-minute run.

## Proposed Remediation

**Preferred** (all three levers from the issue, in the maintainer's recorded order):

1. **Decouple the mapping from `spec.md`** — `zfa tdd plan` additionally reads `specs/<feature>/contracts/*.md` (the contracts directory the planning phase already writes; resolved feature dir, so `.specify/bugs/<slug>/contracts/` works too): contract rows merge with spec.md's (duplicate row names across sources refuse, errors-are-an-API); FR↔contract traces bind by FR id (`- **FR-001**: traces: Row` same-line or indented-continuation form — new `SpecParser.parseCriterionContractTraces`), filling behaviors that carry no inline spec trace; an FR declared in BOTH spec.md and a contracts file refuses (double declaration), a criterion trace naming no known FR warns (parity with #1319 unbound warnings).
2. **Fail fast on unit-lane fallback** — after the strict gate, if any behavior in `fallbackKinds` classified as `BehaviorKind.unit`, plan refuses (exit 1, `unit-fallback-refused`), names every `U<n> (FR-xxx)`, and the fix line names the three outs (declare `traces:` under the FR, put the mapping in `contracts/*.md`, or re-run with the new `--allow-unit-fallback` migration escape hatch). No artifacts written, spec never mutated (the refusal precedes marker emission). `--allow-unit-fallback` preserves the legacy labeled-fallback behavior for the migration window.
3. **Propagate the authoring template at wiring time** — new `SpecTemplateWriter` (`lib/src/cli/writers/tdd/spec_template_writer.dart`, embedded zuraffa-1.0 template) wired into `zfa tdd init`: template absent → install; present but carrying NO known zuraffa template version marker (the stock spec-kit scaffold — exactly the dead-end carrier) → replace with a loud notice; present with a known zuraffa marker → untouched (the marker is the customization treaty, #919/#1183).

**Alternatives** (considered, rejected): making the acceptance marker migration also patch FRs — impossible without inventing authoring intent (the exact thing the issue forbids); defaulting the gate to warn-only — leaves the companion bug ("plan exiting 0 on an all-fallback spec") unfixed; teaching the classifier to invent row names — explicitly called out as unfixable in `doc/BREAKING_CHANGES.md:62-73`.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/plan_command.dart` (contracts merge + fail-fast gate + flag)
- `lib/src/plugins/tdd/services/spec_parser.dart` (criterion-keyed trace parser)
- `lib/src/cli/writers/tdd/spec_template_writer.dart` (new)
- `lib/src/plugins/tdd/commands/init_command.dart` (wire the writer)
- tests: `test/cli/writers/tdd/spec_template_writer_test.dart`, `test/plugins/tdd/commands/plan_contracts_decoupled_1480_test.dart`, `test/plugins/tdd/commands/plan_unit_fallback_fail_fast_1480_test.dart` (new); legacy plan fixtures updated to the new contract where they pre-date the grammar

**Tests to add or update**:
- template writer: install-on-absent, replace-stock, preserve-marked (red→green)
- decoupled mapping: contracts-file rows + criterion traces route `[declared:]` on a grammarless spec; duplicate-row and double-trace refusals; unknown-FR warning
- fail-fast: all-fallback spec refuses exit 1 naming `U1 (FR-001)`, no artifacts, spec untouched; `--allow-unit-fallback` restores legacy exit 0; traced spec plans green; end-to-end: init installs template → template-authored spec + traces → plan green

## Risks & Considerations

- The fail-fast gate changes `zfa tdd plan`'s default contract: legacy specs with untraced FRs that used to exit 0 now exit 1. Mitigation: `--allow-unit-fallback` escape hatch + a fix line naming all three outs; test fixtures predating the grammar are updated (traces added) or pass the flag where the fallback path itself is the subject.
- Replacing a grammarless spec-template at init: a user-customized stock-template variant would be replaced — mitigated by the loud notice line; the zuraffa-marker treaty preserves any template that already pins `zuraffa-1.0`.
- `contracts/*.md` files that are script documentation (e.g. `specs/1444…/contracts/*.md`) parse to zero rows/traces — no behavior change for existing features.
- Engine cycle, gen/make pipeline, verify gate: untouched (task constraint). The decoupled traces ride the existing test-list cells (issue #1320 method-qualified names), so make's declared-signature path works unchanged.

## Open Questions

- None blocking. Companion issues (#1417 boundary scripts, #1466 plan exit 0) stay open; this PR closes only the grammar-propagation dead-end.
