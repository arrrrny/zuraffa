# Feature Specification: Spec template [CORE]/[SKIN] lane markers + AdaptiveViewSlots + Engine/Skin plan split

**Feature Branch**: `1000-spec-template-core-skin-lanes`

**Created**: 2026-09-05

**Status**: Draft

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/1000 — [ZIKZAK-REBUILD] Spec template: [CORE] and [SKIN] lane markers + AdaptiveViewSlots (S-TRACK). The engine/skin split begins with the spec contract."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Lanes-declaring spec plans into engine and skin lane files (Priority: P1)

A spec author declares a `## Lanes` section in the zuraffa-1.0 template: each lane names the behavior ids it owns (ranges like `U1-U6` expand), whether Flutter is allowed (`false` for CORE, `true` for SKIN, `conditionally` for BOTH), and — for SKIN — the AdaptiveViewSlots the skin must provide (`[mobile, ios, android, macos]`). `zfa tdd plan <feature>` reads the declaration and emits a SPLIT plan instead of the single behavior table: `tdd/04-ENGINE.md` (behaviors whose lane is CORE or BOTH), `tdd/04-SKIN.md` (behaviors whose lane is SKIN or BOTH), and `tdd/04-CONTRACT.md` (the engine/skin seam: AdaptiveViewSlots, the BOTH-lane shared behaviors, and the flutter boundary statement). The old `tdd/test-list.md` becomes a META-INDEX: no behavior rows, just the lane table and the pointers to the three split files. A spec with no `## Lanes` section plans exactly as before — one `tdd/test-list.md` with the behavior tables, byte-stable with the legacy shape.

**Why this priority**: The engine/skin split is the single most important structural change per the fleet report, and it begins with the spec contract: until the spec can SAY which behaviors are pure Dart engine and which are Flutter skin, every downstream tool (gen, make, run) has to guess from prose. The lane declaration is the rung-1 declaration for the engine/skin axis, exactly as `**Type**` markers are for the subject-kind axis.

**Independent Test**: Can be fully tested by authoring a spec whose Lanes section declares `A1, A2, U1-U6` CORE, `W1-W4` SKIN with adaptive slots `[mobile, ios, android, macos]`, and `A3` BOTH, then running `zfa tdd plan <feature>` and confirming the three 04-* files exist (no `04-test-list.md`), that `04-ENGINE.md` contains zero `package:flutter` references, that `04-SKIN.md` contains the declared AdaptiveViewSlots, and that a control spec without `## Lanes` still emits the single legacy `test-list.md`. Delivers: the engine/skin split expressed as a plan-time declaration instead of prose guesswork.

**Acceptance Scenarios**:

1. **Given** a spec declaring `## Lanes` with CORE `[A1, A2, U1-U6]`, SKIN `[W1-W4]` + `adaptive_slots: [mobile, ios, android, macos]`, and BOTH `[A3]`, **When** `zfa tdd plan <feature>` runs, **Then** `tdd/04-ENGINE.md`, `tdd/04-SKIN.md`, and `tdd/04-CONTRACT.md` are emitted and no file named `04-test-list.md` exists.
2. **Given** the emitted `04-ENGINE.md`, **When** its content is scanned, **Then** it contains zero occurrences of `package:flutter` (the engine lane is pure Dart by construction).
3. **Given** the emitted `04-SKIN.md`, **When** its content is scanned, **Then** it contains the AdaptiveViewSlots declared in the spec (`mobile`, `ios`, `android`, `macos`).
4. **Given** a spec with NO `## Lanes` section, **When** `zfa tdd plan <feature>` runs, **Then** the output is the single legacy `tdd/test-list.md` with behavior tables (no 04-* files) — existing test semantics unchanged.
5. **Given** the meta-index `test-list.md` written for a Lanes-declaring spec, **When** `TestListReader.read()` runs, **Then** it resolves the same behavior rows as before the split (engine rows + skin rows, BOTH behaviors appearing once) so gen/make/run keep working unmodified.

---

### User Story 2 - The noFlutter guard rejects CORE behaviors that reference package:flutter (Priority: P1)

Plan generation enforces the engine boundary: a behavior destined for `04-ENGINE.md` (lane CORE — or BOTH, whose engine copy must be pure Dart) whose row text references `package:flutter`, or whose subject kind is Flutter-only (`widget`/`theme`, whose gen pair imports Flutter), is a lane violation. Plan refuses it before any artifact is written: exit 2, the offending behavior id and line named, and a `--> fix:` instruction telling the author to move the behavior to the SKIN lane or drop the Flutter reference. Nothing is emitted on refusal — an incomplete split never leaves a half-written lane plan claiming completeness.

**Why this priority**: A guard that only lives in the view widget writers (where the equivalent check exists today) is enforced at generation time, after the plan has already promised the split. Making it plan-enforced moves the failure to the earliest possible moment — the contract, before a single test is scaffolded.

**Independent Test**: Can be fully tested by declaring a CORE behavior whose description names `package:flutter/material.dart`, running `zfa tdd plan <feature>`, and confirming exit 2 with the behavior named and no artifacts written (no test-list.md, no 04-* files). Delivers: the engine lane's purity is a checked contract, not a convention.

**Acceptance Scenarios**:

1. **Given** a spec whose CORE lane declares a behavior whose description references `package:flutter`, **When** `zfa tdd plan <feature>` runs, **Then** it exits 2 naming the behavior and the fix, and writes no artifacts.
2. **Given** a spec whose CORE lane declares a behavior routed widget-kind (UI-observable prose), **When** `zfa tdd plan <feature>` runs, **Then** it exits 2 naming the Flutter-only kind and the SKIN lane fix.
3. **Given** a spec whose Lanes section omits a spec-derived behavior from every lane, **When** `zfa tdd plan <feature>` runs, **Then** it exits 2 naming the undeclared behavior and the lane declaration to add (declarations win; gaps surface, never default silently).

---

### User Story 3 - `zfa tdd split <feature>` migrates an existing plan in one shot (Priority: P2)

Features planned before the lane grammar carry a single `tdd/test-list.md` with behavior rows. `zfa tdd split <feature>` reads that old plan, classifies every behavior row CORE or SKIN, and emits the new plan pair — `04-ENGINE.md`, `04-SKIN.md`, `04-CONTRACT.md` — plus `split-receipt.json`, converting `test-list.md` into the meta-index. Classification consults the spec's `## Lanes` declaration when the feature's spec declares one (declarations win); otherwise it is deterministic from the row's kind: `widget`/`theme` rows are SKIN, everything else (acceptance/unit/ffi/platform) is CORE. The receipt records every classification so the migration is auditable, and the command is one-shot: a feature whose receipt already exists (or whose test-list is already a meta-index) is refused with a pointer to the receipt, never silently re-split.

**Why this priority**: The ZIKZAK rebuild fleet (001-shoe-size-tracker, 002-login, 003-widget-probe, 004-login-ui) has live plans in the legacy shape; without a one-shot migration each of them would have to be re-authored by hand, and hand migration is exactly where rows get dropped.

**Independent Test**: Can be fully tested by seeding a legacy `tdd/test-list.md` (acceptance, unit, and widget rows) for a feature, running `zfa tdd split <feature>`, and confirming all three 04-* files exist with the widget rows in `04-SKIN.md`, the rest in `04-ENGINE.md`, a `split-receipt.json` recording each row's lane, the meta-index in place of the old table, and a second run refusing with a receipt pointer. Delivers: the whole legacy fleet migrates onto the lane split with one command and an audit trail.

**Acceptance Scenarios**:

1. **Given** a feature with a legacy single-file `tdd/test-list.md` (mixed acceptance, unit, and widget rows), **When** `zfa tdd split <feature>` runs, **Then** `04-ENGINE.md`, `04-SKIN.md`, `04-CONTRACT.md`, and `tdd/split-receipt.json` are produced, and `test-list.md` is now the meta-index.
2. **Given** the receipt, **When** it is read, **Then** every prior behavior id appears exactly once with its assigned lane (widget/theme rows SKIN, the rest CORE) and the emitted file list.
3. **Given** a feature already split (receipt exists), **When** `zfa tdd split <feature>` runs again, **Then** it refuses non-zero naming the receipt — one-shot, never a silent re-split.
4. **Given** a feature whose spec declares `## Lanes`, **When** `zfa tdd split <feature>` runs, **Then** the classification follows the spec's lane declaration instead of the kind heuristic (declarations win).

---

### User Story 4 - The spec template carries the Lanes grammar (Priority: P2)

`.specify/templates/spec-template.md` — the file `create-new-feature.sh` copies into every new spec — gains the `## Lanes` section with the documented grammar (lane name, behaviors list with range and annotation support, `flutter_allowed`, `adaptive_slots`) and a worked example, so new specs are authored against the lane contract from day one instead of retrofitting it. The section is documented as optional-and-skippable exactly like Key Entities: a spec without it plans the legacy single-file shape.

**Why this priority**: A grammar that only exists in the parser is a grammar nobody writes; the template is the authoring surface where the contract meets the spec writer.

**Independent Test**: Can be fully tested by reading the template and confirming the `## Lanes` section documents the three lanes, the behaviors/range syntax, `flutter_allowed`, and `adaptive_slots`, and that a spec copied from the template with the section filled in parses via `SpecParser.parseLanes`. Delivers: the lane grammar on the authoring surface.

**Acceptance Scenarios**:

1. **Given** the repo's `.specify/templates/spec-template.md`, **When** the `## Lanes` section is read, **Then** it documents CORE/SKIN/BOTH, `behaviors` (with ranges like `U1-U6` and annotations like `A3 (acceptance: navigates to deal_list)`), `flutter_allowed`, and `adaptive_slots`.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system shall parse a spec's `## Lanes` section into lane declarations (lane name, behavior ids with `U1-U6` ranges and `(...)` annotations expanded, `flutter_allowed`, `adaptive_slots`), accepting the section content whether the yaml block is fenced or bare.
- **FR-002**: `zfa tdd plan <feature>` on a Lanes-declaring spec shall emit `tdd/04-ENGINE.md` (behaviors whose lane is CORE or BOTH), `tdd/04-SKIN.md` (behaviors whose lane is SKIN or BOTH), and `tdd/04-CONTRACT.md`, and shall NOT emit any file named `04-test-list.md`.
- **FR-003**: The emitted `04-ENGINE.md` shall contain zero occurrences of `package:flutter` in its rendered content.
- **FR-004**: The emitted `04-SKIN.md` shall contain the AdaptiveViewSlots the spec's SKIN lane declares.
- **FR-005**: `zfa tdd plan` shall refuse (exit 2, no artifacts) a behavior destined for the engine plan whose row references `package:flutter` or whose kind is Flutter-only (`widget`, `theme`), naming the behavior and a `--> fix:` line.
- **FR-006**: `zfa tdd plan` shall refuse (exit 2, no artifacts) a spec-derived behavior that no lane declares, naming the behavior and the declaration to add.
- **FR-007**: `zfa tdd plan` on a spec with no `## Lanes` section shall emit the single legacy `tdd/test-list.md` byte-stable with the pre-1000 shape.
- **FR-008**: `TestListReader.read()` shall resolve behavior rows from the split files (engine then skin, BOTH ids deduplicated to their first occurrence) when `tdd/test-list.md` is a lane meta-index, and shall parse legacy lists exactly as before.
- **FR-009**: `TestListReader` entity/dependency/layer-contract reads shall fall back to `04-ENGINE.md` when the meta-index carries no such sections.
- **FR-010**: A new `zfa tdd split <feature>` command shall read the legacy `tdd/test-list.md`, classify rows CORE/SKIN (spec `## Lanes` declarations winning over the kind heuristic: widget/theme to SKIN, the rest CORE), emit the three 04-* files plus `tdd/split-receipt.json`, and convert `test-list.md` into the meta-index.
- **FR-011**: `zfa tdd split` shall be one-shot: a feature with an existing `split-receipt.json` or an already-meta-indexed `test-list.md` is refused non-zero naming the receipt.
- **FR-012**: The spec template `.specify/templates/spec-template.md` shall document the `## Lanes` grammar with a worked example.

### Key Entities *(include if feature involves data)*

- **LaneDeclaration**: one parsed lane of the `## Lanes` section — `lane` (CORE/SKIN/BOTH), `behaviorIds` (expanded ids, annotations stripped), `flutterAllowed` (verbatim `false`/`true`/`conditionally`), `adaptiveSlots` (SKIN's declared slots), `annotations` (id -> parenthetical description text).
- **LaneSplit**: the plan-time lane resolution — every behavior row's lane, the engine/skin/contract file set, and the meta-index content; shared by `plan` and `split` so both emit the same shape.
- **SplitReceipt**: the `tdd/split-receipt.json` record — feature, per-behavior classification, emitted files, adaptive slots, engine flutter-reference count.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1-U6]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1-W4]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3 (acceptance: the split plan satisfies issue #1000 end to end)]
    flutter_allowed: conditionally
```

## Success Criteria *(mandatory)*

### Measurable Outcomes

- `zfa tdd plan 004-login-ui` on a Lanes-declaring fixture emits `04-ENGINE.md`, `04-SKIN.md`, `04-CONTRACT.md`; no `04-test-list.md`; `test-list.md` is the meta-index.
- `04-ENGINE.md` scans clean for `package:flutter` (zero occurrences).
- `04-SKIN.md` contains `mobile`, `ios`, `android`, `macos` (the declared AdaptiveViewSlots).
- `zfa tdd split 004-login-ui` on a legacy fixture produces all three files plus `split-receipt.json`.
- The full existing fast suite passes with no semantic change (legacy plans parse identically).

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| ---------- | ---- | -------- | ------------- |
| (none) | - | - | - |

## Assumptions

- The 04- prefix is the issue's naming for the plan-stage artifacts of the TDD workflow; the legacy `test-list.md` filename is kept as the meta-index so every existing consumer path (gen/make/run/corpus) keeps resolving.
- Behaviors a Lanes section declares but the spec prose does not derive (e.g. `W1-W4` with no matching scenario/FR) render as hand-declared lane rows — the same status theme/platform rows already carry (plan tolerates hand-maintained rows; it never invents their prose beyond the lane annotation).
