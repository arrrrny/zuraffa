# Tasks: 979 — provider A+ upgrade

- [x] T1: Read spec + provider_builder.dart + provider_command.dart + provider
      plugin schema (root cause understood)
- [x] T2: RED — write failing tests under test/plugins/provider/ (stub gate,
      conformance, parity, receipt emission, append/inject round-trip)
- [x] T3: GREEN — GENERATED header + provider receipt (saveNamed) +
      ProviderVerifier + `zfa provider verify <Entity>` + make post-pass hook
- [x] T4: GREEN — dead-flag purge + init wiring + manifest --verify
      certification
- [x] T5: Verify — dart analyze, tools/run_tests_chunked.sh, dart format,
      tdd/verification.md (REAL)
- [x] T6: Commit + PR (Closes #979)
