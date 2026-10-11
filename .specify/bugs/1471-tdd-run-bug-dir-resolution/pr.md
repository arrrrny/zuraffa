# Bug Fix PR: resolve bug directories across the tdd run/doctor/verify family

- **Slug**: 1471-tdd-run-bug-dir-resolution
- **Opened**: 2026-09-10
- **PR**: 1475
- **URL**: https://github.com/arrrrny/zuraffa/pull/1475
- **Branch**: fix/1471-tdd-run-bug-dir-resolution
- **Issue**: 1471

Completes the #1182 migration so every `zfa tdd` command in the run family resolves a bug
directory through `TddFeaturePaths`, letting the bug extension's TDD loop run past
`tdd.plan`. Verified end-to-end with the real CLI: `zfa tdd run <slug>` now drives the loop
(`A1 gen -> ok`, then `A1 verify-red`) and writes all artifacts under
`.specify/bugs/<slug>/tdd/` with nothing fabricated under `specs/`.
