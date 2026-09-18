# TDD test list — EPIC 3 (#1134): Presentation — contracted views + adaptive layouts + coverage ledger

Behaviors pinned BEFORE implementation (red set). Lanes are ordered; each
lane lands red → green in one commit. Suite paths are relative to repo
root.

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1134-a1 | test/plugins/tdd/services/platform_layout_contract_1134_test.dart | unit | `PlatformLayoutContract.resolve` honors the Presentation `adaptive_layouts` declaration first (precedence: Presentation wins over Skin Contract) | FR-001, US1-AC2 | RED → GREEN (proved, this session) |
| U-1134-a2 | test/plugins/tdd/services/platform_layout_contract_1134_test.dart | unit | `resolve` falls back to the Skin Contract `adaptive_slots` when no Presentation bullet declares slots (the #1004 declaration drives generation) | FR-001, US1-AC2 | RED → GREEN (proved, this session) |
| U-1134-a3 | test/plugins/tdd/services/platform_layout_contract_1134_test.dart | unit | `resolve` returns null when neither declaration exists (single-layout skeleton, zero drift) | FR-001, US1-AC3 | RED → GREEN (proved, this session) |
| U-1134-a4 | test/plugins/tdd/commands/view_command_skin_contract_slots_test.dart | command | `zfa tdd view` emits the AdaptiveViewState skeleton with one layout stub per Skin-Contract slot (contract-driven, no Presentation bullet) — every stub carries its slot key | FR-001, US1-AC2 | RED → GREEN (proved, this session) |
| U-1134-a5 | test/plugins/tdd/commands/view_command_skin_contract_slots_test.dart | command | a feature with no slot declarations keeps the single-layout Column skeleton (byte-stable zero drift) | FR-001, US1-AC3 | RED → GREEN (proved, this session) |
| U-1134-v1 | test/tdd/services/view_generation_contract_test.dart | unit | `ViewGenerationContract.inspect` classifies: mainline marker → generatorWritten, tdd subject doc comment → tddSubject, neither → handWritten, empty/absent → notFound | FR-003 | RED → GREEN (proved, this session) |
| U-1134-v2 | test/tdd/services/view_generation_contract_test.dart | unit | `machineSummary` renders `view: entity=<n> outcome=<scaffolded\|already-implemented\|error> files=<n>` — deterministic bytes | FR-002 | RED → GREEN (proved, this session) |
| U-1134-v3 | test/plugins/view/view_deterministic_contract_test.dart | command | first `zfa view create` scaffolds + prints the machine summary line `outcome=scaffolded` | FR-002, US2-AC1 | RED → GREEN (proved, this session) |
| U-1134-v4 | test/plugins/view/view_deterministic_contract_test.dart | command | re-run on an existing generator-written view: `already implemented — nothing to scaffold` + `outcome=already-implemented`, exit 0, no bytes rewritten | FR-002, US2-AC2 | RED → GREEN (proved, this session) |
| U-1134-v5 | test/plugins/view/view_deterministic_contract_test.dart | command | a target carrying the `zfa tdd view` subject marker refuses (exit 1) naming the tdd generator and the `--force` escape — the fence | FR-003, US2-AC3 | RED → GREEN (proved, this session) |
| U-1134-v6 | test/plugins/view/view_deterministic_contract_test.dart | command | a hand-written target (no marker) reports already-implemented without `--force` — never silently overwritten | FR-003, US2-AC4 | RED → GREEN (proved, this session) |
| U-1134-t1 | test/plugins/tdd/services/typed_ledger_projection_test.dart | unit | the projection assigns kinds from scenario verbs: shows→presence, is not shown→absence, navigates to→navigation, is disabled→state, while…in flight→sequence | FR-004, US3-AC1 | RED → GREEN (proved, this session) |
| U-1134-t2 | test/plugins/tdd/services/typed_ledger_projection_test.dart | unit | component tokens and i18n keys derive presence rows (`t.<key>` surfaces); slot-key surfaces derive per-slot presence rows | FR-004 | RED → GREEN (proved, this session) |
| U-1134-t3 | test/plugins/tdd/commands/plan_typed_ledger_1134_test.dart | command | `zfa tdd plan` writes `tdd/typed-ledger.md` + `tdd/typed-ledger.json`; every row carries kind (five-kind vocabulary) + status `traced\|untraced`; plan-time rows are untraced, visible, never omitted | FR-004, US3-AC1/AC5 | RED → GREEN (proved, this session) |
| U-1134-t4 | test/tdd/services/typed_platform_ledger_test.dart | unit | `TypedPlatformLedger.derive` produces (slot, surface, kind, status) rows — a mobile-only prover set leaves macos rows untraced (each layout traced independently) | FR-005, US1-AC4 | RED → GREEN (proved, this session) |
| U-1134-t5 | test/tdd/services/typed_platform_ledger_test.dart | unit | `kindSlotHeatmap` renders the kind × slot grid (`traced/total` cells, `-` for kinds the plan never declared) | FR-005, US3-AC2 | RED → GREEN (proved, this session) |
| U-1134-t6 | test/plugins/tdd/commands/plan_typed_ledger_1134_test.dart | command | a feature declaring `adaptive_layouts: mobile, macos` gets the per-layout heatmap section in `typed-ledger.md` + platform rows in the JSON | FR-005, US3-AC2 | RED → GREEN (proved, this session) |
| U-1134-t7 | test/tdd/services/xray_platform_heatmap_1134_test.dart | unit | `XrayLedgerOverlay.renderPlatformHeatmap` renders per-layout kind coverage — one line per kind × slot, HIGHLIGHT on zero-traced cells (kind coverage, not surface count) | FR-005, US3-AC3 | RED → GREEN (proved, this session) |
| U-1134-t8 | test/tdd/services/xray_platform_heatmap_1134_test.dart | unit | `XrayLedgerDeck.platformEntries` lists one entry per (slot, kind) with a traced/untraced badge | FR-005, US3-AC4 | RED → GREEN (proved, this session) |
| U-1134-t9 | test/plugins/tdd/commands/plan_typed_ledger_1134_test.dart | command | the 075 `ui-ledger.{md,json}` artifacts keep their pinned shape (typed ledger is a NEW pair — zero drift on the legacy artifacts) | NFR zero-drift | GREEN (pin) |
| U-1134-g1 | test/plugins/tdd/services/widget_vocabulary_gate_test.dart | unit | normalization: `ShadInput`→`input` ✓, `ZfaButton`→`button` ✓, `ShadGrid`→`grid` ✗ (not in vocabulary), `table` ✗; method-signature tokens (`buildMain(a, b) -> String`), `key:` tokens and slot bullets are NOT widget references | FR-006, US4-AC1/AC5 | RED → GREEN (proved, this session) |
| U-1134-g2 | test/plugins/tdd/commands/plan_vocabulary_gate_1134_test.dart | command | an out-of-vocabulary widget reference refuses the plan (exit 2, no artifacts) naming the token + the `zfa ui schema` fix; in-vocabulary tokens pass | FR-006, US4-AC2 | RED → GREEN (proved, this session) |
| U-1134-g3 | test/plugins/tdd/commands/view_vocabulary_gate_test.dart | command | `zfa tdd view` refuses BEFORE any write (exit 1, subject untouched) on an out-of-vocabulary component token | FR-006, US4-AC3 | RED → GREEN (proved, this session) |
| U-1134-g4 | test/skin/builders/skin_builder_layout_refusal_test.dart | unit | `SkinBuilder` with layout `grid`/`table`/unknown refuses BY NAME (not implemented, not in the vocabulary) and writes NO file; `list`/`form` unchanged | FR-007, US4-AC4 | RED → GREEN (proved, this session) |

Guard pins (pre-existing, must stay green):

| id | suite | description |
| -- | ----- | ----------- |
| #1142 | test/plugins/tdd/commands/spec_1142_adaptive_layout_test.dart | the Presentation-contract-driven adaptive skeleton (unchanged shape) |
| #1142 | test/plugins/tdd/commands/view_command_test.dart | U-V1…U-V13: the deterministic tdd view contract (already-implemented verdict, machine summary) |
| #963 | test/tdd/075-ui-coverage-ledger/ | the 075 surface-ledger discipline |
| #966 | test/tdd/0966-typed-ledger-rows/, test/tdd/1334-typed-ui-coverage-ledger/ | the typed ledger library pins |
| #1004 | test/plugins/tdd/commands/plan_skin_contract_1004_test.dart | Skin Contract parsing + drift refusals |

## Red evidence

Each lane's red run is captured at implementation time (this session) —
suites fail for the missing-behavior reason (no setup errors), then go
green on the lane's code. Final counts land in `tdd/verification.md`.
