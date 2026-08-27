# Implementation Plan: make --test regenerates tests for id-less entities

**Branch**: `016-fix-make-test-no-id` | **Date**: 2026-08-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/016-fix-make-test-no-id/spec.md`

## Summary

`zfa make`'s entity-resolution step throws the #307 `MakeCommandException` ("the entity has no id field") before plugin dispatch, so it fires even when the only active plugin is `test`, which merely regenerates test files from already-generated usecases and needs no identity. Primary requirement: gate the loud failure on the presence of an id-DEPENDENT plugin (repository, usecase, controller, presenter, datasource, and other plugins whose generated signatures embed an id), declared as one named `static const Set<String>`. On the id-neutral path, resolve a representative REAL field of the entity (never enum-typed, never a synthetic id) into `query-field` so the regenerated get/update/toggle tests reference an existing Field constant. Everything else — the #307 message and its three remediation hints, value-object handling, id-bearing entities — must behave byte-for-byte as before.

## Technical Context

**Language/Version**: Dart 3.11+ (repo SDK constraint `^3.11.0`; verified locally with Dart 3.13.2 stable)

**Primary Dependencies**: `args` (CLI parsing), `code_builder` + `dart_style` (code emission — not touched by this change), `package:test` (test runner), `analyzer` (repo lint gate)

**Storage**: N/A (pure CLI code generation; the only state is the emitted Dart source on disk)

**Testing**: `dart test` (fast unit suite by default; `--preset=regression` for the slow tier — see `test/README.md` and AGENTS.md "Validation guidance"). `dart analyze` on touched files.

**Target Platform**: Any OS with a Dart 3.11+ VM; CLI only, no Flutter SDK in the CLI path.

**Project Type**: library + CLI code generator (`zuraffa` package, `zfa` executable)

**Performance Goals**: Negligible — the fix adds one set-intersection check per `zfa make` run and (only on the id-less id-neutral path) one entity-source re-read that already happens for every id-bearing entity.

**Constraints**: Minimal, tightly scoped diff — the maintainer has uncommitted work in `lib/src/plugins/test/builders/*`; that directory MUST NOT be touched. No hand-editing of generated code. #307 diagnostic text is contract.

**Scale/Scope**: 2 production files (`make_command.dart`, `entity_field_resolver.dart`), 1–2 test files, spec artifacts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is an unfilled scaffold in this checkout; the de-facto constitution is `AGENTS.md`:

| Gate (AGENTS.md) | Status |
|---|---|
| Do not use the removed legacy one-shot generator | N/A — no generation-flow change |
| Prefer `zfa make` over `zfa feature` | N/A |
| Do not hand-create entities; no hand-written code to route around zfa misfires | PASS — fix is in the GENERATOR (`make_command.dart`), exactly per the issue |
| Do not call build_runner directly in normal agent flows | PASS — demo fixture uses `zfa build` |
| Spec Kit branch naming: branch == feature directory | PASS — `016-fix-make-test-no-id` both |
| Validation: focused `dart test` on touched suites + `dart analyze` | PASS — planned in tasks |
| STOP-ON-ROADBLOCK | PASS — reproduction confirmed the defect; no workarounds |

No violations → no Complexity Tracking entries needed.

## Project Structure

### Documentation (this feature)

```text
specs/016-fix-make-test-no-id/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── make-command-id-gating.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/src/
├── commands/
│   └── make_command.dart          # THE fix: named id-dependent set + gated throw +
│                                  # representative query-field resolution on the
│                                  # id-neutral path
└── utils/
    └── entity_field_resolver.dart # new resolveRepresentativeField() (source parse;
                                   # no builders touched)

test/
├── commands/
│   └── make_command_test.dart     # regression tests (runCapturing pattern), next to
│                                  # the existing "#307 identity contract" group
└── utils/  (existing resolver tests extended if present)

# Verification-only (NOT committed; lives outside the repo):
../zikzak_demo/                    # local stand-in for apps/zikzak_demo
```

**Structure Decision**: Single-project layout, mirroring the existing repository exactly. The verification demo (`zikzak_demo`) deliberately stays OUTSIDE the zuraffa repo — it is a scratch fixture reproducing `apps/zikzak_demo`'s state (id-less entities + pre-existing get/update/toggle usecases), not a deliverable.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

None — no constitution violations.
