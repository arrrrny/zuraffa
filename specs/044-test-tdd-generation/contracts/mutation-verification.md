# Contract: Feature-scoped mutation verification

## Purpose

This contract defines how `zfa tdd verify --feature <feature>` converts registered behavior artifacts into a trustworthy mutation assessment. It replaces the use of a static repository-wide mutation scope for behavior verification; the existing root `mutation-test.xml` remains a framework-specific fixture and is not the behavior-audit input.

## CLI contract

```text
zfa tdd verify --feature <feature>
```

`<feature>` must be a single existing feature-directory name. The command rejects traversal-like values before any external process is started.

### Required execution sequence

1. Recover and verify any incomplete earlier mutation journal for the feature.
2. Load and validate the TDD profile and all feature behavior artifact manifests.
3. Build and print the resolved behavior IDs, criteria, test paths, and subject paths.
4. Reject an empty, missing, tampered, incomplete, or out-of-project scope as `notAssessed`.
5. Run the resolved feature preflight test command. If it is not green, stop before mutation analysis and report `notAssessed(preflightFailed)`.
6. Snapshot selected subject bytes and hashes in a run journal.
7. Render an ephemeral mutation configuration limited to the selected subjects and tests.
8. Run the configured mutation adapter within per-mutant and whole-audit time bounds.
9. Parse, reconcile, and classify the complete report.
10. Restore and verify all source snapshots in the cleanup path.
11. Write an append-only feature verification entry and return the quality-gate exit status.

## TDD profile extension

The existing five machine-readable fields remain required: `runner`, `single`, `file`, `suite`, and `coverage`.

The profile adds this structured mapping inside its machine-readable block:

```yaml
mutation:
  adapter: mutation_test_v1
  executable: dart
  arguments: [run, mutation_test, "{config}", -f, md, -o, "{output}"]
  report_format: md
  per_mutant_timeout_seconds: 30
  audit_timeout_seconds: 900
```

| Field | Validation |
|---|---|
| `adapter` | Must identify a supported report parser. |
| `executable` and `arguments` | Must be tokenized values; `{config}` and `{output}` are the only mutation substitutions. |
| `report_format` | Must be supported by the selected adapter. |
| Timeouts | Positive, bounded integer seconds. |

The profile reader rejects malformed or unavailable configuration. Verification must not substitute a hard-coded runner or mutation command.

## Scope contract

The mutation audit scope is the deduplicated union of complete owned manifests for the requested feature:

```text
BehaviorArtifactManifest[]
  -> subject paths under lib/
  -> test paths under test/
  -> behavior ID + source criterion traceability
  -> MutationAuditPlan
```

All paths are project-relative, canonicalized, and validated to remain beneath the project root. Subject paths must remain under `lib/`; test paths must remain under `test/`.

The rendered configuration and preflight invoke only this registered scope. Every configuration command is token-safe: generated behavior identifiers and paths use the restricted deterministic naming format, and profile commands that cannot be safely represented are rejected.

## Assessment and gate contract

| Condition | Status | Score | Exit |
|---|---|---:|---:|
| Complete evaluation, green preflight, zero survived/timed-out/not-covered, and verified restoration | `passed` | `killed / evaluated` | 0 |
| Complete evaluation with any survived, timed-out, or not-covered mutation | `failed` | `killed / evaluated` | non-zero |
| Empty scope, red preflight, unavailable tool, invalid profile/config, no mutations, incomplete/timeout/interrupted execution, missing/unparseable/conflicting report, or cleanup failure | `notAssessed` with a precise reason | none | non-zero |

`evaluated = killed + survived + timedOut`. The report always shows killed, survived, timed-out, and not-covered counts separately. It displays a score only for a complete assessment where `evaluated > 0`.

The adapter must not use a mutation tool's threshold/exit policy as the final gate. The contract's strict policy controls the command exit status.

## Report contract

Each append-only entry in `specs/<feature>/tdd/verification.md` includes:

- run identifier and timestamps;
- assessment status, reason when not assessed, and final gate decision;
- each behavior ID, source criterion, subject path, and test path in scope;
- resolved preflight and mutation commands (with sensitive values redacted), exit code, and elapsed time;
- adapter/version and rendered configuration reference;
- candidate/evaluated/killed/survived/timed-out/not-covered counts and score denominator;
- report/diagnostic references;
- source snapshot and restoration verification result.

When the result cannot be trusted, diagnostics explain why but it is never represented as a zero-count or 100% passing audit.

## Source-integrity contract

Before external mutation begins, the verifier records raw-byte snapshots and hashes for every selected subject in `.zfa/runs/tdd/<run-id>/`. Cleanup restores all subjects through a verifier-controlled `finally` path and compares post-cleanup hashes to their snapshots.

An incomplete run is marked `recoveryRequired`. The next verification invocation restores and verifies its journal before executing another audit. Version-control reset and edits to generated/user-authored test files are prohibited cleanup mechanisms.
