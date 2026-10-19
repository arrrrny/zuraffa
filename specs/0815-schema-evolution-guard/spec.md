# Schema evolution guard (spec 815)

Every schema change produces a migration plan: data migrations for sqlite, API
compatibility scores for exposed types, and a breaking-change report naming every
downstream artifact affected (repositories, mocks, caches, tests). `zfa entity
evolve` applies it transactionally, receipts included (Pillar A).

## v0 first slice
- rename-field → generated migration stub + affected-artifact list
- Compatibility score per entity: semver-style (major/minor/patch)
- `--dry-run` machine-readable report per #778

## Done when
- Renaming a field on the todo example migrates data, updates all artifacts, tests green
- A breaking change without a migration plan fails with an actionable proposal

Status: scaffold only (CLI subcommands `zfa entity rename-field` and
`zfa entity evolve`). Full generation pending.
