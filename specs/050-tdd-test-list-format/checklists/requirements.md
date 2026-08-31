# Specification Quality Checklist: TDD plan↔gen test-list format contract

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-31
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- The spec names `TestListReader` and `zfa tdd plan`/`zfa tdd gen`/`zfa tdd run`
  because the contract IS between those commands — these are the feature's
  user-visible surface (CLI invocations), not internal design.
- FR-006 vs FR-007 split reflects the two real 6-column dialects found in the
  repo (kind cell = `acceptance`/`unit` vs kind cell = extension test-shape).
- Verified against the seed (issue #617): no requirements beyond the seed's
  suggested fix, its repro, and its migration-risk note.
