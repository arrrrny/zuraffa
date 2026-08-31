# Quickstart: validating `zfa corpus import`

Runnable end-to-end validation. Prerequisites: repo checkout on branch
`050-corpus-import`, Dart SDK on PATH.

## 1. Unit suite (fast)

```bash
dart test test/core/project/corpus_manifest_test.dart \
          test/cli/services/corpus_importer_test.dart \
          test/commands/corpus_command_test.dart
```

Expected: all pass, no `slow` tags.

## 2. Fixture corpus import (the SC-001 matrix)

```bash
# build a 3-feature fixture corpus
mkdir -p /tmp/fx-corpus/{001-clean,002-no-scenarios,003-speckit}/ ...
# 001: spec.md with Given/When/Then + FR
# 002: spec.md with prose only (no acceptance scenarios)
# 003: spec.md + checklists/ + tdd/test-list.md (foreign format)

cd <fresh zfa app (or temp project)>
dart run bin/zfa.dart corpus import /tmp/fx-corpus
echo "exit=$?"   # expect 0
```

Expected: 001 `imported`; 002 `not-ready (no acceptance scenarios)`;
003 `imported foreign-artifacts-ignored`; manifest at
`.zfa/manifests/corpus-manifest.json` lists all three in order with correct
`ready` marks; summary line per contracts/corpus-import.md.

## 3. Loop-readiness proof (spec SC-002)

```bash
# for every ready feature: plan must succeed with zero manual edits
# for the not-ready one: plan must refuse with its reason
dart run bin/zfa.dart tdd plan 001-clean --project .
```

Expected: plan succeeds on 001, fails on 002 with the exact reason the
manifest carried.

## 4. Idempotency + divergence (spec SC-003/SC-004)

```bash
dart run bin/zfa.dart corpus import /tmp/fx-corpus   # rerun
# expect all skipped; manifest byte-identical except imported_at
# then edit /tmp/fx-corpus/001-clean/spec.md and rerun:
#   expect divergent with both hashes, target unchanged
dart run bin/zfa.dart corpus import /tmp/fx-corpus --force
#   expect imported now
```

Expected: re-import touches nothing; divergence reports, `--force` updates;
existing `tdd/` trees untouched throughout (checksum-verified by the tests).

## 5. Dry-run safety

```bash
dart run bin/zfa.dart corpus import /tmp/fx-corpus --dry-run
```

Expected: same report as a real run, zero files written (manifest included).