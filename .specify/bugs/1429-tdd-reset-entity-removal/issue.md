# Bug Issue: TDD reset doesn't revert phase-0 entity_create — no receipted entity-removal verb, permanent proof-preflight 'deleted' finding

- **Slug**: 1429-tdd-reset-entity-removal
- **Fetched**: 2026-09-15T20:04:47Z
- **Issue**: 1429
- **URL**: https://github.com/arrrrny/zuraffa/issues/1429
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: (none)

## Body

zfa 6.2.2 (macOS). Repo: arrrrny/zuraffa_intents, feature 002-publishable-plugin.

### Repro

1. A spec's `### Key Entities` table declares a row whose name collides with a Flutter SDK type (`PlatformException` — declared as the pigeon error envelope; the author intent was documentation, not a new domain entity).
2. `zfa tdd run` phase-0 honestly scaffolds it: `entity PlatformException -> created` → `lib/src/domain/entities/platform_exception/` + an `entity_create` proof receipt.
3. The author realizes the row was over-declared (the contract surfaces Flutter's PlatformException verbatim — the domain duplicate is dead code). `zfa tdd reset <feature>` reverts the behavior artifacts but NOT the phase-0 entity creation.
4. Deleting the entity files leaves the `entity_create` receipt pointing at missing paths → `ProofChecker` reports `deleted` findings forever, and `zfa tdd verify` for that feature is NOT_ASSESSED permanently (the preflight filter scopes by `input.feature`).

### The gap

- `zfa tdd reset` (the designed undo verb) doesn't revert phase-0 entity scaffolds.
- `zfa entity` has no remove/delete subcommand, and no verb writes a tombstone/receipt for a removed entity — so a legitimate spec correction permanently poisons the proof preflight.
- Also worth considering: phase-0 creating a domain entity whose name collides with a `package:flutter` type (e.g. PlatformException, BuildContext) deserves at least a warning — a same-named domain class invites import ambiguity the moment both are in scope.

### Workaround used to continue

Removed the entity files and pruned the single `entity_create` receipt from the local store (documented in the PR), then fixed the spec's Key Entities table. Works, but hand-editing the provenance store should not be the only path back from a mis-declared entity.

## Comments

None.
