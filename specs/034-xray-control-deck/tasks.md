# Tasks: X-Ray Control Deck — @XRayMock Decorator & Synthetic Payload Injector

**Input**: Design documents from `specs/034-xray-control-deck/`

**Prerequisites**: plan.md, spec.md.

**Tests**: Tasks marked `[T]` are behavior-driving test tasks written FIRST (TDD red).

**Organization**: Tasks grouped by user story from `spec.md`.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T01 [P?] US1 Confirm `lib/src/plugins/xray/` directory exists (already populated by prior X-Ray work).

## Phase 2: Type + Entry (User Story 1 — Annotate a UseCase with Mock Payloads, P1)

- [ ] T02 [T] US1 RED: Write `test/plugins/xray/xray_mock_type_test.dart`:
  - `XRayMockType.valid.color` is `0xFF00C853` (neon green).
  - `XRayMockType.error.color` is `0xFFD50000` (red).
  - `XRayMockType.unknown.color` is `0xFF9E9E9E` (neutral grey).
  - `XRayMockType.fromString('valid')` returns `XRayMockType.valid`.
  - `XRayMockType.fromString('error')` returns `XRayMockType.error`.
  - `XRayMockType.fromString(null)` returns `XRayMockType.unknown`.
  - `XRayMockType.fromString('garbage')` returns `XRayMockType.unknown`.
  - `XRayMockType.fromString('VALID')` (case-insensitive) returns `XRayMockType.valid`.
  - `.label` returns `"valid"` / `"error"` / `"unknown"`.
- [ ] T03 US1 GREEN: Implement `lib/src/plugins/xray/xray_mock_type.dart`. Passes T02.
- [ ] T04 [T] US1 RED: Write `test/plugins/xray/xray_mock_entry_test.dart`:
  - `XRayMockEntry(name: 'A', payload: 'p1')` defaults `type` to `XRayMockType.unknown`.
  - `XRayMockEntry(name: 'A', payload: 'p1', type: XRayMockType.valid)` stores all fields.
  - Two entries with the same name+payload are equal (operator ==).
  - Two entries with the same name but different payloads are NOT equal.
  - `toJson()` produces `{"name", "payload", "type"}`.
  - `XRayMockEntry.fromJson(json)` round-trips.
  - Empty `payload: ''` is accepted as a valid mock (edge case from spec).
- [ ] T05 US1 GREEN: Implement `lib/src/plugins/xray/xray_mock_entry.dart`. Passes T04.

## Phase 3: Registry (User Story 4 — Programmatic Mock Registration, P2)

- [ ] T06 [T] US4 RED: Write `test/plugins/xray/xray_control_deck_test.dart`:
  - `XRayControlDeck.instance.entries` starts empty.
  - `registerEntries([e1])` populates the registry; `entries.length == 1`.
  - `registerEntries` with duplicate name+payload does NOT add a second entry (dedup).
  - `registerEntries` with same name but different payload DOES add (per the edge case).
  - `clear()` empties the registry.
  - `find(name, payload)` returns the entry or `null`.
  - `inject(name)` returns the payload string for a registered entry, or `null` for unknown.
  - `changes` stream emits the new snapshot after `registerEntries` / `clear`.
  - In release mode (`XRayControlDeck(isReleaseMode: true)`), `registerEntries` is a no-op; `entries` stays empty; `inject` returns null.
- [ ] T07 US4 GREEN: Implement `lib/src/plugins/xray/xray_control_deck.dart`. Passes T06.

## Phase 4: YAML Parser (User Story 2 — YAML-Based Scenario Definition, P1)

- [ ] T08 [T] US2 RED: Write `test/plugins/xray/xray_mock_yaml_test.dart`:
  - `XRayMockYaml.parse(yaml)` with a single entry `- name: A\n  payload: p1\n` returns one entry.
  - `XRayMockYaml.parse` with two entries returns both.
  - `XRayMockYaml.parse` with `type: valid` populates `XRayMockType.valid`.
  - `XRayMockYaml.parse` with no `type` field defaults to `XRayMockType.unknown`.
  - `XRayMockYaml.parse` with garbage `type: foo` falls back to `XRayMockType.unknown`.
  - `XRayMockYaml.parse` with a missing required `name` field THROWS with a clear message identifying the offending entry index.
  - `XRayMockYaml.parse` with a missing required `payload` field THROWS.
  - `XRayMockYaml.parse('')` returns an empty list (not an error).
  - `XRayMockYaml.parseFile(path)` reads a YAML file from disk.
- [ ] T09 US2 GREEN: Implement `lib/src/plugins/xray/xray_mock_yaml.dart`. Passes T08.

## Phase 5: Release-strip Regression (User Story 5 — Release Build Exclusion, P2)

- [ ] T10 [T] US5 RED: Write `test/regression/issue_185_xray_deck_release_strip_test.dart`:
  - `kXrayReleaseMode` is a compile-time constant (false in test runs).
  - `XRayControlDeck(isReleaseMode: true).registerEntries([...])` is a no-op — `entries` stays empty, `changes` stream emits nothing.
  - `XRayControlDeck(isReleaseMode: true).inject('any')` returns `null`.
  - `XRayControlDeck(isReleaseMode: true).find('a', 'b')` returns `null`.
  - `XRayControlDeck(isReleaseMode: true).toJson()` returns `{"active": false, "release_mode": true, "entries": []}`.
- [ ] T11 US5 GREEN: Implement the release guard in `xray_control_deck.dart`. Passes T10.

## Phase 6: Verify

- [ ] T12 Run `dart analyze` — must not introduce new errors/warnings.
- [ ] T13 Run `dart test test/plugins/xray/xray_mock_type_test.dart test/plugins/xray/xray_mock_entry_test.dart test/plugins/xray/xray_control_deck_test.dart test/plugins/xray/xray_mock_yaml_test.dart test/regression/issue_185_xray_deck_release_strip_test.dart` — all green.
- [ ] T14 Write `specs/034-xray-control-deck/tdd/verification.md` mapping each FR-001..008 and SC-001..004 to tests.
- [ ] T15 Commit artifacts + push + open PR (closes #185).
