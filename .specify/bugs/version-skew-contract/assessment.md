# Bug Assessment: Generator/runtime version-skew contract

- **Slug**: version-skew-contract
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/911
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> Part of #908. Generated persistence-harness test imports `package:zuraffa/zuraffa.dart` `PersistenceTestHarness`/`TestClock` — classes that exist only in zuraffa master. Consumers resolving zuraffa from pub.dev get a compile-error. Project had to add a path override to proceed.
>
> Required: (1) Generator emits only APIs available in the MINIMUM published zuraffa the project's constraint allows; or emits a version-guarded alternative. (2) Lockstep publishing contract: harness/simulation APIs land in a zuraffa release BEFORE (or with) the generator that emits them. (3) `zfa doctor` check: scan generated test imports against the resolved zuraffa's exported API surface; drift = named verdict with fix.

## Symptom

Generated persistence-harness tests import `package:zuraffa/zuraffa.dart` and reference `PersistenceTestHarness` and `TestClock`. These classes exist in the zuraffa source tree (`lib/src/testing/persistence_test_harness.dart`) but may not be exported from the published barrel (`lib/zuraffa.dart`) or may not exist in the version pinned by the consumer's `pubspec.yaml`. The consumer's `dart test` or `flutter test` fails with a compile error on import resolution. The workaround is a `dependency_overrides` path to the local zuraffa clone.

## Reproduction

1. Create a Flutter project with `zuraffa: ^1.0.0` (or any published version) in `pubspec.yaml`.
2. Run `zfa tdd plan <feature>` on a feature with `[persistence]` behaviors.
3. Run `zfa tdd gen <behavior-id>` for a persistence behavior.
4. The generated test file contains `import 'package:zuraffa/zuraffa.dart'` and uses `PersistenceTestHarness` / `TestClock`.
5. Run `dart test` — compile error: the imported symbols do not exist in the resolved published zuraffa version.

## Suspected Code Paths

- `lib/src/testing/persistence_test_harness.dart:1-50` — defines `PersistenceTestHarness` and `TestClock`; this is the source file in the zuraffa library
- `lib/src/plugins/tdd/services/behavior_test_writer.dart:54-55` — `_renderPersistenceTest()` renders the persistence-harness test template that imports from `package:zuraffa/zuraffa.dart`
- `lib/zuraffa.dart` — the barrel export file; must include `PersistenceTestHarness` and `TestClock` for the generated import to resolve
- `lib/src/plugins/tdd/services/behavior_test_writer.dart:48-49` — the `escapedGroupDesc` apostrophe escaping logic (also relevant to #912)

## Root Cause Hypothesis

**High confidence.** The root cause is a publishing order gap: the `PersistenceTestHarness` and `TestClock` classes were added to the zuraffa source tree (bug #833) and the generator templates were updated to use them, but either (a) the barrel export (`lib/zuraffa.dart`) does not re-export `package:zuraffa/src/testing/persistence_test_harness.dart`, or (b) the classes were added after the last pub.dev publish, so consumers on the published version see compile errors. The generated code assumes a bleeding-edge API surface that the published package does not yet expose.

## Proposed Remediation

**Preferred**:
1. **Immediate**: Ensure `PersistenceTestHarness` and `TestClock` are re-exported from `lib/zuraffa.dart` (the barrel). Verify with `dart analyze lib/zuraffa.dart` that the symbols resolve.
2. **Publish**: Create a new pub.dev release that includes the barrel export. The generator's minimum-version constraint in `pubspec.yaml` must pin to this version or later.
3. **Guard**: Add `zfa doctor` subcommand that scans `tdd/artifacts.json`-registered test files for `package:zuraffa` imports, resolves the imported symbols against the project's resolved zuraffa version, and reports any that are missing as a named verdict with `--> fix:` instructions.
4. **CI matrix**: Pin a `generator-version × published-runtime-version` matrix in CI to catch future drift before it reaches consumers.

**Alternatives**:
- **Version-guarded alternative**: The generator could emit a conditional import (`if (dart.library.io) ...`) that falls back to a local stub when the published package lacks the symbol. Trade-off: adds template complexity and is fragile across Dart SDK versions.
- **Lockstep publish**: Always publish zuraffa + zfa in a single release. Trade-off: tighter coupling, harder to hotfix one without the other.

**Files likely to change**:
- `lib/zuraffa.dart` — add export for `src/testing/persistence_test_harness.dart`
- `pubspec.yaml` — bump version
- `lib/src/plugins/tdd/services/behavior_test_writer.dart` — potential version-guard if the alternative approach is taken
- New: `lib/src/plugins/tdd/commands/doctor_command.dart` — add import-resolution drift check

**Tests to add or update**:
- Test that `lib/zuraffa.dart` exports `PersistenceTestHarness` and `TestClock`
- Test that a generated persistence test compiles against the minimum published zuraffa version
- Doctor command test: import-resolution drift check catches missing symbols

## Risks & Considerations

- **API breakage**: If `PersistenceTestHarness` was not previously part of the public API, re-exporting it makes it public contract. Future changes to its interface become breaking changes requiring semver bumps.
- **Release coordination**: The lockstep publishing contract requires careful release choreography — a breaking change in the generator requires a corresponding zuraffa publish first.
- **Existing consumers**: Any consumer who already worked around this with `dependency_overrides` will need to remove the override after the publish.

## Open Questions

- [NEEDS CLARIFICATION: Is `PersistenceTestHarness` currently re-exported from `lib/zuraffa.dart`, or is it only accessible via `package:zuraffa/src/testing/persistence_test_harness.dart`?]
- [NEEDS CLARIFICATION: What is the latest published zuraffa version on pub.dev, and does it include these classes?]
- [NEEDS CLARIFICATION: Should `zfa doctor` be a new subcommand or extend the existing `tdd doctor`?]
