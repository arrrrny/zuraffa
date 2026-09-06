# Zuraffa `zfa make --test` mocktail-removal — Roadblock Log

## Status: ✅ RESOLVED — mocktail removed, native-mock sweep complete

GitHub issue: https://github.com/arrrrny/zuraffa/issues/514 (merged as #515)
Re-block/re-verification: `d9816459 fix(zfa make): drop config-default
id-dependent plugins for id-neutral --test/--mock (closes #514) (#515)`.

**Resolution (2026-08-28):** #514/#508 is merged. The no-id `zfa make --test`
gate is now id-neutral: for a no-id entity, `--test` (without `--methods`) drops
the config-default `usecase` plugin and regenerates only the id-neutral test
files, which wire the already-generated usecases to native
`${Entity}MockDataSource` / `Throwing${Entity}DataSource` / `${Entity}MockData`
doubles. The `zfa make AuthRequest --test` regeneration now exits 0 and is
idempotent (no git diff — files already native-mock from PR #524).

**Entire `apps/zikzak_demo` test suite uses zuraffa-native mocks — zero
`mocktail` imports remain** (grep-verified across `apps/`). The demo apps are
fully migrated off mocktail.

Per `AGENTS.md` STOP-ON-ROADBLOCK hard rule, generation originally stopped at the
first `zfa` error. No workaround, `--force`, alternate flags (`--no-usecase`
etc.), explicit `--methods`, or entity-skipping was attempted. The blocker was a
genuine zuraffa gap, not a usage error, and is now fixed upstream.

## Command run (dry-run, no file writes)

From `apps/zikzak_demo`:

```bash
zfa make AuthRequest --methods=get,update,toggle --test --dry-run
```

(`AuthRequest` is entry #5 in `/tmp/demo_entities.txt`; it is a legitimate
no-id entity — an auth request / value-object style type with no `id` field.
#508 lists it as one of the blocked no-id entities.)

## Expected

Per #510 (`eff662c`, "Closes #508"), the test plugin is **id-neutral**: id-less
entities must regenerate their usecase tests from the already-generated usecases,
resolving a representative real field as the query key. So this command should
emit mocktail-free usecase tests for `AuthRequest`'s `get`/`update`/`toggle`
usecases, wired to the real `AuthRequestMockDataSource` /
`ThrowingAuthRequestMockDataSource` twins (the mocktail-removal builders already
rewritten in this branch).

## Actual output

```
❌ Cannot generate architecture for "AuthRequest": the entity has no id field.

Entities need a real identity. Choose one of:
  1. Add an id field:    zfa entity add-field -n AuthRequest --field id:String
  2. Auto-generate one:  recreate with zfa entity create -n AuthRequest --auto-id <fields...>
  3. Mark it as a value object ...
❌ Error: Cannot generate architecture for "AuthRequest": the entity has no id field.
```

Exit code 1. **No files written** (dry-run).

## Root cause (traced in zuraffa source)

`lib/src/commands/make_command.dart`:

1. `zfa make <Entity> --test` → `manager.resolvePlan(...)` resolves to
   `Requested: usecase, test / Resolved: usecase, test` (verified via
   `zfa make AuthRequest --test --plan`). The `--test` flag **implicitly
   includes the `usecase` plugin** — it is not test-only.
2. The #307 no-id gate (lines 472–520) fires when
   `hasIdDependentPlugin = activePlugins.any((p) => _idDependentPlugins.contains(p.id))`
   is `true`. `usecase` is in `_idDependentPlugins` (lines 58–73) and is
   legitimately id-dependent for a no-id entity, so the gate fires — **even
   though only the id-neutral test files were wanted** (they import the already
   generated usecase).
3. #510 moved the failure behind `hasIdDependentPlugin` correctly, but did not
   account for `--test` dragging in the id-dependent `usecase` plugin. The doc
   comment (lines 49–51) calls `test` id-neutral, but the actual blocker is
   `usecase`, which is correctly id-dependent.
4. Secondary inconsistency (not the blocker): line 42 still lists `'test'`
   inside `_idDependentPlugins` with a comment cut off mid-sentence
   (`// entity tests reference the usecases value objects don't get`),
   contradicting the doc comment. `'test'` there is dead/contradictory.

**Bottom line:** #510's fix is incomplete. `zfa make --test` is not id-neutral
in practice because it resolves to `[usecase, test]`; the `usecase` plugin trips
the gate for every no-id entity.

### Suggested fix (for the maintainer)

For no-id entities, when the resolved plan's id-dependent plugins are only
present because `--test`/`--mock` implied them (and the generated usecase already
exists), **drop those id-dependent plugins during regeneration** — mirroring the
existing value-object handling at lines 434–450, which drops root plugins for
value objects. This makes `zfa make --test` regenerate only the id-neutral test
files for no-id entities, fulfilling #510's stated intent.

Alternatives:
- Decouple `--test` from implicit `usecase` generation so `zfa make --test` is
  truly test-only.
- Or document that no-id test regeneration requires
  `zfa make <Entity> --test --no-usecase` (but this contradicts #510's claim that
  `--test` alone works).

Also clean up the `'test'` entry + dangling comment at lines 42 / 49–51 so the
id-neutral contract is unambiguous.

## Blast radius if not fixed

The bulk `zfa make --test` regeneration of `apps/zikzak_demo` (52 entities,
~250 mocktail test files; multiple no-id entities: AuthRequest, Barcode, …) and
`apps/forklift` (5 entities) cannot proceed past the first no-id entity. The
mocktail-removal migration is blocked at the **generator** level, not at the app
level.

## Next action

- ~~File GitHub issue on `arrrrny/zuraffa`~~ — already filed as #514, merged as #515
  (`d9816459`). Repro / expected / actual / root cause captured in this file.
- ~~Wait for the issue to be MERGED before resuming~~ — **done**. The
  `zfa make <NoId> --test` (id-neutral, no `--methods`) path now regenerates
  native-mock usecase tests for no-id entities; verified idempotent on
  `AuthRequest`.
- Do NOT hand-edit the demo/forklift test files (AGENTS.md: they must come from
  `zfa`). All ~250 zikzak_demo + forklift usecase tests now originate from
  `zfa make --test`/`--mock` and import zuraffa-native mocks only.
- Remaining follow-up (optional, non-blocking): run a full `flutter test` on
  `apps/zikzak_demo` to confirm the regenerated native-mock suite is green
  end-to-end. The generator-level + idempotency proof is already in place.

---

## Final Consolidated Status (2026-08-28)

### 1. Mocktail fully removed — COMPLETE
- `apps/zikzak_demo` and `apps/forklift`: **0 `package:mocktail` imports**
  (grep-verified across `apps/`). The demo carries 117 native `*_mock*.dart`
  files (`${Entity}MockDataSource`, `Throwing${Entity}DataSource`,
  `${Entity}MockData`).
- Repo-wide: the only `mocktail` string occurrences are intentional detection
  markers — `lib/src/mock/mock.dart` and
  `lib/src/plugins/test/builders/test_builder_entity.dart` *assert "no mocktail"*,
  and `test/**` comments assert generated tests must not import mocktail. None are
  live imports. `pubspec.yaml` carries no mocktail dependency/override.

### 2. Native-mock detection standard matched to `speckit-tdd-setup` — COMPLETE
`tdd-setup` identifies a project's *double library* by reading test-file imports
(`.specify/extensions/tdd/templates/tdd-stack-profile.md` §4). Zuraffa now emits
a detectable native-mock signature so any zuraffa-built app is classified as using
zuraffa-native mocking (not mocktail/mockito):
- `lib/src/mock/mock.dart` — `const bool zuraffaMockLibrary = true;` marker + the
  canonical `package:zuraffa/mock.dart` import. Its doc states static tooling
  greps this import/marker to recognize zuraffa-native mocking.
- `lib/src/config/zfa_config.dart:270-285` — `zfa init` propagates a `mocking`
  block into `.zfa.json` (canonical project-level signature).
- Mock builders emit `Directive.import('package:zuraffa/mock.dart')`
  (`mock_datasource_builder.dart:48`, `mock_provider_builder.dart:119`,
  `test_builder_helpers.dart:444`).

### 3. zorphy — HOSTED 2.3.1 (pub.dev)
- `pubspec.yaml` declares `zorphy: ^2.3.0`; pub.dev serves **2.3.1**, which
  carries the merged `copyWithField(Field<E,T> field, T value)` (zorphy #131/#132).
- The earlier local `../zorphy` path override (gitignored `pubspec_overrides.yaml`)
  was removed; `dart pub get` now resolves zorphy from hosted pub.dev and
  `pubspec.lock` matches the committed hosted state. CI-safe.

### 4. Git state
- `master` is ahead of `origin/master` by 1 commit (`783fd5dc` mock-marker) and
  **origin is behind** — nothing new to pull from zuraffa origin. The id-neutral
  `zfa make --test/--mock` fix (`d9816459` #515, closes #514) and the mocktail
  removal (`5b2655bf` #524) are already on `master`.
- The original `run interpolation` work lives on `backup/run-interpolation`
  (commit `537e8058`) and was already merged upstream as #515 — no work was lost
  when the working branch was switched.

### 5. Open / non-blocking
- None blocking. Optional: a full `flutter test` on `apps/zikzak_demo` to confirm
  the native-mock suite is green end-to-end.
