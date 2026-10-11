# Test Report: Four `startsWith('## ')` line-scanners outside the cycle-log stay fence-blind

- **Slug**: 1575-remaining-fence-blind-line-scanners
- **Date**: 2026-09-13
- **Branch**: `fix/1575-remaining-fence-blind-line-scanners`
- **Assessment**: `assessment.md` · **Fix**: `fix.md` · **TDD verify**: `tdd/verification.md`

## Verdict: FIXED (red → green, full-suite sweep clean)

## Reproduction → Resolution

The assessment's reproduction (a fenced example carrying `## Key entities`
or a loop marker inside a behavior section, then a real row) failed
pre-fix exactly as predicted:

| Fixture (new suite) | Pre-fix (RED) | Post-fix (GREEN) |
| --- | --- | --- |
| in-fence `## Inner loop:` re-kinds the section | A2 parsed as **unit** (mis-kind) | A2 stays **acceptance** |
| in-fence `## Key entities` swallows rows | U2 **missing** from rows | U2 parses (unit) |
| `readEntities` in-fence header | `Widget` entity **dropped** | `['Role', 'Widget']` |
| `readDependencies` in-fence header | `Clock` dependency **dropped** | `['AuthApi', 'Clock']` |
| `readLayerContracts` in-fence header | `IStore` contract **dropped** | `['IRepo', 'IStore']` |
| `_behaviorIdsOf` in-fence header | `B2` **vanished** from the audit | gap reported for B1 **and** B2 |
| `_behaviorIdsOf` fenced `## Behaviors` example | phantom **`PHANTOM`** id fabricated | no phantom ids |

## Validation runs (REAL, this session — Dart 3.13.3, linux_x64)

1. Bug suites (both new files): `00:00 +11: All tests passed!`
2. Pre-existing reader/proof suites (7 files, incl. the bug #984
   line-contract pins and the #1148 proof-chain contract):
   `00:03 +76: All tests passed!`
3. Full-suite chunked sweep — all 1,294 test files, 26 chunks:
   every chunk `All tests passed!` except four Flutter-toolchain
   compile-pin suites whose `setUpAll` runs `flutter pub get` on a host
   with no Flutter SDK (`ProcessException`), each reproduced identically
   on a pristine pre-fix worktree (d5a40731) — pre-existing host gap,
   not a regression. ≈6,507 tests passed, 4 failed (the four
   `setUpAll` entries), zero assertion-level failures.
4. `dart analyze`: changed files clean; full project 112 issues ==
   pristine pre-fix baseline 112 (0 errors / 0 warnings both).
5. `dart format`: the four changed Dart files are format-clean.

## Constraints check

- Only `test_list_reader.dart` + `proof_chain_checker.dart` changed in
  `lib/`; the cycle-log readers and the splitter untouched.
- Well-formed test-list/spec parsing unchanged (no-fence controls, the
  committed 004 corpus fixture control, and the 76 pre-existing tests).
- Line-naming error contract (bug #984) byte-identical (U-1575-b3).
- `dart analyze` with no new warnings — full-project parity proves it.

## Artifacts

- `red-evidence.md` — the pre-fix failure record
- `assessment.md` / `issue.md` — triage and upstream issue transcription
- `fix.md` — the change record
- `tdd/test-list.md` — the 11-row acceptance list (all GREEN)
- `tdd/verification.md` — the full tdd.verify record
