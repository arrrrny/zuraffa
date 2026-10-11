# TDD Test List — Spec 1388

Red pre-fix: U1–U3 red — the traces migration reuses (`verdict=reused`)
the stale guard-only pair, no fingerprint machinery exists.

Red pre-review-fix (PR #1597): U7/U7b red at `26c534fc` — the
whole-file `spec.md` hash made a documentation-only edit read as a
declared-routing change (U7: no reuse), and on a progressed pair it
hard-failed with `--> fix: zfa tdd reset` (U7b). U8 is the other way
round: it pins the `forceRebuild` leg that the byte-compare cannot see,
and is green both before and after (a characterization pin, not a
red-first behavior). U9 is the copy-site round-trip the U4 claim
originally asserted without covering.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| U1 | Signature-row traces migration → verdict=regenerated, declared assertion, no guard-only marker | FR-2 / AS-1 / SC-001 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U2 | No-signature-row traces migration → verdict=regenerated despite identical bytes; next gen reused | FR-2 / AS-2 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U3 | Drift + progressed subject → refused with --> fix: zfa tdd reset <feature> | FR-3 / AS-3 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U4 | Fingerprint service: arms on created records (64-hex sha256), deterministic across identical routing inputs, distinct for different routing inputs | FR-1 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U5 | Drift fires once per change (refreshed fingerprint reuses) | FR-2 / AS-4 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U6 | Unchanged routing + legacy records keep reuse | FR-4 / FR-5 / AS-5 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U7 | Documentation-only spec edit → verdict=reused, digest and bytes unmoved, no "declared routing changed" note | FR-1 / FR-6 / AS-6 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U7b | The same prose edit on a PROGRESSED pair → exit 0, reused, never `zfa tdd reset` | FR-6 / AS-6 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U8 | Routing-surface declaration that leaves the render byte-identical → verdict=regenerated (forceRebuild), digest refreshed, reuse resumes | FR-2 / AS-7 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U9 | `gen_fingerprint` round-trip: absent key → null, `toJson` omits it, present digest survives every copier | FR-1 | test/plugins/tdd/models/artifact_record_test.dart, test/plugins/tdd/services/artifact_registry_test.dart, test/plugins/tdd/commands/bug_912_migrate_paths_package_uris_test.dart |

## Red protocol

```
dart test test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart
dart test test/plugins/tdd/models/artifact_record_test.dart \
          test/plugins/tdd/services/artifact_registry_test.dart \
          test/plugins/tdd/commands/bug_912_migrate_paths_package_uris_test.dart
```
