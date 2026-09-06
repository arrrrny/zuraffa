# BUG 1197 — [MOCK-FIRST] generator/runtime version-skew contract

GitHub issue #1197, part of #908 (P0), severity critical.
Branch: `fix/1197-version-skew-contract`

## Observed (live, this cycle)

1. The skin barrel of a generated slice imports
   `package:zuraffa/skin.dart` — that barrel did not exist in published
   6.1.0 (sandbox had to override to master).
2. Core master bumped `analyzer: ^14.3.0` as a regular dep; Flutter
   consumers needed a `dependency_overrides` (#1189).
3. Generated code's `hide` clauses broke when the core barrel changed
   what it exports (#1176 → #1180 fixed the emission; the CLASS of
   breakage — generated artifacts coupled to one core version —
   remains unguarded).

## Why P0

Every zik_zak feature slice generated this cycle died once on version
skew; at 120 specs × the corpus, that is 120 manual overrides.

## Root cause (from the live repo, pre-fix)

- Tag `v6.1.0` ships NO `lib/skin.dart` (added to master by a40d8e36,
  spec 1102) — yet the master generator emits
  `import 'package:zuraffa/skin.dart';` unconditionally at three
  emission sites (skin kit, view `--skin`, app shell `--skin-audit`).
- The same audit (the #1197 two-end sweep) found TWO MORE unguarded
  post-v6.1.0 surfaces: `package:zuraffa/simulation.dart` (spec 893 —
  emitted by datasource DI registration files and the simulation
  binding) and `package:zuraffa/src/plugins/xray/xray_overlay.dart`
  (spec 036 — emitted by app shell `--xray`).
- Version strings cannot arbitrate availability: tag `v6.1.0` shipped
  `pubspec.yaml` 6.0.1 while `version.dart` said 6.0.0, and master
  still says 6.1.0 while carrying `skin.dart`.
- Receipts carried `generator_version` (sometimes hardcoded `'6.1.0'`
  literals in the TDD plugin) but no core floor and no
  generated-against version; `zfa doctor` had no skew check.

## Hard constraints

- skew contract + CI matrix + doctor skew report
- one PR for this bug
