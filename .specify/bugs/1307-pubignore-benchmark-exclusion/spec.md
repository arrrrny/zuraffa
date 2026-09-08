# Bug Spec: 1307-pubignore-benchmark-exclusion

Synthesized from `assessment.md` for the TDD loop (`bug.fix` TDD mode).
The required (fixed) behavior is the acceptance criteria; the assessment's
reproduction is the failing-test scenario.

## Problem

`.pubignore` contains unanchored directory patterns. Pub applies gitignore
semantics: a pattern with a trailing slash and no leading/middle slash
(`benchmark/`) matches directories at ANY depth. This excludes
`lib/src/core/benchmark/` (exported by `lib/zuraffa.dart:294-301`) and
`lib/src/plugins/benchmark/` from the published tarball, so published
6.2.0/6.2.1 fail consumer compilation at day zero.

## Acceptance Criteria (required fixed behavior)

- **AC-1** — Every `export`/`part` directive target in every `.dart` file
  under `lib/` that would be published resolves to a file present in the
  would-publish set (the file set pub uploads after applying `.pubignore`).
  This is the publish-time export guard.
- **AC-2** — The guard pins gitignore semantics as a regression wall:
  the top-level `benchmark/` harness stays EXCLUDED from the publish set,
  while `lib/src/core/benchmark/benchmark_contract.dart` (and its 7 sibling
  exported files) are INCLUDED.
- **AC-3** — The guard itself rejects any future unanchored directory
  pattern (trailing-slash-only pattern) in `.pubignore`, so the any-depth
  hazard class cannot silently return.
- **AC-4** — The fix touches ONLY `.pubignore` (anchor the 8 dev-only
  directory patterns) plus the new guard test. No changes to
  `lib/zuraffa.dart` exports, no publish-process changes.

## Failing-Test Scenario (from assessment reproduction)

With the current (unanchored) `.pubignore`, computing the would-publish set
and checking exported targets must FAIL: `src/core/benchmark/*.dart` targets
of `lib/zuraffa.dart` exports are absent from the set. After anchoring, the
same check must PASS.

## Out of Scope

- Republishing 6.2.2 (maintainer action post-merge).
- Any change to `lib/zuraffa.dart`, the publish process, or other files.
