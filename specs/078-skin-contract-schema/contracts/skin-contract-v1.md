# Contract: skin-contract.v1 JSON (issue #1164)

**Location inside spec**: fenced JSON under `## Skin Contract:`.
**Generated artifact**: `specs/<feature>/tdd/04-skin-contract.schema.json` (JSON Schema, emitted by `zfa tdd plan`).

## Schema (v1)

```json
{
  "schemaVersion": "1",
  "routes": [
    { "path": "/login", "view": "LoginPage" }
  ],
  "states": [
    { "view": "LoginPage", "loading": false, "error": "toaster", "empty": false }
  ],
  "platformRows": [
    { "view": "LoginPage", "mobile": true, "ios": true, "android": true, "macos": false }
  ],
  "stateRows": [
    { "view": "LoginPage", "row": "error-toaster", "kind": "observer" }
  ]
}
```

## Rules

1. `schemaVersion` is exactly `"1"` in v1.
2. All four sections are required; each row object must carry exactly the fields listed
   in data-model.md — unknown fields are parse errors naming the key.
3. `routes[].path` starts with `/`; `routes[].view` is a PascalCase class name.
4. `states[].error` ∈ {none, toaster, inline}; `stateRows[].kind` ∈ {observer, listener, builder}.
5. The emitted JSON Schema validates every field above, requires every required field,
   and forbids additional properties — it is generated from the model, never hand-edited.

## Emitter contract (`zfa tdd plan`)

- Spec contains `## Skin Contract:` → `specs/<feature>/tdd/04-skin-contract.schema.json`
  is (re)written deterministically.
- Spec lacks the section → nothing written, plan output otherwise unchanged.
