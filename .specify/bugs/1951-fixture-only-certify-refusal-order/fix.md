# Bug Fix — #1951 (the refusal now fires only when there is something to refuse)

## Root cause

`MockCertificationService.certify` resolved `requireInterfaceFile` /
`requireMockFile` up front and threw the #1894 `StateError` when the derived
datasource seam was absent — which it always is for an enum (#1037 skips the
CRUD surface by design). `fixtureOnly` was computed only at return time, so
the #1887 short-circuit could never reach the refusal.

## Changes

- `lib/src/plugins/mock/services/mock_certification.dart`
  - the fixture-only classification (enum / CRUD-less, the shared
    #1887/#1747 predicate) is computed BEFORE the refusals, probed through
    `_absolute(root, outputDir)` — the same root the file checks use, so a
    project-relative `outputDir` with a non-cwd `projectRoot` probes the
    target tree;
  - `requireInterfaceFile = requireInterface && !fixtureOnly` and
    `requireMockFile = requireMock && (requireArtifacts ?? true) &&
    !fixtureOnly` — a fixture-only entity has no interface or mock to
    refuse;
  - the returned `MockCertification` carries the precomputed `fixtureOnly`
    (no recomputation that could drift from the decision the refusals
    acted on).
- `lib/src/commands/mock_verify_command.dart`
  - a fixture-only entity skips the missing-artifact refusals and reports
    the fixture-only green (exit 0; `--json` emits a canonical pass
    envelope with `fixtureOnly: true` in `details`), refusing honestly when
    the mock data file itself is missing;
  - real entities are untouched — the missing-file refusals keep firing.
- `test/plugins/mock/bug_1951_fixture_only_certify_refusal_order_test.dart`
  - pins the whole contract: fixture-only certification, the #1894 refusal
    intact for a real CRUD entity, plain + `--certify` enum create exits 0,
    verify green (human + `--json`), verify still refuses for a real entity
    with no artifacts.

## Evidence

- red (pre-fix): `dart test test/plugins/mock/bug_1951_fixture_only_certify_refusal_order_test.dart -j 2`
  — 5 failed; the create repro printed the issue's output verbatim:
  `zfa mock create: cannot certify SubscriptionTier — the declared interface
  lib/src/data/datasources/subscription_tier/subscription_tier_datasource.dart does not exist.`
- green (post-fix): same command — `00:03 +7: All tests passed!`
- regression: `dart test test/plugins/mock -j 2` — `+275: All tests passed!`;
  the #1503/#realize consumers:
  `dart test test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart test/plugins/tdd/commands/realize_mock_command_test.dart test/commands/mock_command_help_test.dart -j 2`
  — `+18: All tests passed!`
- `dart analyze lib test --no-fatal-warnings` — exit 0 (pre-existing infos
  only, in files this change does not touch).
