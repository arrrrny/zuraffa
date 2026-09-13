# Bug Verification: artifacts.json silently swallows corruption

- **Slug**: 1470-artifacts-json-corruption-silent
- **Tested**: 2026-09-13
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified (corrupt registry now fails loud; missing-file
  contract unchanged)
- **TDD verification**: `tdd/verification.md` (from the real run in this
  session)

## Summary

Pre-fix, a corrupt `artifacts.json` was indistinguishable from an absent
one: `_loadRecords()` mapped `FormatException` to `[]`, so `register()`
re-registered behaviors with `Ownership.created` and the next append
rewrote the file, destroying the prior records (reproduced on unmodified
master with a scratch script before touching the library). Post-fix, the
same corruption raises `ArtifactRegistryCorruptException` naming the file
and the recovery path, on every read/write path (`loadAll`, `findRecord`,
`preflight`, `register`, `append`), while a genuinely missing registry
still behaves as the FR-012 empty registry.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (pre-fix) | scratch script on unmodified master: corrupt `artifacts.json`, `loadAll()` + `register()` | silent data loss | `[]`, then `Ownership.created`, registry rewritten to `[B-003]` — B-001/B-002 destroyed |
| RED | `dart test test/plugins/tdd/services/artifact_registry_test.dart` (type defined, throw not wired) | fail 4/5 new tests | failures are the bug's own symptoms; FR-012 guard passed throughout |
| Post-fix (GREEN) | same command after wiring the throw | pass 20/20 | `00:00 +20: All tests passed!` |
| Corrupt-file untouched | `register()` on a corrupt registry, byte-compare after | pass | store never "repairs" by overwrite; recovery path intact |
| Message contract | throwsA matchers on the message | pass | names path, `Unexpected end of input` cause, "Delete the file", "re-run gen" |
| Missing-file guard | `loadAll`/`findRecord`/`register` on absent file | pass | FR-012 unchanged |
| Neighbor suites | `dart test test/plugins/tdd/services/` and `.../commands/` | pass +950 / +533 | registry consumers incl. `RunStateStore` unregressed |
| Chunked fast suite | `tools/run_tests_chunked.sh` (resumed via `run_chunks_range.sh`) | pass 99/104 chunks, 0 failed | 5 SKIP = pre-existing all-slow folders (baseline quirk) |
| Static analysis | `dart analyze` (changed files / full project) | pass | No issues found! / 112 info lints = stashed-fix baseline, 0 errors 0 warnings |
| Formatter | `dart format .` then re-run | pass | 1 file re-joined (the new test group); suite re-run green |

## Output Excerpts

Pre-fix reproduction (scratch script, unmodified master):

```text
loadAll() on CORRUPT file -> []                <-- silent empty list
register(B-003) -> Ownership.created           <-- re-registered as fresh
registry file now contains: [B-003]            <-- B-001/B-002 DESTROYED
```

Post-fix (same corruption):

```text
Unhandled exception:
Corrupt artifacts.json at .../specs/044-demo/tdd/artifacts.json:
Unexpected end of input. Delete the file and re-run gen to rebuild the registry.
#0 ArtifactRegistry._loadRecords (package:zuraffa/.../artifact_registry.dart)
```

## Residual Risks

- Readers of a corrupt registry now error instead of reporting an empty
  feature — intended (fail loud), consistent with `RunStateStore` and the
  other TDD stores; the recovery is one `rm` + `gen`, printed in the
  message itself.
- Well-formed-JSON-but-wrong-shape files still raise `TypeError` from the
  casts, not `ArtifactRegistryCorruptException`; widening that would
  exceed the issue's hard constraint ("fix ONLY the FormatException
  handling") and is left for a follow-up if ever reported.

## Recommendation

Close #1470 as fixed: corruption is now loud on every registry path, the
recovery message is actionable, and the missing-file contract (FR-012)
plus the ownership model are byte-for-byte unchanged.
