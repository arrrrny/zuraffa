# Contract: `zfa bone` CLI

The skeleton plugin exposes one command tree via `CliAwarePlugin`. Exit code 0
on success, non-zero with a stderr message on any validation failure.

## `zfa bone generate <feature-slug>`

Generate (or regenerate) the bone for one feature.

| Arg / flag | Type | Default | Meaning |
|------------|------|---------|---------|
| `<feature-slug>` | positional | required | directory name under `specs/` (e.g. `020-skeleton-plugin-bones`) |
| `--spec <path>` | path | `specs/<slug>/spec.md` | override the source spec |
| `--entity <Name>` | repeatable | auto-detect | explicitly declare an entity |
| `--depends-on <slug>` | repeatable | auto-detect | explicitly declare a bone dependency |
| `--output <dir>` | path | `.zfa/bones` | bone root directory |

**Success output**: writes `.zfa/bones/<feature-slug>/` containing `bone.yaml`,
`lib/entities/*.dart` stubs, layer placeholders (`domain/`, `data/`,
`presentation/`), and prints the bone path to stdout.

**Failure modes** (all exit non-zero, no partial output):
- spec missing or unreadable
- spec declares no entities (missing-field validation)
- referenced entity not found in any known feature (missing dependency)
- circular dependency detected (message names the bones in the cycle)
- conflicting definitions of the same entity name across features

## `zfa bone export <feature-slug>`

Package a generated bone into a single transferable artifact.

| Arg / flag | Type | Default | Meaning |
|------------|------|---------|---------|
| `<feature-slug>` | positional | required | bone to export |
| `--output <path>` | path | `.zfa/bones/<slug>.tar.gz` | artifact destination |

**Success output**: writes `<slug>.tar.gz` containing the full bone directory;
prints the artifact path to stdout. Fails (non-zero) if the bone has not been
generated yet.

## `zfa bone validate <feature-slug>`

Re-check an existing bone for self-containment (FR-005) and spec staleness
(FR-008). Exit 0 when clean; non-zero listing violations otherwise. Intended
for CI and for delegate agents verifying a received bone.
