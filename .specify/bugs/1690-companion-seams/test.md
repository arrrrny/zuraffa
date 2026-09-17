# Bug Verification: 1690-companion-seams

- **Slug**: 1690-companion-seams
- **Tested**: 2026-09-18
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (fallback audit — verdict:
  verified, 4/4 sampled mutants killed)

## Summary

Both pre-publish seams are closed. The documented `path:` install now
works end-to-end: a real `dart pub get` against relative path deps
produces the relative-rootUri package config, `PluginGate.companionEntry`
anchors it at the package_config's own directory, and
`zfa graphql generate` delegates through the compiled companion —
regardless of the process CWD. Hosted-style companions compile against
the consuming project's package config (`dart compile exe
--packages=<project>/.dart_tool/package_config.json`), cache the
artifact in the PROJECT's `.dart_tool/zfa_cli_bin/` under a
candidate+project slot, and invalidate on a rewritten package config —
the shared pub cache is never written. Absolute `file://` rootUris and
the legacy no-`packagesFile` compile contract are pinned unchanged.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| RED §1 | `dart test test/plugins/plugin_gate/plugin_gate_test.dart` (tests alone) | RED ×2, right reason | relative rootUri → `companionEntry` null; absolute + missing-bin guards green pre-fix |
| RED §2 | `dart test test/cli/zfa_executable_test.dart --plain-name "U12"` | RED ×4, right reason | no `--packages`, artifact inside candidate root, shared slot, no invalidation; U12e legacy green pre-fix |
| GREEN | `dart test test/plugins/plugin_gate/plugin_gate_test.dart test/cli/zfa_executable_test.dart` | pass ×35 | all U7 + U12 pins green |
| E2E | `dart test test/graphql/graphql_generate_delegation_e2e_test.dart` | pass | real `pub get` (relative rootUri asserted) → delegation → `✅ Generated`; project cache written; companion root untouched |
| Analyzer | `dart analyze` over the 6 touched files | pass | `No issues found!` |
| Mutation | M1–M4 (see tdd/verification.md) | 4/4 killed | each mutant applied, pin run, tree restored |
| Regression | `dart test test/cli/` + gate/spawn-sweep/graphql/commands suites | pass ×281 + ×168 + ×15 | no new failures; no-JIT spawn sweep green |
| Format | `dart format .` | pass | 2943 files, 0 changed |

## Out of scope (per the issue's sequencing)

§3 capability scaffold and §4 companion repo splits remain separate
follow-up workstreams.
