# Chore Assessment: Migrate all ZikZak pub.dev packages to be built on zuraffa (EPIC #214)

- **Slug**: migrate-zikzak-pubdev-packages
- **Created**: 2026-10-18
- **Source**: GitHub issue https://github.com/arrrrny/zuraffa/issues/214
- **Verdict**: in scope
- **Size**: large

## Summary

EPIC tracking the complete rewrite of every ZikZak package published on pub.dev
(https://pub.dev/publishers/zuzu.dev/packages) onto Zuraffa v6. The EPIC also
covers (a) forking orphaned/unmaintained dependencies into the Zuraffa ecosystem,
(b) launching a private PRO-only Unpub repository at zikzak.zuzu.dev, and
(c) a macOS/iOS/Android showcase ecommerce app ("mag Magento-like app builder").

The per-package migration specs already exist in this repo (specs/053..065 and
032-migrate-pubdev-packages). This chore's deliverable is the consolidated
migration plan that sequences those packages, resolves inter-package
dependencies, and defines the parity gates. The detailed playbook already lives
in `docs/package_migration_guide.md`; this plan applies it to the ZikZak family.

## Affected Paths

- `specs/032-migrate-pubdev-packages/spec.md` — EPIC spec (already present, Draft)
- `specs/032-migrate-pubdev-packages/plan.md` — consolidated migration plan (this chore's deliverable)
- `docs/package_migration_guide.md` — playbook (reference, not modified)
- `docs/writing_zuraffa_packages.md` — greenfield reference

## Proposed Approach

1. Inventory the ZikZak package family (already-migrated `zuraffa_*` vs.
   legacy `zikzak_*` / third-party dependencies).
2. Classify each legacy package: migrate (rewrite on Zuraffa v6), fork (take
   over an orphaned dependency), or deprecate.
3. Define a dependency-ordered execution sequence (foundational packages first).
4. Define parity gates (API, behavior, layer discipline, DI completeness,
   publish) per `docs/package_migration_guide.md` §7.
5. Track progress against the per-package specs (053-065).

## Verification

- `dart analyze` clean (docs-only change).
- `dart test -j 2` green.
EOF