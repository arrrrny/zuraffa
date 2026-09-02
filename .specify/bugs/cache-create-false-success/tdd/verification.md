# Verification: Issue #772 — `cache create` false-success on nonexistent entity

Cycle: SDD spec → RED → GREEN → verify (all runs this session, branch
`fix/772-cache-create-entity-validation`, base master `6921c730`,
Dart 3.13.3).

## Evidence

| # | Check | Command | Result |
|---|-------|---------|--------|
| B1 | Mechanism | code trace | `CreateCacheCapability._generateFiles` never validated the entity; `plugin.generate` returned 0 files → `CapabilityCommand` empty-files branch printed `✅ Success! (No changes required)`, exit 0 |
| R1 | RED false success | `dart test test/plugins/cache/create_cache_capability_validation_test.dart` | FAILED pre-fix: `execute({'name':'Ghost'})` → `success == true`, no message (expected not-found failure) |
| R2 | RED available-entities parity | same run | FAILED pre-fix (no failure raised at all) |
| R3 | Guard (pre-fix) | same run | existing-entity test passed by design |
| G1 | GREEN unit | same file, post-fix | **3/3 pass** (not-found failure; `Available entities:\n  - Auth` listed; real entity not rejected) |
| G2 | Real CLI, missing entity | `zfa cache create --name cart` (scratch, only `Auth` exists) | `❌ Failed: Exception: Entity 'cart' not found.` + `Available entities:\n  - Auth` — matches sibling `cache adapter` UX |
| G3 | Real CLI, existing entity | `zfa cache create --name Auth` | validation passes; generator proceeds (minimal entity yields 0 files — the separate silent-no-op family #766/#768/#770, out of scope here) |
| S1 | Regression | `dart test test/plugins/cache/ test/commands/` | **70/70 pass** |
| S2 | Static analysis | `dart analyze` | No issues found |
| S3 | Format | `dart format` touched files | clean |

## Fix summary

- `CreateCacheCapability`: new `_validateEntityExists` mirroring the sibling
  `CreateCacheAdapterCapability` — entity file check (`domain/entities/<snake>/<snake>.dart`),
  enum fallback (index or per-file `enum <Name>`), and an
  `Available entities:` discovery list on failure.
- `execute()` wraps generation in try/catch → `ExecutionResult(success:false,
  message)` so failures are capability-owned and render as `❌ Failed: ...`
  (never raw stack traces, never false success).
- `CreateCacheAdapterCapability` untouched (FR-4).

## What was not audited

- The broader zero-files-success family (#766/#768/#770) — separate root
  causes, tracked separately.
- Extracting the adapter's resolver into a shared helper (DRY follow-up
  noted in spec; deliberately deferred).
