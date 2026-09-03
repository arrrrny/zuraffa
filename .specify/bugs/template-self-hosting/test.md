# Bug Test: template-self-hosting (issue #912)

- **Slug**: template-self-hosting
- **Verdict**: verified

## Evidence

1. **Acceptance Test**: `dart test test/plugins/tdd/bug_912_template_self_hosting_test.dart`
   - A1: `BehaviorTestWriter` escapes apostrophes in persistence test descriptions — PASSED
   - A2: `migrate-paths` rewrites package-URI imports in moved tests — PASSED

2. **Analyzer**: `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
   - 0 issues found.
