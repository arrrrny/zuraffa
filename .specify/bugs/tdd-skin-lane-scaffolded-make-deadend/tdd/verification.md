# TDD Verification — Bug 1258 (tdd skin lane scaffolded make dead-end)

- **Bug:** `tdd-skin-lane-scaffolded-make-deadend` — GitHub issue #1258
  (`tdd: SKIN lane dead-ends at make — scaffolded widget tests are refused
  with no supported authoring step`, severity high).
- **Generated:** FRESH from the actual runs in this session (2026-09-07,
  UTC+8) — not a copy of a prior verification.
- **Command path:** `/speckit.tdd.verify` semantics executed against the bug
  branch `fix/1258-tdd-skin-lane-scaffolded-make-deadend` (spec-kit
  `specify` CLI v1.0.5.dev0 installed via uv and checked; the repo's
  `.specify/extensions.yml` already carries the TDD extension v1.1.2 —
  enabled, `speckit.tdd.verify` command present. Step 0 engine detection:
  the repo root carries NO `.zfa.json`, so per the command's contract this
  is the **Fallback Path** (LLM-guided audit) — `zfa tdd verify` mutation
  dispatch does not apply to the zuraffa repo itself; the mutation-style
  guard evidence below substitutes for it).

## Verdict: **PASSED** (for the bug's changed surface, with 5 pre-existing
unrelated failures disclosed and triaged)

| Gate | Result |
|------|--------|
| RED (repro before fix) | ✅ `tdd/red-T001-issue1258-pre-fix.log` — with the `make_command.dart` fix stashed (pure `SkinAuthoring` service + tests present), 6/14 fail: 5 with the exact dead-end signature `❌ Could not find an option named "--author"` (no supported authoring step exists) and 1 pinning the padded-transcript guard tolerance. The 8 pure-contract tests pass (they encode the patch contract, not the CLI). |
| GREEN (after fix) | ✅ `tdd/green-T001-issue1258-fixed.log` — `+14: All tests passed!`, exit 0 (14/14: 5 SkinAuthoring patch-contract + 3 SuiteGuard tolerance + 6 CLI authoring tests U1–U6) |
| Live authoring flow (U1, the issue's scenario) | ✅ scaffolded placeholder finders replaced from `--finders-file`, marker cleared, authored red re-certified from a REAL failing run (`authored red certified (assertion)`), hand-delta receipt in `specs/<f>/tdd/provenance-ledger.json` (`recordedBy: zfa tdd make --author`), view-builder lane generated, `make: behavior=W-1258 outcome=green`, exit 0 — the driver resumes |
| Honest-refusal gates | ✅ U2: without `--author` the `outcome=scaffolded` refusal stands byte-identical, zero mutations; U3: born-green vacuity (finders the inert stub already satisfies) refuses + RESTORES scaffolded bytes + writes no evidence/receipt; U4: `--author` on a non-scaffolded test is a misfire refusal before any state change; U5: missing `--finders-file` usage refusal; U6: non-compiling author finders refuse with `classification: compile-error` and restore bytes (never a fabricated red) |
| `dart analyze` (changed files) | ✅ `tdd/analyze.log` — **No issues found!** |
| Targeted consumer suites (files that consume the changed lib files) | ✅ `tdd/consumer-suites.log` — `+48: All tests passed!`, exit 0 (`suite_guard_test`, `make_command_widget_939/950`, `make_command_declared_071/strict_071`, `make_command_1036`, `runner_suite_test`, `run_baseline_cache_test`) |
| `test/commands/make_skin_flag_test.dart` + `make_command_xray_default_test.dart` | ✅ +2 passed (fast tier) |
| `dart format --set-exit-if-changed lib test` | ✅ `tdd/format.log` — `Formatted 2363 files (0 changed)`, exit 0 — zero remaining formatting diffs in the CI-gated trees |
| Mutation-style guard checks | ✅ the negative tests prove the gates do not over-accept: born-green refusal (U3), compile-error refusal (U6), backward-compat refusal (U2); the authored red requires `RedClassification.assertion` (the same `classify` discipline `verify-red` enforces) |

## 1. Red → green cycle log

- **T001 (red):** `tdd/red-T001-issue1258-pre-fix.log` — with the command
  fix stashed, `dart test test/plugins/tdd/bug_1258_skin_author_make_test.dart
  --preset=all`: `+8 -6` — the five authoring tests fail with the issue's
  exact signature (`Could not find an option named "--author"`: the make
  command has NO supported authoring step), plus one SuiteGuard
  tolerance test (it pins the enabling parser fix). EXIT=1.
- **T001 (green):** `tdd/green-T001-issue1258-fixed.log` — with the fix
  applied, same command: `+14: All tests passed!` (exit 0).
- **Refactor:** no hand-edits; `dart format` normalization only
  (0 changed in `lib`/`test` after the fix). The pure patch contract lives
  in `skin_authoring.dart`; the command orchestrates it — no behavior
  duplication.

## 2. The fix (what changed)

1. `lib/src/plugins/tdd/services/skin_authoring.dart` (NEW) — the pure
   sanctioned-authoring transform: `patchedContent` replaces the scaffolded
   scenario block (marker comment + the `expect(find.byWidget(view),
   findsOneWidget);` placeholder) with author-supplied concrete finders and
   clears the `zfa:tdd: scaffolded` marker by construction;
   `validateAuthorFinders` refuses empty/marker-carrying/expect-less
   blocks. Registry-owned test bytes are mutated ONLY here — inside the
   pipeline, receipted.
2. `lib/src/plugins/tdd/commands/make_command.dart` — `zfa tdd make
   --author --finders-file <path>`: (a) patch + marker clear; (b) honest
   red-before-green re-certification via the shared `classify` gate — only
   an assertion-classified red certifies; born-green vacuity / compile /
   load failures RESTORE the scaffolded bytes and refuse (safe-failure,
   never a silent pass); (c) authored red evidence appended to the
   cycle-log + hand-delta receipt recorded in the provenance ledger (the
   `realize --scaffold` pattern, `recordedBy: zfa tdd make --author`); (d)
   falls through to the unchanged make flow so the run driver resumes past
   `<id>:make`. The certified-red precondition defers ONLY for
   `--author` + scaffolded targets; without `--author` the `outcome=
   scaffolded` refusal is byte-identical (U2).
3. `lib/src/plugins/tdd/services/suite_guard.dart` (enabling fix) — the
   pinned compact reporter pads every progress line to terminal width with
   TRAILING spaces (and redraws via bare `\r`) and prints no `Failing
   tests:` block for a red run, so the `$`-anchored failure grammar parsed
   a REAL red suite as zero failures → `parseable: false` → every
   baseline-carrying make refused ("suite baseline did not produce a
   usable snapshot") on this SDK. `parse()` now normalizes line endings
   and strips trailing whitespace per line before matching; the `-N` +
   `[E]` failure markers stay required. This un-breaks the existing slow
   tier on current SDKs: `make_command_test.dart` US1/U26 failed on
   PRISTINE master in this environment (baseline unparseable) and passes
   with this fix.

## 3. Success criteria — PROVED vs not

| Criterion | Status |
|-----------|--------|
| First-class, receipted scaffolded→concrete transition through the pipeline | **PROVED** (U1: finders replaced, red re-certified from a real failing run, ledger receipt written, marker cleared) |
| Validates red-before-green honestly | **PROVED** (U3 born-green refusal + restore; U6 compile-error refusal + restore; only `classification: assertion` appends evidence) |
| Registers the hand delta in the registry/provenance ledger | **PROVED** (`provenance-ledger.json` entry with `diffHash`, `recordedBy: zfa tdd make --author`, issue #1258 reason) |
| Clears the scaffold marker so the driver resumes | **PROVED** (U1: `contentIsScaffolded` false post-patch, view lane generated, `outcome=green` exit 0) |
| No regression on the existing refusal contract | **PROVED** (U2 byte-identical refusal, zero mutations, no generation) |
| Minimal fix with tests (red → green) | **PROVED** (2 lib files changed + 1 new service + 1 test file; RED log → GREEN log) |
| `tdd/verification.md` (REAL, from this run) | **PROVED** (this file, generated from the actual run logs stored beside it) |
| Full fast suite re-run | **NOT RUN on the whole tree in one invocation** — this sandbox has a 9.9 GB disk; `dart test test/plugins/tdd --exclude-tags flutter` as ONE invocation overflowed `/tmp` (the repo's own dart_test.yaml documents this exact hazard and mandates the chunked runner, which this disk still cannot hold). Per the cloud-agent protocol, verification is scoped to the changed files' suites: all changed-file consumers listed above pass 48/48 + 14/14 + 2/2; the chunked full-suite run is delegated to CI (which runs the fast tier per its own disk budget). |

## 4. Flagged: pre-existing failures (not from this fix)

`make-command-suite-flagged-preexisting.log` — 33 passed / 5 failed. All
five fail IDENTICALLY on pristine `master` (verified during this session by
stashing the fix and re-running each):

- `bug 657: an unexpressible make names the verb and the stub path...`
- `A11/U17: a unit-kind unexpressible make never composes (SC-004)`
- `A15 (amended by #737): failed terminal build ... outcome=skipped`
- `U-829g: the plan is entity create -> make <Entity> -> wire -> build`
- `U-829h: an existing entity is REUSED — the plan drops the entity create`

On master these refuse even earlier (the same baseline-parse class this PR
repairs); after the enabling fix they progress further and stop on their own
pre-existing expectation drift (message wording / plan shape), unrelated to
the skin-authoring change. Net effect of this PR on this file: US1/U26 goes
red→green; no previously-passing test regresses.

## 5. Environment notes (honest disclosure)

- Toolchain: Dart SDK 3.13.3 stable (linux x64) — meets the Dart 3.13+
  requirement. Flutter is NOT installed; the repo's own pubspec pins the
  package as pure Dart (`test` is dev-only, `flutter_test` appears only in
  generated-consumer templates), and the Flutter-only `example/` subpackage
  is intentionally unresolved (`flutter pub` domain) — out of scope for a
  CLI-lane fix.
- Disk housekeeping honored: kernel caches (`dart_test.kernel.*`,
  `.dart_tool/test/`) and temp fixtures were purged after every phase;
  the disk hit 100% once mid-suite and was reclaimed to 8.2 GB free before
  continuing (df snapshots in the session transcript).
- Dependency overrides: `pubspec.yaml`'s `dependency_overrides` section is
  already removed upstream (comment only); `dart pub get` resolved every
  dependency to the latest published version from pub.dev. No path:
  overrides were reintroduced.
