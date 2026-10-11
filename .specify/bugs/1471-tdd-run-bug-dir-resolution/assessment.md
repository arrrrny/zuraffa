# Bug Assessment — #1471: `zfa tdd run` rejects bug directories

- **Slug**: 1471-tdd-run-bug-dir-resolution
- **Created**: 2026-09-10
- **Source**: https://github.com/arrrrny/zuraffa/issues/1471
- **Verdict**: valid
- **Severity**: high

## Source Fetch Record

- **URL (verbatim)**: `https://github.com/arrrrny/zuraffa/issues/1471`
- **Host**: `github.com` — **allowlisted** (policy branch 2)
- **Retrieval**: `gh issue view 1471 --repo arrrrny/zuraffa --json …` — an
  authenticated CLI fetch of the structured issue payload, not an HTML page
  fetch; nothing was followed or redirected. No instruction-like content
  appeared in the body; nothing was acted on beyond reading it as data.

## Report (verbatim, condensed)

> The speckit bug extension's TDD mode (`bug.fix` with `tdd_enabled: true`) pins
> `.specify/feature.json` → `feature_directory: .specify/bugs/<slug>` and expects
> `zfa tdd run` to operate on the bug directory. It cannot.

Repro (from the issue):

```bash
# 1. tdd PLAN accepts a bug directory (issue #1182) — works:
zfa tdd plan .specify/bugs/cycle-log-phantom-sections
# → wrote .../tdd/test-list.md (exit 0)

# 2. tdd RUN with the feature.json pin, bare slug — ignores the pin:
zfa tdd run cycle-log-phantom-sections --timeout 25
# → zfa tdd run: no feature directory at specs/cycle-log-phantom-sections
# → result=runner-error ... EXIT: 2

# 3. tdd RUN with the bug-dir path — grammar refusal:
zfa tdd run .specify/bugs/cycle-log-phantom-sections --timeout 25
# → ❌ invalid feature ".specify/bugs/cycle-log-phantom-sections": expected a
#    single spec directory name such as 049-tdd-run, not a path. EXIT: 2
```

Reporter's root cause: `run_command.dart` hardcodes
`featureDir: p.join(projectRoot, 'specs', feature)` and never consults
`.specify/feature.json`; `doctor`/`verify` appear to share the assumption.
Impact: every `/skill:speckit-bug-fix` with `tdd_enabled: true` on this repo
stops at `zfa tdd run`. Hit running bug-whole for issue #1467
(slug `cycle-log-phantom-sections`, branch `fix/cycle-log-phantom-sections`).

## Symptom

`zfa tdd plan <ref>` resolves a bug directory, but `zfa tdd run <ref>` resolves
only `specs/<name>`: the bare slug is rejected as a missing feature dir
(exit 2, `runner-error`) and the explicit `.specify/bugs/<slug>` path is
rejected as a usage error (exit 2). Expected: `run` (and `doctor`/`verify`)
resolve the feature exactly as `plan` does, so the documented bug-workflow TDD
loop (`bug.fix` → `tdd.plan` → `tdd.run` → `tdd.verify`) can complete.

## Reproduction

1. In a project with a bug directory (`.specify/bugs/<slug>/spec.md` and a
   `tdd/test-list.md` written by `zfa tdd plan .specify/bugs/<slug>`), run
   `zfa tdd run .specify/bugs/<slug>`.
2. Observe the usage refusal (`invalid feature … not a path`) and exit 2.
3. Run `zfa tdd run <slug>` (bare). Observe `no feature directory at
   specs/<slug>` and exit 2.

Both failure modes are reproducible from the source alone — no missing
environment detail. `[NEEDS CLARIFICATION: the exact fixture project/branch the
reporter used is not preserved in the issue; a temp-dir fixture reproducing the
same layout is sufficient — see tests below.]`

## Suspected Code Paths

- `lib/src/plugins/tdd/services/feature_path_resolver.dart:60` —
  `TddFeaturePaths.resolve`, the #1182 shared resolver. Already supports all
  four documented shapes: plain name, `specs/<name>`, `.specify/bugs/<slug>`,
  absolute path. It is **called from exactly one place** (next bullet), which is
  the whole asymmetry.
- `lib/src/plugins/tdd/commands/plan_command.dart:160` — the **only** caller of
  `TddFeaturePaths.resolve`. This is why plan works and run does not.
- `lib/src/plugins/tdd/commands/run_command.dart:169-170` — `stripSpecsPrefix`
  then `validateFeatureSegment`, whose `/`-rejection produces the exact
  `❌ invalid feature … not a path` message and, via
  `lib/src/cli/cli_runner.dart:399` + `lib/src/cli/exit_protocol.dart:48`
  (`usage = 2`), the reported exit 2.
- `lib/src/plugins/tdd/commands/run_command.dart:195, 307, 329, 390, 438, 472,
  479` — seven hardcoded `p.join(projectRoot, 'specs', feature)` sites
  (preflight journal, cert gate, both lane journals, unified journal, meta
  journal). Matches the issue's line list.
- `lib/src/plugins/tdd/commands/run_driver_core.dart:256` — **`RunDriverCore.drive`
  joins `specs/<feature>` itself**, plus `:1298` (transaction),
  `:1433`/`:2380` (cycle log). Fixing `run_command.dart` alone is therefore
  insufficient: the driver core must receive the resolved featureDir (or the
  resolved reference) or a bug-dir run will write its journal, receipts and
  cycle log under a fabricated `specs/<slug>` path.
- `lib/src/plugins/tdd/commands/run_driver_core.dart:2104-2112` —
  `_handStepViolationFor` derives the project root by walking up only when the
  feature dir's parent is named `specs`; for `.specify/bugs/<slug>` the parent
  is `bugs`, so it would resolve the project root to `.specify/bugs` and probe
  a bogus `<…>/bugs/test/...` path. A second, easy-to-miss site that must learn
  about the bug-dir layout.
- `lib/src/plugins/tdd/commands/run_engine_command.dart:177-178, 192, 214, 245`
  — same strip+validate and `specs/` hardcodes; `checkFeature(featureDir:)` is
  called from run_command:307 with the wrong dir for a bug feature.
- `lib/src/plugins/tdd/commands/run_skin_command.dart:166-167, 187` — same.
- `lib/src/plugins/tdd/commands/doctor_command.dart:127, 137` — same
  (`no feature directory at specs/$feature`).
- `lib/src/plugins/tdd/commands/verify_command.dart:113, 168, 477` and
  `:492` — same, and worse: `_resolveFeatureFromCwd` is a deliberate stub that
  always returns `null`, so `verify` has **no** feature-resolution fallback at
  all.
- `lib/src/plugins/tdd/services/composition_targets.dart:154` —
  `isBugFeatureDir` *already* recognizes a real `.specify/bugs/` path segment
  (not just the legacy `bug-` basename). The composition layer is ready; it is
  only the path plumbing that is not.

The report's "doctor/verify have the same assumption" claim is **confirmed**.
Its line-number list for `run_command.dart` is **accurate**. Its framing is
**incomplete in one respect**: no command in the TDD plugin reads
`.specify/feature.json` (grep: `feature.json` appears in the plugin only inside
the resolver's doc comment). The pin is consumed by *other* plugins
(`lib/src/plugins/skeleton/bone_command.dart:101`,
`lib/src/commands/simulate_command.dart:395-422`,
`lib/src/plugins/mock/capabilities/certify_mock_capability.dart:251`,
`lib/src/plugins/mock/services/dependency_declaration_reader.dart:108`,
`lib/src/engine/engine_receipt_writer.dart:298`) — so "honor the pin when no
positional is given" is a **new capability**, not a regression.

## Root Cause Hypothesis

`TddFeaturePaths.resolve` was introduced by #1182 to teach *one* command (plan)
the `.specify/bugs/<slug>` shape; the run/doctor/verify family still carries the
pre-#1182 `specs/<feature>` assumption in four layers — the per-command
validators (`validateFeatureSegment` / `_validateFeatureSegment`), the
per-command dir joins, `RunDriverCore.drive`'s internal join, and the
`_handStepViolationFor` project-root walk. Since no TDD command ever read the
`feature.json` pin, the bug extension's documented loop has never actually been
runnable past `plan`. **Confidence: high** — every claim above is verifiable
from the cited lines, and the reported exit codes follow mechanically from
`ExitProtocol.usage = 2` + `cli_runner.dart:399`.

## Proposed Remediation

**Preferred** — complete the #1182 migration instead of adding a second
resolver:

1. Make `TddFeaturePaths` the single entry point: add an optional
   `featureDirectoryPin(projectRoot)` that reads
   `.specify/feature.json` → `feature_directory` (reuse the existing parse
   shape from `simulate_command.dart:395-422`; malformed pin = honest refusal,
   never a silent guess) and use it when the positional reference is absent.
2. Route the positional reference through `TddFeaturePaths.resolve` in
   `run_command.dart`, `run_engine_command.dart`, `run_skin_command.dart`,
   `doctor_command.dart` and `verify_command.dart`; use `ResolvedFeatureDir.name`
   as the canonical feature name for artifacts, receipts and the summary line,
   and `ResolvedFeatureDir.dir` for every path. Drop the
   `validateFeatureSegment` pre-check for the *positional* (it is strictly
   weaker than the resolver) while keeping the documented misuse message for
   genuinely undeclared shapes.
3. Change `RunDriverCore.drive` to take the resolved `featureDir` (keeping
   `feature` as the name) and thread it to the transaction, cycle-log and
   lane-receipt sites at `:256`, `:1298`, `:1433`, `:2380`; pass it through from
   both lane commands and from `run_command`'s `checkFeature` call too.
4. Fix the project-root walk at `run_driver_core.dart:2104-2112` to derive the
   root from the resolved layout (e.g. stop at the directory containing
   `.specify`/`specs`) rather than keying on a parent literally named `specs` —
   otherwise generated-test paths stay wrong for bug features even after 1–3.

**Alternatives**:
- *Minimal*: special-case `.specify/bugs/<slug>` in each command without
  touching `drive`. Rejected — it duplicates the #1182 resolver, leaves the
  driver core and the project-root walk wrong, and re-introduces exactly the
  plan/run divergence this bug is about.
- *Bridge*: have the bug extension write a `specs/bug-<slug>` symlink again.
  Rejected — #1182 exists to delete that bridge, and it produces odd relative
  paths in artifacts.

**Files likely to change**:
- `lib/src/plugins/tdd/services/feature_path_resolver.dart` (pin support)
- `lib/src/plugins/tdd/commands/run_command.dart`
- `lib/src/plugins/tdd/commands/run_driver_core.dart`
- `lib/src/plugins/tdd/commands/run_engine_command.dart`
- `lib/src/plugins/tdd/commands/run_skin_command.dart`
- `lib/src/plugins/tdd/commands/doctor_command.dart`
- `lib/src/plugins/tdd/commands/verify_command.dart`

**Tests to add or update**:
- New `test/plugins/tdd/commands/run_command_bug_1471_test.dart`, modeled on
  `test/plugins/tdd/commands/plan_command_bug_1182_test.dart`: temp fixture with
  `.specify/bugs/<slug>/spec.md` + a plan-written `tdd/test-list.md`; drive
  `zfa tdd run .specify/bugs/<slug>` and assert the run reads the bug dir's test
  list and writes its journal/receipts/cycle log **under the bug dir**, and that
  exit ≠ 2.
- Pin test: `feature_directory: .specify/bugs/<slug>` in a temp
  `.specify/feature.json`, run with the bare slug and no positional, assert the
  pin is honored; plus a malformed-pin refusal case.
- Resolver unit tests for the pin fallback and for
  `ResolvedFeatureDir.name` = basename on path references (extends the existing
  `TddFeaturePaths` unit group in the #1182 test).
- Doctor/verify path-form tests mirroring
  `test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart`.
- Regression guard: existing tests that pin plain-name semantics and the
  `specs/<feature>` message — `test/plugins/tdd/run_command_path_format_test.dart`,
  `test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart`, and the
  `RunDriverCore` tests that pass `projectRoot` + `feature` — must stay green
  (the plain-name resolution must remain byte-identical).

## Risks & Considerations

- **Contract stability**: `validateFeatureSegment`'s refusal message and exit 2
  are a documented surface (`run_command_path_format_test.dart`,
  `bug_1397_path_form_mismatch_test.dart`). Relaxing the positional check must
  keep that message for undeclared shapes.
- **Layout blast radius**: `drive`, the transaction, cycle-log and lane receipts
  all move for bug features. Artifacts landing beside the resolved spec (not
  under a fabricated `specs/`) is the #1182 precedent and should be asserted
  explicitly, not assumed.
- **Project-root derivation** (`run_driver_core.dart:2104`) is the subtle one: a
  wrong root silently degrades the hand-step violation message to a guessed
  test path instead of failing. Needs its own test.
- **No API breakage** for plain features is the acceptance bar; anything else is
  a regression the fast suite should catch.
- **Scope**: `make`/`gen`/`compose`/`refactor`/`verify-red`/`fake`/`spec-fuzz`/
  `status`/`prove` carry their own local `_validateFeatureSegment` copies. This
  assessment and its fix stay on the reported family (run, run-engine, run-skin,
  doctor, verify); the rest should be tracked as a follow-up rather than bundled
  into this fix.
- No migrations, no performance or security exposure — this is CLI path
  resolution.

## Open Questions

- `[NEEDS CLARIFICATION: should `run` accept the positional path forms only, or
  also the `feature.json` pin with a bare slug? The issue's "Expected" asks for
  both; the pin half is new capability. Recommend both, since `bug.fix` pins the
  file and passes the bare slug.]`
- `[NEEDS CLARIFICATION: when the pin resolves to a directory with no
  `spec.md`/`tdd/test-list.md`, should the command refuse with the resolved path
  in the message (plan's precedent) or fall back to `specs/<slug>`? Recommend
  refuse with the resolved path.]`
- `[NEEDS CLARIFICATION: is the `--feature` flag on `verify` also expected to
  accept a path, or only the pin? The issue names verify only via its
  `specs/$feature` assumption.]`
