# Data Model: skin-contract.v1 (issue #1164)

## SkinContract

| Field | Type | Rules |
|---|---|---|
| `schemaVersion` | string | must be `"1"` |
| `routes` | list of `ContractRoute` | required, may be empty only when `states`/rows are also empty |
| `states` | list of `ContractState` | required |
| `platformRows` | list of `ContractPlatformRow` | required |
| `stateRows` | list of `ContractStateRow` | required |

## ContractRoute

| Field | Type | Rules |
|---|---|---|
| `path` | string | required, starts with `/` |
| `view` | string | required, PascalCase view class name |

## ContractState

| Field | Type | Rules |
|---|---|---|
| `view` | string | required |
| `loading` | bool | required |
| `error` | string | required — `none` / `toaster` / `inline` (v1 vocabulary) |
| `empty` | bool | required |

## ContractPlatformRow

| Field | Type | Rules |
|---|---|---|
| `view` | string | required |
| `mobile` / `ios` / `android` / `macos` | bool | required each (adaptive slot declared or not) |

## ContractStateRow

| Field | Type | Rules |
|---|---|---|
| `view` | string | required |
| `row` | string | required, audit-row id |
| `kind` | string | required — `observer` / `listener` / `builder` (v1 vocabulary) |

## Validation rules

- Unknown field at any level → parse error naming the key.
- Missing required section/field → parse error naming it.
- `schemaVersion != "1"` → parse error naming the version.
- Round-trip: model → JSON → model must be equal field-for-field.

## State transitions

- Contract JSON is immutable data; the only transition is absent → parsed → validated
  (schema test) → emitted schema beside the lane plan. Schema file regeneration is a
  deterministic overwrite.
