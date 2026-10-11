# Plan 1312 — receipt preflight absolute-vs-relative path mismatch

## Technical Context

- Toolchain: Dart 3.13.3 stable (SDK constraint `^3.11.0` respected);
  pure-Dart package — no Flutter SDK in the loop (Constitution VII).
- Target file (the ONLY lib/ file allowed to change):
  `lib/src/plugins/tdd/services/receipt_preflight.dart` — class
  `ReceiptPreflight`, members `check()` and `_normalize()`.
- The two stores and their path shapes:
  - `specs/<f>/tdd/artifacts.json` — written by
    `lib/src/plugins/tdd/commands/gen_command.dart` line ~885:
    `final subjectPath = '$cwd/lib/tdd/$featureName/${snakeId}_subject.dart';`
    → `subject_path` is ABSOLUTE (string concat with cwd). Parsed by
    `ArtifactRecord.fromJson` (`subject_path` key, `requireString`) —
    no path normalization anywhere in the reader.
  - `.zfa/receipts/*.json` — `GenerationReceipt.files[]`
    (`GenerationReceiptFile.path`) is PROJECT-RELATIVE
    (`lib/tdd/<feature>/..._subject.dart`), loaded by
    `ReceiptStore(projectRoot).loadAll()`.
- The failing comparison: `ReceiptPreflight.check` builds
  `covered` = set of receipt `files[].path` (relative) and tests
  `covered.contains(_normalize(subject))` where `_normalize` is
  `p.normalize(path).replaceAll('\\', '/')` — no relativization →
  absolute-vs-relative never intersects → `missing_receipt` on every
  subject (issue #1312).
- Call chain (audit side, unchanged):
  `verify_command.dart` line ~224 → `MutationScope.derive(featureDir)`
  (returns `subjectPath` values verbatim from artifacts.json) →
  `ReceiptPreflight(projectRoot: cwd).check(auditedPaths: scope.subjectPaths)`.

## Approach

Fix at compare time inside `ReceiptPreflight` — no writer change, no
registry re-gen, no audit-semantics change:

1. `_normalize(String path)` becomes a relativizing normalizer
   (signature widens to `String?`):
   - Normalize separators first: `p.normalize(path)` then
     backslash → `/` (unchanged behavior for relative inputs —
     idempotent, back-compat with existing fixtures/tests).
   - If the normalized path is NOT absolute → return as-is
     (already project-relative).
   - If absolute → relativize against the project root:
     `p.relative(normalized, from: root)` with
     `root = p.normalize(p.absolute(projectRoot))` (so a relative
     `projectRoot` is still resolved deterministically). If the
     result escapes the root (`..` or `../*`) → return `null`
     (out-of-root subject).
2. `check()` call site: `_normalize(subject)` returning `null` →
   `continue` (skip — not an auditable subject of this project);
   otherwise the membership test and the finding path are unchanged
   (findings keep naming the project-relative path shape).
3. Doc comments updated to the real contract: audited paths may be
   absolute (as recorded by existing artifacts.json registries) or
   project-relative; absolute paths are relativized against
   `projectRoot`; out-of-root paths are skipped.

Why compare-time relativization and not fixing the writer: spec 044
FR-012..023 gates must pass on EXISTING registries (acceptance
criterion 3). A writer-only fix would leave every already-written
artifacts.json red forever. Constraint 5 forbids touching the writer
anyway.

## Test surface (see tdd/test-list.md)

- `test/plugins/tdd/services/receipt_preflight_test.dart` — unit tier:
  absolute-in-root covered → pass (SC-2); absolute-out-of-root →
  skipped (SC-3); mixed list (SC-4); relative back-compat already
  pinned by existing tests (SC-5); uncovered still fails closed
  (SC-6, existing tests).
- CLI tier (same file): `artifacts.json` with ABSOLUTE `subject_path`
  + covering receipt → `zfa tdd verify` prints
  `receipt preflight: ok` and proceeds past the gate (SC-1) — the
  exact repro of issue #1312 in miniature.

## Risk register

- **Symlinked temp dirs** (macOS `/var` → `/private/var`): tests derive
  subject files and receipts from the SAME `workspace.path` string, so
  textual relativization is consistent on POSIX CI. No
  symlink-canonicalization is introduced (would be a behavior change).
- **Case-insensitive filesystems**: out of scope — both stores are
  written by the same tooling on the same machine; textual compare is
  the pre-existing contract.
- **`p.relative` on a root-equal subject** (`.`): nonsensical input;
  produces a missing_receipt for `.` rather than silently passing —
  fail-closed, consistent with the gate's purpose.

## Verification strategy

Per the cloud-agent protocol: kernel-cache cleanup before/after, targeted
`dart analyze` on changed files, targeted `dart test` on the changed test
file ONLY (never the full suite), `dart format .` with zero remaining
diffs, disk housekeeping between phases.
