# Bug Assessment: `zfa tdd init` adds `mocktail` and pins `mutation_test: ^1.0.0`

- **Slug**: zfa-tdd-init-mocktail-mutation-version
- **Created**: 2026-09-02
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> when I ran zfa tdd init it added the mocktail as well, I remember we dont use mocktail anymore, so verify that and fix it ,and mutation_test should be 1.8.0 not 1.0.0

Two distinct defects in the same baseline writer, both surfaced by running `zfa tdd init`:

1. The writer adds `mocktail: ^1.0.0` to the generated project's `dev_dependencies`. The codebase has explicitly migrated to **zuraffa-native mocks** (no third-party mocking library) since the feature 524 / commit `783fd5dc` era — adding it back is regression.
2. The writer pins `mutation_test: ^1.0.0`. The downstream verifier (`MutationVerifier`) is only designed for the **v1.8.0+** report format; the repo itself is on `1.8.0` (`pubspec.lock`). `^1.0.0` would admit versions (e.g. `1.0.x`) whose report format the parser does not understand.

## Symptom

After running `zfa tdd init` in either a Flutter or pure-Dart project, the project `pubspec.yaml` ends up with `mocktail: ^1.0.0` and `mutation_test: ^1.0.0` in `dev_dependencies`. The `mocktail` entry contradicts the rest of the codebase (native-only mocks) and the `mutation_test: ^1.0.0` floor is too permissive — it would resolve to versions older than the parser's contract.

## Reproduction

1. Create a fresh project (Flutter or pure Dart) with a minimal `pubspec.yaml` whose `dev_dependencies` is `{}` or absent.
2. Run `zfa tdd init` from the project root.
3. Inspect `pubspec.yaml` after the command exits cleanly.
4. **Observed**: the `dev_dependencies` block now lists `mocktail: ^1.0.0` and `mutation_test: ^1.0.0`.
5. **Expected**: no `mocktail` line at all (native mocks); `mutation_test: ^1.8.0` (matching the wired version in `pubspec.lock` and the `MutationVerifier` parser).

## Suspected Code Paths

- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:22` — `'mocktail': '^1.0.0',` inside `flutterDevDependencies`.
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:26` — `'mutation_test': '^1.0.0',` inside `flutterDevDependencies`.
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:31` — `'mocktail': '^1.0.0',` inside `dartDevDependencies`.
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:35` — `'mutation_test': '^1.0.0',` inside `dartDevDependencies`.
- `lib/src/plugins/tdd/commands/init_command.dart:138-140` — calls `PubspecDevDependenciesPatcher.ensure(cwd)` (so `init` is the consumer that surfaces this).
- `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart:30-69` — currently pins the buggy contract (`expect(added.length, 7)`, asserts `mocktail` and `mutation_test` are present at the wrong floor). **Tests must be updated in lockstep with the fix.**
- `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart:82, 88` — duplicate-and-presence assertions for `mocktail` also need to flip.

Cross-evidence (why both halves are bugs):

- `lib/src/mock/mock.dart:1-12` — "Zuraffa generates its own test doubles — mock datasources, mock data, mock providers, and throwing doubles — so a zuraffa-built app can run end-to-end on full native mocks with **no third-party mocking library** (mocktail / mockito)."
- `lib/src/plugins/test/builders/test_builder_entity.dart:6` — "Emits **native** zuraffa mocks (no `package:mocktail`)."
- `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart:183-186` and `:258-261` — generated entity test code is asserted **MUST NOT** import `package:mocktail/mocktail.dart`.
- `lib/src/plugins/tdd/services/mutation_verifier.dart:216` — "The mutation_test package (v1.8.0+) emits these in multiple forms across versions".
- `lib/src/plugins/tdd/services/mutation_verifier.dart:236` — "OR 'Detected by: test N' (mutation_test v1.8+ format)."
- `pubspec.lock:476-483` — the project itself resolves `mutation_test` to `version: "1.8.0"`.
- `mutation-test.xml:68`, `tools/run-tdd-tests.sh:6`, `specs/041-tdd-setup-plugin/tdd/verification.md:13` — all reference the wired tool as **v1.8.0**.
- Root `pubspec.yaml:81` — `mutation_test: ^1.1.4` in zuraffa's own dev_dependencies (so even the existing root floor is older than the wire — the user is asking to align the generated baseline with the actual wired version, 1.8.0).

## Root Cause Hypothesis

`PubspecDevDependenciesPatcher` was last updated for spec 041 (`# tdd-setup-plugin`, see file-level comment "Bug #716") to ensure `test` and the rest of the baseline. At that point, `mocktail` was still in use and `mutation_test` had not yet been pinned. Subsequent work (mock-feature native migration in #524 / commit `783fd5dc`; mutation wiring at v1.8.0) updated the rest of the codebase but did **not** prune `mocktail` from the baseline list nor tighten the `mutation_test` floor. So the writer is now an island of stale state.

**Confidence**: high — both claims are corroborated by file-level comments, regression tests, the verifier's parser, and the lockfile.

## Proposed Remediation

**Preferred** (single-file fix in `pubspec_dev_dependencies_patcher.dart`):

1. Remove the `'mocktail': '^1.0.0',` entry from **both** `flutterDevDependencies` (line 22) and `dartDevDependencies` (line 31).
2. Update the `'mutation_test': '^1.0.0',` entry to `'mutation_test': '^1.8.0',` in **both** maps (lines 26 and 35). Floor of `1.8.0` is the lowest version whose report format `MutationVerifier._parseCounts` understands; below 1.8 the parser would silently miscount.
3. Update the file-level comment block above `flutterDevDependencies` to mention that mocktail was dropped (so the next reader doesn't re-add it) and that the `mutation_test: ^1.8.0` floor matches `MutationVerifier`.

**Test updates** (lockstep, in `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart`):

- Lines 43, 56–66: drop `7` → `6`, drop `mocktail` from the asserted-keys set.
- Line 50: keep the `mutation_test` presence check (still must be added) but no version assertion needed in that test (covered indirectly via the dry-run key check).
- Lines 82 and 88: replace the duplicate-prevention case with a `mocktail`-absence case — e.g., assert that an existing `mocktail: ^1.0.0` line in the user pubspec is **not** re-added by the writer (because the writer no longer wants it). Then verify that `flutter_test` count is still `1`.
- Consider adding a new `group("mutation_test floor is ^1.8.0")` that asserts both maps' `mutation_test` constraint is exactly `^1.8.0`, so a future regression to `^1.0.0` fails loudly.

**Optional but recommended**: also tighten the root `pubspec.yaml:81` from `^1.1.4` to `^1.8.0` so the zuraffa dev tree matches the baseline it generates. **Flag for user**: this is a root-only change with no behavioural impact on the TDD loop, so the user may want to keep it as a separate concern.

**Alternatives**:

- *Leave mocktail in but unconstrained.* Rejected — the codebase has regression tests asserting no mocktail imports; leaving it in the pubspec invites a future generated test to import it and trip the regression.
- *Pin `mutation_test: ^1.0.0` and bump the verifier to handle v1.0–v1.7 report shapes.* Rejected — wider blast radius, no benefit (every wired instance is on 1.8.0 already).

**Files likely to change**:

- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`
- `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart`

**Tests to add or update**:

- Pin `mutation_test` floor at `^1.8.0` in both maps.
- Drop `mocktail` from the "all missing deps added" assertion and the "duplicate prevention" assertion.
- New test: writer does **not** add `mocktail` even if the user's pubspec lacks it.

## Open Questions

- None blocking. The user statement is unambiguous; the codebase contains explicit supporting evidence for both halves. If the user wants the root `pubspec.yaml:81` tightened in the same change, confirm before patching.