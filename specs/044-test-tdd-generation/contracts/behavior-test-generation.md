# Contract: Behavior test generation

## Purpose

This contract defines the additive test-plugin operation used by `zfa tdd gen` to materialize one planned behavior as an honest-red test and a paired compilable subject. It does not change the existing `zfa test <Name>` interface.

## CLI contract

```text
zfa tdd gen <behavior-id> [--feature <feature>] [--dry-run] [--replace-owned]
```

| Input | Required | Rules |
|---|---:|---|
| `<behavior-id>` | Yes | Must identify one behavior in the resolved feature contract. |
| `--feature <feature>` | No | Single feature-directory name. If absent, the command uses `.specify/feature.json`; it fails if no active feature is resolved. |
| `--dry-run` | No | Validates and reports the complete artifact plan without writes. |
| `--replace-owned` | No | May replace artifacts only when their manifest identifies the same behavior and their current hashes still match managed content. |

The command resolves `specs/<feature>/tdd/behavior-contracts.json`. The requested record must have `status: "ready"`. `needsDefinition`, unknown, ambiguous, malformed, or path-escaping records are errors before any artifact write.

## Capability contract

`TestPlugin` exposes a separate `create_behavior` capability. Its typed request consists of:

```text
BehaviorGenerationRequest
├── ready BehaviorContract
│   ├── feature, behaviorId, kind, description, sourceCriterion
│   ├── subject signature and deterministic subject path
│   └── typed invocation, matcher, expected value, and red-stub value
├── resolved test profile
├── dryRun
└── replaceOwnedArtifacts
```

It returns:

```text
BehaviorGenerationResult
├── feature
├── behaviorId
├── sourceCriterion
├── testName
├── manifestPath
└── artifacts[]
    ├── role: test | subject | manifest
    ├── path
    └── ownership: created | reused
```

A capability result is successful only after all artifacts are atomically committed (or, for a dry run, completely validated). A collision is a failed result, not a successful skipped file.

## Generated artifact contract

| Artifact | Stable location | Required properties |
|---|---|---|
| Test | `test/tdd/<feature>/<kind>/<behavior-id>_behavior_test.dart` | Imports the paired subject, has exactly one named behavior test, includes behavior ID and criterion traceability, and asserts the declared observable outcome. |
| Subject | `lib/src/tdd/<feature>/<kind>/<behavior-id>_behavior_subject.dart` | Compiles independently, exposes exactly the contract-declared target, and initially returns the compatible red-stub value. |
| Manifest | `.zfa/manifests/tdd-behavior/<feature>/<behavior-id>.json` | Records request fingerprint, artifact paths, test name, hashes, ownership, and traceability. |

The behavior ID is the identity. A readable description suffix may be added to generated names, but it cannot determine uniqueness.

## Honest-red rule

After a successful real generation:

1. The configured standalone test command must load the test and subject successfully.
2. The one behavior test must execute.
3. The result must be a failed assertion of the declared expected outcome.
4. A skipped/pending test, missing import/symbol, parse/load error, unconditional failure, or already-green result is not an honest-red result.

The test generation operation produces the code necessary for this condition; `zfa tdd verify-red` is responsible for running and classifying the evidence in the next lifecycle phase.

## Ownership and retry rules

| State | Result |
|---|---|
| No matching manifest or generated paths | Create all artifacts atomically. |
| Matching contract fingerprint and content hashes | Reuse all artifacts with no byte changes. |
| Changed contract but verified matching owned artifacts | Require `--replace-owned`; then replace all three atomically. |
| Existing unowned/different content, or changed managed hashes | Fail with path and reason; never overwrite. |
| Partial manifest/artifact state | Fail with each missing/conflicting path; never repair implicitly. |

## Compatibility rules

- `CreateTestCapability`, `TestCommand`, and the existing architecture-derived test builders retain their current input schema, file paths, and generated output behavior.
- Behavior generation respects the resolved Dart-vs-Flutter test profile when selecting imports and runner-compatible test structure.
- Behavior test generation is additive; it must not require an entity, use case, repository, mock data source, or any other pre-existing generated production artifact.
