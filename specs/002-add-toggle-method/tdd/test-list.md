# TDD Test List: Add Toggle Method to Entity MethodList

**Feature**: 002-add-toggle-method  
**Generated**: 2026-08-26  
**Planned at commit**: 614e648  
**Mode**: outer-only (no plan.md exists)

## Test List Format
- **Behavior ID**: Unique identifier (A1, A2... for acceptance; U1, U2... for unit)
- **Type**: acceptance | unit | integration | property
- **Source**: spec.md section or plan.md component
- **Status**: DONE | PENDING | BLOCKED
- **Test Name**: Exact test name as it appears in test files
- **Test Path**: File path relative to repo root
- **Notes**: Any relevant context

---

## Acceptance Behaviors (from spec.md)

| ID | Type | Source | Status | Test Name | Test Path | Notes |
|---|---|---|---|---|---|---|
| A1 | acceptance | User Story 1, Scenario 1 | DONE | toggle method is generated across all layers | test/integration/toggle_method_test.dart | Existing integration test covers this |
| A2 | acceptance | User Story 1, Scenario 2 | DONE | toggle method accepts ID, field, and boolean value | test/integration/toggle_method_test.dart | Verified by checking method signatures |
| A3 | acceptance | User Story 2, Scenario 1 | DONE | toggle method uses ToggleParams<String, Field<Entity, dynamic>> | test/integration/toggle_method_test.dart | Checked in repository interface test |
| A4 | acceptance | User Story 2, Scenario 2 | DONE | ToggleParams has id, field, value fields | test/plugins/toggle_value_param_test.dart | ToggleParams class test |
| A5 | acceptance | User Story 3, Scenario 1 | DONE | toggle uses `toggleValue` param when idField=`value` | test/plugins/toggle_value_param_test.dart | #302 collision fix |
| A6 | acceptance | User Story 3, Scenario 2 | DONE | canonical Todo (id=`id`) uses `toggleValue` param | test/plugins/toggle_value_param_test.dart | Lock in no behavioral break |

---

## Unit Behaviors (from existing code inspection)

| ID | Type | Source | Status | Test Name | Test Path | Notes |
|---|---|---|---|---|---|---|
| U1 | unit | EntityUseCaseGenerator.toggle case | DONE | Toggle usecase generated with ToggleParams | test/integration/toggle_method_test.dart | Line 60-71 |
| U2 | unit | PresenterPlugin._buildToggleMethod | DONE | Presenter toggle uses toggleValue param | test/plugins/toggle_value_param_test.dart | Line 45-97 |
| U3 | unit | ControllerPlugin._buildToggleMethod | DONE | Controller toggle uses toggleValue param | test/plugins/toggle_value_param_test.dart | Line 99-140 |
| U4 | unit | Repository interface generator | DONE | Repository interface has toggle method | test/integration/toggle_method_test.dart | Line 47-58 |
| U5 | unit | Data repository implementation | DONE | Data repo calls _dataSource.toggle(params) | test/integration/toggle_method_test.dart | Line 73-85 |
| U6 | unit | Remote datasource generator | DONE | Remote datasource throws UnimplementedError | test/integration/toggle_method_test.dart | Line 100-117 |
| U7 | unit | Local datasource generator | DONE | Local datasource uses copyWithField | test/integration/toggle_method_test.dart | Line 119-136 |
| U8 | unit | State generator | DONE | State has isToggling field | test/integration/toggle_method_test.dart | Line 138-147 |
| U9 | unit | Test plugin (toggle method) | DONE | #289 — toggle test file generated | test/integration/toggle_method_test.dart | Line 179-231 |

---

## Edge Case Behaviors (from existing tests)

| ID | Type | Source | Status | Test Name | Test Path | Notes |
|---|---|---|---|---|---|---|
| E1 | regression | Issue #302 | DONE | Toggle param collision with entity field `value` | test/regression/issue_302_toggle_param_collision_test.dart | Barcode entity scenario |
| E2 | regression | Issue #289 | DONE | Toggle test file generated with test plugin | test/integration/toggle_method_test.dart | Line 179-231 |
| E3 | regression | Issue #307 | DONE | id-less entity resolves no id (no first-field fallback) | test/regression/issue_302_toggle_param_collision_test.dart | Line 68-98 |

---

## Summary

- **Total Behaviors**: 17 (6 Acceptance + 9 Unit + 3 Edge Case/Regression)
- **DONE**: 17
- **PENDING**: 0
- **BLOCKED**: 0

All behaviors are already covered by existing tests. The toggle method feature appears to be fully implemented and tested.