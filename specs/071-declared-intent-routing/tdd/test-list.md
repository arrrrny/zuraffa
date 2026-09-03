# Test List: 071-declared-intent-routing

Derived from spec.md + plan.md by the LLM-guided workflow (repo is not
zuraffa-wired: `zfa` present but no `.zfa.json` → `ZFA_MISSING`, tdd.plan Step 0
fallback). Behaviors map 1:1 onto the `[behavior: …]`-marked test tasks in
`tasks.md`; every test task precedes its implementation task.

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | declared lanes route end-to-end: a marker-declared widget scenario whose prose says "renders" plans the widget lane (never func); past-tense scenarios keep their declared lane; reworded prose yields identical routing | FR-001, FR-013, SC-001 | PENDING |
| A2 | generation surfaces, signatures, and entity attribution come from declared contract rows: entity row → entity pipeline; function row → `tdd func` with the declared return type (the #920 replay); presentation row → view lane; undeclared → labeled fallback with provenance | FR-004, FR-005, FR-007 | PENDING |
| A3 | routing provenance: `zfa tdd plan` prints one `route:` line per behavior (declared/fallback bracket tokens, spec lines) and persists the provenance block into the test list | FR-008, SC-003 | PENDING |
| A4 | strict mode: `--strict-routing` refuses undeclared intent (exit 1, `--> fix:` naming the spec line), surfaces conflicts/dangling/malformed refusals, and runs clean on fully declared specs; the five bug-class replays cannot reproduce | FR-010, FR-011, SC-004, SC-002 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the RoutingResolver ladder: precedence marker > contract row > test-list kind > labeled fallback; per-aspect resolution (kind/surface/entity/signature/persistence); conflicts name both lines; dangling references, malformed signatures, strict undeclared each refuse with spec lines; deterministic | FR-001, FR-009, FR-011 | PENDING |
| U2 | scenario `**Type**: <kind>` markers parse into declarations with spec lines; duplicate markers conflict; specs without markers yield empty declarations | FR-002 | PENDING |
| U3 | the `**Function**` Layer Contracts bullet parses into contract rows with `name(Params) -> Return` signatures; a bullet missing the return is a malformed-declaration naming the row | FR-003, FR-005 | PENDING |
| U4 | persistence declarations: `[persistent]` FR tags and storage-dependency traces mark behaviors; storage vocabulary without a declaration does not; fallback marking is labeled | FR-006 | PENDING |

## Task mapping (tasks.md)

| Behavior | Test task (mandatory, RED first) | Implementation tasks |
| --- | --- | --- |
| U1 | T005 | T002, T003, T004 |
| U2 | T006 | T008, T009, T010, T011 |
| A1 | T007 | T008–T011 |
| U3 | T012 | T014 |
| A2 | T013 | T015, T016, T017 |
| U4 | T018 | T019, T020, T021 |
| A3 | T022 | T023, T024 |
| A4 | T025 | T026, T027, T028 |

MVP scope (Foundational + US1): U1, U2, A1.
