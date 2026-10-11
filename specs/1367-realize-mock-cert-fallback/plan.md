# Plan — Spec 1367 realize-mock cert-receipt fallback

**Branch**: `1367-realize-mock-cert-fallback` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`_EntityResolution` gains `fixturesDir` + `contractTestOverride`
fallbacks. `_resolveEntity` ends with `_mockCertResolution(cwd, entity)`:
read `test/mock/<snake>/mock-cert.<Entity>.json` by contract (no mock
plugin import), synthesize one realize-diff.v1 case per satisfied method
under `.zfa/realize-mock/<snake>/fixtures/`, and return the resolution
(feature `mock-cert-<snake>`). The command's contract-test discovery and
fixtures-dir selection honor the overrides; every downstream stage
(Tier-1 gate, differential, receipt) is unchanged.

## Test strategy

`test/plugins/tdd/commands/bug_1367_realize_mock_cert_fallback_test.dart`
drives the in-process command with the injected suite runner / tier-1
driver / tier-2 provider (the existing realize-mock test pattern): B1
full resolution + certification + synthesized cases, B2 unknown-entity
guard, B3 unsatisfied-method filtering, B4 missing-contract-test blocked.
Scoped pin: the existing realize-mock suites + analyze.
