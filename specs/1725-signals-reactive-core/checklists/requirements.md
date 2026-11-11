# Requirements Checklist: Signals Reactive Core Upgrades

**Purpose**: Requirements-quality review of specs/1725-signals-reactive-core/spec.md
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md)

**Review Ownership**: This checklist is a reviewer-owned requirements-quality review artifact. Mark an item `[x]` only when the reviewer determines the requirements-quality criterion is satisfied.
**Marker Semantics**: `[x]` means the criterion has been reviewed and satisfied for requirements quality. It does not mean implementation work is complete.

## Problem & Context

- [x] CHK001 The problem is stated from the user's perspective with a clear need (derived-state waste, notification storms, leaks, undocumented hazards)
- [x] CHK002 The feature's value is tied to observable outcomes, not implementation details alone
- [x] CHK002b Current-state analysis is grounded in the actual codebase (signal.dart, signal_result.dart), not docs

## User Scenarios

- [x] CHK003 Every user story follows the "As a [role], I can/want [capability], so that [benefit]" pattern
- [x] CHK004 Every story has a priority with justification
- [x] CHK005 Every story has an independent test description
- [x] CHK006 Every story has acceptance scenarios in Given/When/Then form with Type markers
- [x] CHK007 Edge cases are enumerated (disposed dependency before read, async escaping batch, read-in-own-compute recursion, double-subscribe)

## Requirements Quality

- [x] CHK008 Each requirement is a single, unambiguous capability with RFC-2119 keywords (MUST/MUST NOT)
- [x] CHK009 Each functional requirement is atomic (one verifiable capability per FR)
- [x] CHK010 Each FR is testable as written (no vague qualifiers like "fast", "clean", "user-friendly")
- [x] CHK011 Each FR traces to at least one declared layer contract (Computed, batch, SignalScope, Signal)
- [x] CHK012 Backward compatibility is an explicit requirement (FR-007) with a measurable criterion (SC-005)
- [x] CHK013 No [NEEDS CLARIFICATION] markers remain in the spec

## Success Criteria & Signal Coverage

- [x] CHK014 Success criteria are measurable (zero compute calls, exactly-one notification, zero notifications on identity, 100% scope disposal, unmodified green suite)
- [x] CHK015 Each user story maps to at least one success criterion or scenario that validates it

## Scope & Constraints

- [x] CHK016 The "no second engine" constraint is stated (explicit dependency lists, no auto-tracking, no scheduler)
- [x] CHK017 Out-of-scope behavior is explicit (no async transactions, no rollback, eager delivery kept-and-documented rather than changed)
- [x] CHK018 Assumptions are recorded and falsifiable

## Notes

- Spec authored 2026-11-11 on branch `1725-signals-reactive-core` (before_specify hook executed: branch created, FEATURE_NUM 1725).
- Lanes section intentionally omitted: pure-Dart CORE feature with no skin surface; the legacy single-file test list applies.
- The openwiki-era docs referenced in prior turns are irrelevant here per the user's directive: contracts were taken from the real signal source, not .md files.
