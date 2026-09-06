# Bug Issue: [MOCK-FIRST] template self-hosting — every template born through the TDD loop

- **Slug**: 1198-template-self-hosting
- **Issue**: 1198
- **URL**: https://github.com/arrrrny/zuraffa/issues/1198
- **Part of**: #908 (P0) — "Template self-hosting (templates born TDD) — template correctness debt"
- **Severity**: critical
- **Fetched**: 2026-09-06

## Body (task brief, verbatim requirements)

Every generator template (usecase, service, repository, datasource, mock, di,
view/skin, state, route) gets a template-level test suite that drives the
template through the TDD loop against a fixture entity — the same trust-tier
bar as #1117 (structural + compile + behavioral), plus:

- a diff guard: regenerated output for the same inputs is byte-stable
  (determinism receipt);
- a downstream-compile gate: emitted code compiles in a minimal Flutter
  package (catches import/dep drift like #1189/#1190 at template level, not
  app level);
- templates that fail the loop BLOCK publish (the loop is the template's
  referee).

Why P0: Stage-3/#1116-class template regressions were caught by app-level
failures this cycle; self-hosting moves the referee in front of the consumer.

## Hard constraints

- every template must have a TDD-loop test
- diff guard + downstream-compile gate
- one PR for this bug
