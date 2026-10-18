# Chore Assessment: Migrate html_to_markdown_ffi to be built on zuraffa

- **Slug**: html-markdown-ffi-migration
- **Created**: 2026-10-18
- **Source**: https://github.com/arrrrny/zuraffa/issues/687
- **Verdict**: in scope (large, multi-repo)
- **Size**: large

## Report (verbatim or summarized)

Issue #687 — "[v6] Migrate html_to_markdown_ffi to be built on zuraffa", a sub-issue of EPIC #214 ([v6] Migrate all ZikZak pub.dev packages to be built on zuraffa). Package: `html_to_markdown_ffi` (pub.dev). Goal: migrate the package's codebase to a complete rewrite on zuraffa per the EPIC #214 migration plan. Notes: platform implementations (android/windows/linux/macos) are covered by the umbrella `zikzak_inappwebview` package — do NOT create separate platform sub-issues. Labels: enhancement, v6, zuraffa_core, chore.

## Summary

This is a brownfield migration of the federated `html_to_markdown_ffi` plugin (app-facing + platform + platform-adapter packages) onto the zuraffa v6 architecture. It is tracked in the zuraffa repo via spec `specs/064-migrate-html-to-markdown-ffi/` (Draft) and follows `docs/package_migration_guide.md`. The actual source rewrite lives in the `html_to_markdown_ffi` repository; in zuraffa the deliverable is the spec/assessment and any zuraffa-side capability gaps it surfaces.

## Constitution Check

- `.specify/constitution.md` (if present) governs; migration must preserve the public API surface (FR-006 of spec 064) or document breaking changes. No new runtime dependencies should be added to zuraffa core for this package.
- Layer discipline: domain must not import `dart:ffi`/`dart:io`/channel code; the FFI bridge stays behind a port in the data layer.
- FFI is not a platform channel: the core stays a pure Dart package, not a federated monorepo, unless channel wrappers are required (per guide §1). Platform adapters are sourced from `zikzak_inappwebview`.

## Affected Paths

- `specs/064-migrate-html-to-markdown-ffi/spec.md` — migration spec (Draft); needs tasks.md + tdd artifacts to match siblings like spec 058.
- `docs/package_migration_guide.md` — canonical brownfield playbook (shape decision, mapping table, parity gates).
- External repo `arrrrny/html_to_markdown_ffi` — actual rewrite target (federated: app-facing + platform + adapters).
- `lib/src/commands/package_command.dart` / `zfa package create-plugin` — scaffold entrypoint used for federated shape.

## Proposed Approach

**Preferred**: Follow the brownfield playbook end to end in the package repo:
1. Phase 0 inventory (public API, behavior, native, dependency, consumer census) -> `migration-contract.md`.
2. Phase 1 scaffold via `zfa package create-plugin html_to_markdown_ffi --platforms ios,android,macos,linux,windows` (or in-place rewrite if keeping the same repo).
3. Phase 2 map old API to zuraffa shapes (Port + Service + UseCases; entities; AppFailure).
4. Phase 3 port tests first; wire `zfa tdd` engine for new behavior; keep test count >= baseline.
5. Phase 4 compatibility facade preserving public API.
6. Phase 5 parity gates (API, behavior, layer discipline, DI, statics, lifecycle, publish, journal).
7. Phase 6 publish as minor.

In zuraffa, advance spec 064 to match the artifact set of comparable migration specs (tasks.md, tdd/cycle-log.md) so the migration is trackable and auditable.

**Alternatives**:
- Treat as a "nothing to ship" tracking issue if the spec is considered the deliverable (rejected: issue is open and migration not executed).

**Paths likely to change**:
- `specs/064-migrate-html-to-markdown-ffi/tasks.md` (new)
- `specs/064-migrate-html-to-markdown-ffi/tdd/cycle-log.md` (new)
- External package repo (full rewrite)

**Verification to run**:
- In package repo: `dart pub get`, `dart analyze`, `dart test` (all green); `dart pub publish --dry-run` clean.
- In zuraffa: `dart test -j 2` remains green (no source changes here).

## Risks & Considerations

- Large blast radius: federated plugin with native libs; platform adapters must not be duplicated (FR-007, issue notes).
- Native bindings must be preserved verbatim (FR-003); FFI bridge wrapped by datasource, not replaced.
- Public API parity (FR-006) constrains the rewrite; facade layer required.
- Publishing/versioning: minor bump for facade-complete, major only when facades removed.
- Tracking-only change in zuraffa must not perturb the test suite or analysis.

## Open Questions

- [NEEDS CLARIFICATION: whether the rewrite lands in the existing `html_to_markdown_ffi` repo or a fresh zuraffa-namespaced repo per EPIC #214 rollout order]
- [NEEDS CLARIFICATION: whether `zikzak_inappwebview` already exposes the platform FFI for all five platforms as assumed (spec 064 Assumptions)]
path">
/Users/arrrrny/Developer/zuraffa/.specify/chores/html-markdown-ffi-migration/assessment.md