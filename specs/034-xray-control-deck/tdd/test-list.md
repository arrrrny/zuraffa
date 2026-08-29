# TDD Test List — X-Ray Control Deck

**Spec**: `specs/034-xray-control-deck/spec.md`
**Plan**: `specs/034-xray-control-deck/plan.md`
**Tasks**: `specs/034-xray-control-deck/tasks.md`

## Behaviors

### B01 — XRayMockType color palette

- **Spec**: FR-001 (optional type/color on `@XRayMock`), FR-004 (color-coded buttons)
- **Test**: `test/plugins/xray/xray_mock_type_test.dart` — `valid.color`, `error.color`, `unknown.color`
- **Implementation**: `lib/src/plugins/xray/xray_mock_type.dart`

### B02 — XRayMockType fromString (case-insensitive, fallback to unknown)

- **Spec**: FR-001, FR-002 (YAML `type?` field optional)
- **Test**: `test/plugins/xray/xray_mock_type_test.dart` — `fromString('valid')`, `fromString(null)`, `fromString('garbage')`, `fromString('VALID')`
- **Implementation**: `lib/src/plugins/xray/xray_mock_type.dart` — `static fromString(String?)`

### B03 — XRayMockEntry data class + dedup equality

- **Spec**: FR-001 (entry shape), Edge case (dedup by name+payload pair, not name alone)
- **Test**: `test/plugins/xray/xray_mock_entry_test.dart` — `==` by name+payload; different payloads NOT equal
- **Implementation**: `lib/src/plugins/xray/xray_mock_entry.dart`

### B04 — XRayMockEntry JSON round-trip

- **Spec**: Integration (MCP bridge / detail panel)
- **Test**: `test/plugins/xray/xray_mock_entry_test.dart` — `toJson`/`fromJson` round-trip
- **Implementation**: `lib/src/plugins/xray/xray_mock_entry.dart`

### B05 — XRayMockEntry accepts empty payload

- **Spec**: Edge case (empty-payload testing)
- **Test**: `test/plugins/xray/xray_mock_entry_test.dart` — `payload: ''` accepted
- **Implementation**: `lib/src/plugins/xray/xray_mock_entry.dart`

### B06 — XRayControlDeck starts empty

- **Spec**: FR-006 (programmatic registration surface)
- **Test**: `test/plugins/xray/xray_control_deck_test.dart` — `entries` empty on init
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart`

### B07 — registerEntries populates the registry

- **Spec**: FR-006
- **Test**: `test/plugins/xray/xray_control_deck_test.dart` — `registerEntries([e1])` → `entries.length == 1`
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart` — `registerEntries(List<XRayMockEntry>)`

### B08 — registerEntries dedups by name+payload pair

- **Spec**: Edge case (dedup by name+payload, not name alone)
- **Test**: `test/plugins/xray/xray_control_deck_test.dart` — duplicate name+payload does NOT add; same name + different payload DOES add
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart` — `_entriesByNameAndPayload` map keyed by `"$name\0$payload"`

### B09 — clear empties the registry

- **Spec**: Edge case (reset between sessions)
- **Test**: `test/plugins/xray/xray_control_deck_test.dart` — `clear()` empties
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart` — `clear()`

### B10 — find by name + payload

- **Spec**: FR-006
- **Test**: `test/plugins/xray/xray_control_deck_test.dart` — `find(name, payload)` returns entry or null
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart` — `find(String, String)`

### B11 — inject returns payload or null

- **Spec**: FR-005 (tap button → inject payload), SC-001 (matrix testing)
- **Test**: `test/plugins/xray/xray_control_deck_test.dart` — `inject(name)` returns payload string or null
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart` — `inject(String name)`

### B12 — changes stream emits on register/clear

- **Spec**: FR-008 (YAML update → updated deck); FR-006 (runtime registration surface)
- **Test**: `test/plugins/xray/xray_control_deck_test.dart` — `changes` emits after `registerEntries`/`clear`
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart` — `Stream<List<XRayMockEntry>> get changes`

### B13 — Release-mode registerEntries is a no-op

- **Spec**: FR-007, SC-003 (release builds contain zero X-Ray code)
- **Test**: `test/plugins/xray/xray_control_deck_test.dart` + `test/regression/issue_185_xray_deck_release_strip_test.dart`
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart` — `_isReleaseMode` guard

### B14 — Release-mode inject returns null

- **Spec**: FR-007, SC-003
- **Test**: `test/regression/issue_185_xray_deck_release_strip_test.dart`
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart`

### B15 — Release-mode find returns null

- **Spec**: FR-007, SC-003
- **Test**: `test/regression/issue_185_xray_deck_release_strip_test.dart`
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart`

### B16 — Release-mode toJson reports release_mode: true

- **Spec**: FR-007, SC-003
- **Test**: `test/regression/issue_185_xray_deck_release_strip_test.dart`
- **Implementation**: `lib/src/plugins/xray/xray_control_deck.dart` — `toJson()`

### B17 — XRayMockYaml parses single + multi entries

- **Spec**: FR-002 (`@XRayMock.fromYaml`)
- **Test**: `test/plugins/xray/xray_mock_yaml_test.dart` — single entry; two entries
- **Implementation**: `lib/src/plugins/xray/xray_mock_yaml.dart`

### B18 — XRayMockYaml respects `type` field

- **Spec**: FR-002
- **Test**: `test/plugins/xray/xray_mock_yaml_test.dart` — `type: valid` → `XRayMockType.valid`; no `type` → `unknown`; garbage `type: foo` → `unknown`
- **Implementation**: `lib/src/plugins/xray/xray_mock_yaml.dart`

### B19 — XRayMockYaml throws on missing required field

- **Spec**: FR-002 (clear error message identifying problematic entry + location)
- **Test**: `test/plugins/xray/xray_mock_yaml_test.dart` — missing `name` throws; missing `payload` throws; error message contains the entry index
- **Implementation**: `lib/src/plugins/xray/xray_mock_yaml.dart`

### B20 — XRayMockYaml accepts empty input

- **Spec**: Edge case (no mocks → empty deck)
- **Test**: `test/plugins/xray/xray_mock_yaml_test.dart` — `parse('')` returns `[]`
- **Implementation**: `lib/src/plugins/xray/xray_mock_yaml.dart`

## Summary

- **Total behaviors**: 20
- **Total test files**: 5 (4 new + 1 regression)
- **Total implementation files**: 4 (all new)
- **Spec FR coverage**: FR-001 (B01, B02, B03), FR-002 (B17, B18, B19, B20), FR-003 (existing codegen), FR-004 (B01), FR-005 (B11), FR-006 (B06, B07, B08, B09, B10, B11, B12), FR-007 (B13, B14, B15, B16), FR-008 (B12, B17).
- **Spec SC coverage**: SC-001 (B07+B11 — matrix testing budget), SC-002 (B17+B12 — YAML update → deck updates via the broadcast stream), SC-003 (B13+B14+B15+B16), SC-004 (golden test of generated deck — existing codegen, out of scope here).

## TDD loop order

B01 → B20, one behavior at a time. Red evidence per behavior in `tdd/red/NN-*.md`. Final green state in `tdd/verification.md`.

## Verification gate

After all 20 behaviors are green:
- Run `dart analyze` — no new errors/warnings.
- Run `dart test test/plugins/xray/xray_mock_type_test.dart test/plugins/xray/xray_mock_entry_test.dart test/plugins/xray/xray_control_deck_test.dart test/plugins/xray/xray_mock_yaml_test.dart test/regression/issue_185_xray_deck_release_strip_test.dart` — all pass.
- Record counts in `tdd/verification.md`.
