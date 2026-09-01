# Bug Assessment: zfa tdd make uses behavior ID as entity name for zfa make

- **Slug**: tdd-make-uses-behavior-id-as-entity-name
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/696
- **Verdict**: valid
- **Severity**: high

## Report

`zfa tdd make` for unit behaviors tries to run `zfa make <behaviorId>` (lowercased), treating the behavior ID as an entity name. Behavior IDs like `u5`, `u6` are NOT entity names, so `zfa make` fails with `no entity source file was found`.

## Symptom

`zfa tdd make U5` → `zfa make u5` → `no entity source file was found`.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart` — passes behavior ID to `zfa make`.

## Root Cause Hypothesis

`make` lowercases the behavior ID and passes it to `zfa make` as an entity name. Behavior IDs are not entity names. Confidence: **high**.

## Proposed Remediation

Derive the actual entity name from the behavior's trace (FR-xxx) or use `--no-entity` flag for unit behaviors that don't map to entities.

## Open Questions

- None blocking.