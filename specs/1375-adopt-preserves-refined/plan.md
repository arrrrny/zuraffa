# Plan — Spec 1375 adopt preserves refined

**Branch**: `1375-adopt-preserves-refined` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

Test-only: drive `zfa tdd gen A1 --adopt` / plain `gen` over a TddFixture
registry record whose test file is hand-refined (provenance header +
behavior id preserved, authored assertion set) and pin the preservation.

## Test strategy

`test/plugins/tdd/commands/bug_1375_adopt_preserves_refined_test.dart`
(B1–B3). Scoped pin: the tdd command suites + analyze.
