# Implementation Plan: Signals Reactive Core Upgrades

**Branch**: `1725-signals-reactive-core` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/1725-signals-reactive-core/spec.md`

## Summary

Six surgical, backward-compatible upgrades to the signals reactive core
(`lib/src/core/signals/`), sourced from a code-level comparison of
medz/oref (alien_signals) against the real Zuraffa source: a lazy cached
`Computed` primitive over explicit dependencies, a synchronous `batch()`
notification-deferral boundary, identity-first default equality, a
`SignalScope` auto-ownership group, dispose-reentrancy hardening of the
notification path plus the `SignalResult.flatMap` orphan fix, and honest
dartdoc contracts for eager-delivery-on-listen and listener-error propagation.
Approach: extend the existing push-based engine; no second reactive engine,
no auto-tracking, no scheduler.

## Technical Context

**Language/Version**: Dart 3.11+ (`environment: sdk: ^3.11.0`), stable SDK 3.13 in the verification rig

**Primary Dependencies**: none new (signals core is dependency-free; zorphy ^2.4.1 stays untouched)

**Storage**: N/A

**Testing**: `dart test` (package:test), single-file runs per tdd-profile (`dart test <file> --plain-name "<name>"`); tests mirror source under `test/`

**Target Platform**: pure Dart (all platforms via Flutter consumption)

**Project Type**: library (core package of the Zuraffa framework)

**Performance Goals**: O(1) signal reads preserved; derived values perform zero compute work while unread; identity fast-path skips full `==` on same-instance writes

**Constraints**: FR-007 backward compatibility (existing public signatures and behaviors unchanged, existing suites stay green unmodified); ~1 GB sandbox cgroup during verification; private registry `pub.zuzu.dev` for `dart pub get` (token staged)

**Scale/Scope**: 2 source files touched (`signal.dart`, `signal_result.dart`), 1 new source file (`computed.dart`), 4 new test files, ~250 added source lines

## Constitution Check

The project constitution is an unfilled template placeholder; no governance
gates apply. The plan still honors the fleet's standing discipline: non-breaking
additions only, no second engine, honest contracts over convenience.

## Project Structure

### Documentation (this feature)

```text
specs/1725-signals-reactive-core/
├── plan.md              # This file
├── research.md          # oref/alien_signals comparison findings (code-level)
├── data-model.md        # Computed/SignalScope/batch state entities
├── quickstart.md        # consumer usage examples
├── contracts/           # API contracts
│   └── api-contracts.md
└── tasks.md             # dependency-ordered task list
```

### Source Code (repository root)

```text
lib/src/core/signals/
├── signal.dart          # EDIT: identity-first equality, batch state + batch(),
│                        #       SignalScope, hardened _notify, honest dartdoc
├── signal_result.dart   # EDIT: flatMap orphan fix (parent dispose cascades to out)
└── computed.dart        # NEW: lazy cached Computed<T> over explicit dependencies

lib/zuraffa.dart         # EDIT: export computed.dart

test/core/signals/       # NEW test home (mirrors source)
├── computed_test.dart
├── batch_test.dart
├── signal_scope_test.dart
└── signal_reentrancy_test.dart
```

**Structure Decision**: single-library cohesion. `batch()` state, `SignalScope`,
and the hardened notify path live in `signal.dart` because they need
library-private access (`_notify`, `_listeners`) and Dart privacy is
per-library — splitting them would force public bridges. `Computed` is a
separate file (`computed.dart`) because it consumes only the public
`ReadonlySignal` surface. Tests mirror `lib/src/core/signals/` under
`test/core/signals/`, matching the repo's test-mirrors-source convention.

## Complexity Tracking

No constitution violations to justify.
