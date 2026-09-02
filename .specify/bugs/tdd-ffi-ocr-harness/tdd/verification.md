---
feature: .specify/bugs/tdd-ffi-ocr-harness (bug #835, branch audit, pinned per bug extension TDD mode; the committed issue.md + assessment.md on master are the authoritative record, issue body transcribed verbatim)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: e273fa43
behaviors: 14
proven: 11
likely: 3
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 10/10 caught # scope: the logic this fix added only (test_list_reader.dart, behavior.dart, subject_writer.dart, behavior_test_writer.dart, golden_harness_writer.dart, gen_command.dart golden+staleness, make_command.dart kind resolution, plan_command.dart preservation, dart_test_yaml_writer.dart), manual deliberate mutants
mutants_survived: 0
suite: "chunked fast suite 31 chunks +3137 −0 (one prior run had a non-reproducing test/commands U12 flake, re-run clean, chunk green in isolation, full folder green); sc_013 +4, sc_017, sc_018, sc_021 +2, sc_022 +5 all green; dart analyze 1 issue = pristine-identical (entity_help_test unused import); dart format clean on all 11 touched files (2 pre-existing master drift files excluded per #737/#829 precedent)"
---

# TDD Verification: bug #835 — FFI + OCR harness (native-boundary behaviors must be TDD-able)

**Verdict: PASS_WITH_GAPS.** The red→green cycle is real on the real CLI. The
pre-fix probes reproduced all four issue signatures verbatim (R1 an `ffi` kind
cell rejected as `expected 4 columns ..., found 6` with zero files written, R2 a
`## Native loop` row rejected as `table row outside an outer/inner loop
behavior section`, R3 the same behavior declared as a unit row producing the
generic `int subject_u1()` pair with NO contract test, NO golden fixtures, NO
marked lane — the fixture/golden file search came back empty, R4 `zfa tdd plan`
silently re-homing the hand-written ffi row into the Inner loop as a plain unit
row). Post-fix, the same declaration path runs end to end: gen emits the
contract pair + the marked golden lane + the fixtures, verify-red certifies the
honest binding-contract red (`classification=assertion certified=true`), make
refuses honestly (`outcome=unexpressible` naming the wiring path), the default
tier runs the contract lane only, and after wiring an in-memory binding and
recording the golden output BOTH lanes go green (`dart test` and
`dart test --preset=integration`). All three remediation items are covered end
to end, all ten deliberate mutants were killed. The gaps: three guard behaviors
are LIKELY (no pre-fix red can exist for them), the e2e drive of the run-driver
deferral reuses the pre-existing #625 machinery rather than re-proving it, and
the CI job's greenness can only be verified after the PR lands.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| U-835a — an `ffi` kind cell (dialect 1) parses as BehaviorKind.ffi (remediation 1) | PROVEN | RED captured verbatim (real CLI, `tmp/red_835_evidence.log`): `test-list.md line 9: expected 4 columns (id/behavior/traces/state), found 6` → gen exit 1, zero files. GREEN: the same row parses (`test_list_reader_ffi_835_test.dart`, 6 tests green) and gen runs. |
| U-835b — a `## Native loop` section carries the ffi kind (remediation 1) | PROVEN | RED: `table row outside an outer/inner loop behavior section` → exit 1. GREEN: 4-col rows under the header parse as ffi (reader test + sc_022's declaration path). |
| U-835c — unknown kinds still fail closed (no silent fallback) | LIKELY | Guard behavior: the malformed-row misfire-stop is pre-existing and unchanged; the new test pins it (unknown kind cell + orphan 4-col row both throw TestListReadException), but no pre-fix red exists for a guard that already held. |
| U-835d — gen emits three surfaces for an ffi behavior: contract pair + marked golden lane + fixtures, document AND OCR variants (remediations 1–3) | PROVEN | RED: R3 — the parsed-as-unit behavior produced the generic `int subject_u1()` pair; the fixture/golden search (`*.pdf`, `*.png`, `*fixtures*`, `*golden*`) returned EMPTY. GREEN: gen `verdict: created` lists 5 created paths (`u1_test.dart`, `u1_subject.dart`, `u1_golden_test.dart`, fixtures); OCR variant auto-selects on `ocr`/`tesseract` (image + expected-extraction JSON); pinned by gen_command_ffi_835 (4 tests) + golden_harness_writer_test (8 tests) + sc_022. |
| U-835e — the contract test is the ONE registered runnable test (`<id> — <description>`), assertion-shaped honest red | PROVEN | Real red→green mid-session: the first draft emitted two contract tests; the real `zfa tdd verify-red` returned `classification=runner-error certified=false` (the registered plain-name matched zero tests); the single-test rewrite returned `classification=assertion certified=true` on the same fixture. Pinned by the writers test (exactly-one test, title contains the runnable name). |
| U-835f — the golden lane is MARKED (`@Tags(['integration','slow'])` before the first directive) and excluded from the default tier | PROVEN | Empirical probes: a library-level annotation filters correctly while one on `main()` is ignored (probed before writing the template); sc_022 asserts the default run exercises the contract lane and NOT the golden lane under the generated dart_test.yaml. |
| U-835g — the lane never skips silently: unwired binding / unrecorded golden FAIL loudly | PROVEN | sc_022: with the binding unwired, `dart test --preset=integration` exits 1 naming the golden test; with the binding wired but golden unrecorded, the `expected: null` scaffold fails with the record-it reason (asserted in golden_harness_writer_test). |
| U-835h — the OCR scenario script encodes the deterministic seed + tolerance thresholds (remediation 3) | PROVEN | R3's empty fixture search covers the pre-fix absence; post-fix the scenario JSON carries `seed` (FNV-1a derivative, golden-pinned 21961/18578 — byte-stable across invocations, NOT String.hashCode) and `thresholds.fieldAccuracy: 0.95`; the lane test asserts accuracy ≥ threshold deterministically. |
| U-835i — fixtures are real, deterministic, and binary-safe (valid PDF, real PNG) | PROVEN | Test-caught real bugs: (a) the first PNG write UTF-8-encoded the bytes (`Expected [137,80,78,71...] Actual [194,137,80,78,71...]`) → fixed to writeAsBytes, pinned by M6; (b) sc_022 caught the document lane's missing `dart:io` (`Method not found: 'File'` at load) → fixed, pinned by M7. The PDF validates byte-for-byte (header, %%EOF, startxref target, every xref offset points at `N 0 obj`). |
| U-835j — re-gen NEVER clobbers recorded golden data or partial wiring (idempotent reuse) | LIKELY | New-surface guard: the staleness-clobber hazard only exists once the harness exists, so no pre-fix red is possible. The gen test simulates partial wiring + a recorded golden and pins both after re-gen; M8 (skip removed) killed the mutant — the guard is load-bearing. |
| U-835k — make refuses ffi behaviors honestly: `unexpressible` naming the wiring path, never the func dead-end | PROVEN | Real CLI on a certified-red fixture: `make: behavior=U2 outcome=unexpressible` exit 1, reason names symbolResolved/roundTrip/convertGolden + the integration preset (the pre-fix analogue would have routed U2 into `tdd func` → `unrecognized shape` → generation-error misfire-stop). |
| U-835l — plan preserves hand-written ffi rows verbatim; a native row CLAIMS its traces, suppressing the spec-derived duplicate | PROVEN | RED: R4 — after re-plan the native section was GONE and U2 appeared as a plain unit row. GREEN: plan_command_ffi_835 (3 tests) pins preservation, criterion claim, and suppression; M10 killed the preservation-dropped mutant. |
| U-835m — fresh consuming projects get lane semantics from the generated dart_test.yaml (tags declared, slow excluded, integration preset re-includes) | PROVEN | dart_test_yaml_writer_ffi_835 (4 tests, YAML-parsed) + sc_022's fixture runs under that exact yaml shape (default tier excludes the lane, preset includes it). |
| U-835n — the ffi lane is wired to CI and can never go vacuously green | LIKELY | ci.yaml gains `ffi_golden_lane` (`dart test --tags ffi`); sc_022 carries the `ffi` tag so the lane has content, and a zero-match tag selection exits 79 (probed: exit 79, not 0). The job itself executes only on the pushed PR — not verifiable in-session. |

No assertion was weakened: the diff touches only the new bug-835 test files, the
new `golden_harness_writer.dart` service, and additive branches in the tdd
plugin; `git diff` removes no test, no assertion, no filter, no threshold. The
`renderContractTest` public method is additive (mirrors the pre-existing
`SubjectWriter.render` staleness-test role). No test was renamed out of a
filter's reach, skipped, or excluded.

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | LOW | `zfa tdd func` invoked DIRECTLY on an ffi behavior still exits 1 with the generic `unrecognized shape` message (the planner's ffi branch keeps the loop away from it, and the refusal protects the harness, but the message does not name the ffi context). Left as-is: the fail-closed contract is U-W5's, unchanged | `lib/src/plugins/tdd/commands/func_command.dart` (`_stubSignature` no-match branch) |
| 2 | LOW | The composition fallback's `target-not-acceptance` message says `is unit-kind` for any non-acceptance row, so an ffi row reads slightly mislabeled. Fail-closed semantics are correct (verified: discover refuses → honest unexpressible); only the prose is imprecise | `lib/src/plugins/tdd/services/composition_targets.dart:131-138` |
| 3 | LOW | Reclassifying an ALREADY-IMPLEMENTED behavior from unit to ffi (hand-editing the list) leaves the old unit pair on disk; gen reuses and the staleness skip will not regenerate a progressed subject. The implementer must migrate artifacts manually. Deliberate: auto-clobbering progressed artifacts is the worse failure (the #829 lesson) | `gen_command.dart` `_regenerateStaleStub` ffi guard |
| 4 | LOW | The golden lane resolves fixture paths relative to the PROCESS CWD (project root), matching the loop's profile templates (`dart test {file}` always runs from the project root). Running the generated test file from a different cwd breaks path resolution. The alternative (Platform.script) is unreliable under `dart test` | `golden_harness_writer.dart` fixture path constants |
| 5 | LOW | One chunked-suite run showed a non-reproducing failure (`doctor_checks_test` U12) that passes in isolation, as a full folder, and on a clean re-run — treated as a timing flake, not attributable (same handling as the #734v2 flake in the #829 verification). No fix tree failure remains | `/tmp/chunk835_full.log` (failing run) vs `/tmp/chunk835_full2.log` (clean rerun, +3137 −0) |
| 6 | LOW | The full integration preset (`--preset=integration`) includes the 19 heavy `test/integration/*` E2E tests; the CI wiring therefore scopes to the `ffi` tag instead of the preset, per the `dart_test.yaml` header policy that keeps heavy temp builds off CI agents. A consuming project's OWN CI should run the preset (its yaml says so) | `.github/workflows/ci.yaml` (`ffi_golden_lane` job comment) |
| 7 | LOW | The bug depends on #827 (namespacing) for artifact paths; that work is on master (e273fa43 carries the #827 namespacing + #829 phase-0 work), so this fix builds directly on it — no new cross-feature coupling introduced | `gen_command.dart` path construction (bug #827 comments) |

## Mutation results (deliberate mutants, manual — no mutation tool in profile)

Scope: the logic this fix added only. One small change each, run against the
pinned test file, expected failure, restored EXACTLY from a byte backup, and the
full 835 suite re-verified green after the pass (final: +38 green).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| `test_list_reader.dart` `_kindFromCell` ffi branch removed | U-835a | No | Killed — the kind-cell test fails (row becomes malformed) |
| `test_list_reader.dart` `native loop` header branch disabled | U-835b | No | Killed — the 4-col-under-native test fails |
| `generation_planner.dart` ffi unexpressible branch disabled (`&& false`) | U-835k | No | Killed — a U-prefixed ffi summary routes to the func surface (steps non-empty) |
| `gen_command.dart` golden-lane writing disabled (`&& false`) | U-835d | No | Killed — golden files + `golden_test_path` + verdict keys absent |
| `subject_writer.dart` `convertGolden` seam omitted | U-835d | No | Killed — the three-seam contract assertion fails |
| `golden_harness_writer.dart` PNG written via writeAsString (UTF-8 corruption) | U-835i | No | Killed — PNG signature assertion fails (the original bug, replayed) |
| `golden_harness_writer.dart` document lane loses `dart:io` | U-835i | No | Killed — the import assertion fails (the e2e-caught compile gap, replayed) |
| `gen_command.dart` ffi staleness skip removed | U-835j | No | Killed — re-gen clobbers the simulated partial wiring (`libpdf_to_md.so` gone) |
| `dart_test_yaml_writer.dart` `exclude_tags: slow` removed | U-835m | No | Killed — the default-tier exclusion assertion fails |
| `plan_command.dart` ffi row preservation disabled (`&& false`) | U-835l | No | Killed — the preserved-row assertions fail |

10/10 killed, 0 survived, 0 equivalent. Sampled behaviors: both declaration
surfaces, the planner refusal, the gen emission + idempotency guard, the harness
contract shape, both fixture-variant correctness gates, the lane tier contract,
and plan preservation — the full surface this fix added; not a whole-repo
mutation score.

## Traceability

| Remediation (issue #835) | Where it lands | Behaviors |
| ------------------------ | -------------- | --------- |
| 1. `zfa tdd gen` ffi-kind behaviors with golden input/output fixtures through the production binding on the host runner | `BehaviorKind.ffi`; `GoldenHarnessWriter` (real PDF/PNG fixtures, golden scaffolds); `SubjectWriter` harness (`convertGolden` seam); `BehaviorTestWriter` contract lane | U-835a, U-835b, U-835d, U-835i |
| 2. Where the native lib cannot load: contract assertions (symbols resolved, marshalling round-trips) in the loop; fixture-level assertion in a marked integration lane wired to CI — still a gate, never skipped silently | Contract lane test (default tier, assertion-shaped red, certified by the real verify-red); `@Tags(['integration','slow'])` golden lane excluded from default tiers; `DartTestYamlWriter` tier config; `ci.yaml` `ffi_golden_lane` job (tag-scoped, zero-match exits 79); loud-failure scaffolds with record-it reasons | U-835e, U-835f, U-835g, U-835m, U-835n |
| 3. OCR: image fixtures + expected extraction JSON; tolerance thresholds in the scenario script (deterministic seeds) | OCR variant (`golden-input.png` + `golden-expected.json` scenario script with `seed` + `thresholds.fieldAccuracy`); deterministic FNV-1a seed, golden-pinned; deterministic field-accuracy comparison | U-835d, U-835h |

Assessment open questions, resolved by this fix (both were flagged
NEEDS-CLARIFICATION): the FFI contract assertion format is the two-facet
contract lane (declared `kRequiredSymbols` all resolve + payload round-trips
unchanged, through the wired production binding); the OCR scenario JSON schema
is `{"behavior", "seed", "thresholds": {"fieldAccuracy"}, "expected": {...} |
null}`.
