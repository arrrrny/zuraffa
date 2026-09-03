# Bug Issue: Generator/runtime version-skew contract: generated code must compile against PUBLISHED zuraffa (repro: U8)

- **Slug**: version-skew-contract
- **Fetched**: 2026-09-03
- **Issue**: 911
- **URL**: https://github.com/arrrrny/zuraffa/issues/911
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

"Part of #908.

## Live repro

Generated persistence-harness test imports 'package:zuraffa/zuraffa.dart' PersistenceTestHarness/TestClock — classes that exist only in zuraffa master. Consumers resolving zuraffa from pub.dev get compile-error. Project had to add a path override to proceed.

## Required

1. Generator emits only APIs available in the MINIMUM published zuraffa the project's constraint allows; or emits a version-guarded alternative.
2. Lockstep publishing contract: harness/simulation APIs land in a zuraffa release BEFORE (or with) the generator that emits them; CI matrix pins generator-version × published-runtime-version.
3. 'zfa doctor' check: scan generated test imports against the resolved zuraffa's exported API surface; drift = named verdict with fix."

## Comments

None.
