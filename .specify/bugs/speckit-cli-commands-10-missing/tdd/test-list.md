---
feature: speckit-cli-commands-10-missing
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 3
planned_at: 49e049c4
updated_at: 49e049c4
suite_baseline: unknown
---

# Test List: Speckit CLI Commands missing from extension manifest

Derived from `spec.md` (issue #499). The extension advertises commands through
`extension.yml` `provides:` entries; each must cover a `zfa manifest` command.
`outer-only` because no `plan.md` exists yet; the "implementation" is generating
documentation files plus registry entries, not component logic.

## Outer loop: acceptance behaviors

| id  | behavior                                                                                 | traces | kind    | state    | test                                                          |
| --- | ---------------------------------------------------------------------------------------- | ------ | ------- | -------- | ------------------------------------------------------------- |
| A1  | Every `zfa manifest` command resolves to a `provides:` alias in the speckit extension   | AC1    | example | RED      | `test/cli/standard/extension_command_parity_test.dart::parity` |
| A2  | Each generated command `.md` carries the template shape (frontmatter + 5 sections)       | AC2    | example | PENDING  | `test/cli/standard/extension_command_parity_test.dart::shape`  |
| A3  | Running the parity check reports 0 missing commands                                      | AC3    | example | PENDING  | `test/cli/standard/extension_command_parity_test.dart::parity` |

## Inner loop: unit behaviors

Not derived: this bug adds no component logic, only registry entries and doc files.
The acceptance test (A1/A3) is the load-bearing behavior; A2 guards the doc shape.

## Invariants and edge cases still to place

- The alias mapping from `manifest(plugin, name)` to `zfa` alias is irregular by
  design; the test encodes the known exceptions (`method_append` → `method` /
  `method-append`, `private-method` → `.private`). Any new irregular plugin must be
  added there, not worked around in the extension.

## Out of scope

- Implementing the `zfa generate-commands` regeneration script (tracked separately).
- Re-categorizing already-covered commands.

## Verification commands (from profile)

- Single test: `dart test test/cli/standard/extension_command_parity_test.dart`
- Feature scope: `dart test test/cli/standard/`
- Analyze: `dart analyze lib/src/cli/standard/ lib/src/plugins/cli/ test/cli/standard/`
