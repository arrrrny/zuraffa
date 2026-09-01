# Contract: Bone Manifest (`bone.yaml`)

The manifest is the single source of truth an external agent reads to
understand a bone. Schema version `1`.

## Example

```yaml
version: 1
feature: checkout-flow
generated_at: "2026-08-29T12:00:00.000Z"
spec_version: sha256:9f2c1a...64-hex-chars
entities:
  - Cart
  - CartItem
dependencies:
  - bone: product-catalog
    entities: [Product]
layers:
  - domain
  - data
  - presentation
```

## Schema

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `version` | int | yes | currently `1`; consumers must reject unknown versions |
| `feature` | string | yes | kebab-case slug, matches bone directory name |
| `generated_at` | ISO-8601 string | yes | UTC emission time |
| `spec_version` | string | yes | `sha256:` + 64 lowercase hex chars |
| `entities` | list<string> | yes | ≥ 1 entry; PascalCase names |
| `dependencies` | list<object> | yes | may be empty `[]` |
| `dependencies[].bone` | string | yes | slug of an existing/known bone |
| `dependencies[].entities` | list<string> | yes | ≥ 1 shared entity name |
| `layers` | list<string> | yes | subset of `domain`, `data`, `presentation` |

## Bone directory layout

```text
<feature-slug>/
├── bone.yaml                 # this manifest
├── lib/
│   ├── entities/<snake>.dart # one stub per declared entity
│   └── <feature_slug>.dart   # barrel entry point exporting the stubs
├── domain/README.md          # layer placeholders
├── data/README.md
├── presentation/README.md
└── test/                     # test stubs (compose with tdd plugin)
```

**Self-containment rule**: every `import`/`export` in `lib/**` resolves to a
file inside the bone, `dart:*`, or a bone listed in `dependencies`.
