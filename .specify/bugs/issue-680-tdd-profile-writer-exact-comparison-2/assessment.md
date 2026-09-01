# Bug Assessment: [zfa tdd init] TddProfileWriter rejects valid non-Flutter profiles on re-run (exact-content comparison too strict)

- **Slug**: issue-680-tdd-profile-writer-exact-comparison-2
- **Created**: 2026-09-01T14:12:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/680
- **Verdict**: likely valid, needs reproduction
- **Severity**: medium

## Report (verbatim or summarized)

`TddProfileWriter` (used by `zfa tdd init`) throws `StateError` and exits non-zero when an existing `tdd-profile.md` has valid-but-different content — even when the project kind (Dart vs Flutter) matches exactly. This blocks idempotent re-runs of `zfa tdd init` on any project that already has a profile.

Issue: https://github.com/arrrrny/zuraffa/issues/680

## Symptom

When running `zfa tdd init` on a project that already has a `tdd-profile.md` with valid-but-different content (e.g. enriched by an ecosystem detector), the tool throws `StateError: tdd-profile.md already exists at ... with different content; refusing to overwrite. Pass --force to overwrite or delete the file first if you want to regenerate.` and exits non-zero, even though the profile's runner kind matches the current project.

## Reproduction

1. Run `zfa tdd init` on a pure Dart package — creates `.specify/memory/tdd-profile.md` with `runner: dart`
2. Enrich the profile with richer metadata (e.g. ecosystem detector adds `runner: "package:test (^1.24.0)"` and `single: 'dart test -n "{name}"'`)
3. Run `zfa tdd init` again
4. → `StateError` thrown; non-zero exit
5. Workaround: re-run with `--force`

## Suspected Code Paths

- `lib/src/cli/writers/tdd/tdd_profile_writer.dart:34-46` (`TddProfileWriter.write()`) — the gate: exact content comparison, no runner-kind check against existing file
- `lib/src/plugins/tdd/commands/init_command.dart:73-84` — caller; catches `StateError` and surfaces it as a failure
- `lib/src/plugins/tdd/models/tdd_profile.dart:54-59` (`TddProfile ==`) — equality is also exact-field, reinforcing that only the exact preset is "equal"

## Root Cause Hypothesis

**Confidence: medium (code evidence strong; reproduction path confirmed through code inspection).**

`TddProfileWriter.write()` performs a single content comparison (line 36) to decide idempotency. When the existing file differs, it unconditionally throws `StateError` unless `force == true` (line 39-44). The method never inspects the existing file's runner kind — it only compares rendered output strings. This means any profile enrichment (even a valid `package:test (^1.24.0)` runner) triggers the rejection, despite no genuine Flutter-vs-Dart conflict existing. The `_render()` method already knows how to derive `isFlutterProfile` from the `runner` field (`tdd_profile_writer.dart:55`), but this logic is never applied to the existing file — only to the outgoing content being generated.

The secondary frontmatter regex bug (`multiLine: true` breaking `^` anchoring) was mentioned by the reporter as an attempted-fix artifact; it appears in the reporter's local work, not in the current upstream `tdd_profile_writer.dart`.

## Proposed Remediation

**Preferred**: Modify `TddProfileWriter.write()` to extract the `runner` key from the existing file's frontmatter before the exact-content comparison. If the existing file's runner is a Dart-family runner (`dart`, `package:test`, etc.) and the writer is targeting a Dart profile, accept the existing file as valid and return `null` (no-op). Only throw when:
- Content is byte-identical (current idempotency, line 36-37), OR
- The existing runner is Flutter but the writer targets Dart (genuine flavor conflict), OR
- `force == true` (explicit clobber)

The `runner` extraction can use a simple regex: `RegExp(r'^runner:\s*(.+)$', multiLine: true)` to scan the YAML keys section of the frontmatter. Since `multiLine: true` on `^` is correct here (we want to match `runner:` at the start of any line in the keys block), no regex fix is needed for this extraction pass.

**Alternative 1** (partial): Document `--force` as the escape hatch; the `StateError` message already suggests it. Low implementation cost but poor UX — users should not need to know `--force` to re-run on an already-valid profile.

**Alternative 2** (simpler, less precise): Drop the exact-content guard entirely for non-Flutter profiles, always accepting any existing file. Loses the check that would catch a genuine mismatch after a project migration (e.g. Dart → Flutter).

**Files likely to change**:
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart` — main fix
- `test/cli/writers/tdd/tdd_profile_writer_test.dart` — add test for "accepts existing Dart profile with different runner metadata"

**Tests to add or update**:
- New test: "accepts an existing Dart-family profile with a different runner value (e.g. `package:test` vs `dart`)" — expects `null` (no-op), not `StateError`
- New test: "rejects an existing Flutter profile when targeting a Dart project" — expects `StateError`
- The existing test at line 46 (`refuses to clobber an existing file with different content`) should be updated or split: it uses a completely unrelated content `# Different content\n` without a `runner:` key, so it would still throw — the Dart-family acceptance should only apply when the existing file has a valid Dart runner key.

## Risks & Considerations

- The `runner` extraction must be robust to malformed frontmatter (missing `runner:` key). In that case, fall back to the current strict behavior (throw).
- Existing files created by older `zfa tdd init` runs will have `runner: dart` and will pass through unchanged — no regression.
- The ecosystem detector that produces `stacks: dart: { runner: ... }` enrichment is mentioned in the issue but not present in the current upstream codebase — the fix should also handle the flat `runner:` format used by `_render()`.
- If a user migrated from Flutter to Dart but kept the old profile, the fix would now silently accept it. The flavor-conflict check (Flutter runner in existing file + Dart profile being written) is the guard against this.

## Open Questions

- [NEEDS CLARIFICATION: Does the ecosystem detector (or any other upstream tool) write a `stacks: dart: { runner: ... }` nested structure, or does it also write a flat `runner:` key? The fix's extraction should match what the detector actually produces.]
- [NEEDS CLARIFICATION: What is the complete set of Dart-family runner values to recognize? `dart`, `package:test`, and pinned versions (`package:test (^1.24.0)`)? Should `flutter_test` be the only Flutter signal?]
