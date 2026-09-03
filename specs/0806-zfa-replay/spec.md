# Feature Specification: `zfa replay` — path-stable replay of recorded TDD history (issue #806, Done-when completion)

**Feature Branch**: `spec/0806-zfa-replay`

**Created**: 2026-09-03

**Status**: Draft

**Input**: Issue [#806](https://github.com/arrrrny/zuraffa/issues/806) — "[VISION] ⏪ `zfa replay`: deterministically re-execute any feature's TDD history". Part of 🧭 VISION 2030 (#804), Pillar A: Proof-carrying generation. The v0 core (integrity → gen compare → verify, NDJSON events, #778 exit codes, both command surfaces) landed via spec 066-zfa-replay. This spec closes the gap between that core and the issue's literal Done-when pair.

## Mission

The v0 replay core is honest but **same-machine only**: spec 066 explicitly scoped out "cross-machine bit-identical artifact guarantees". Every real recorded history, however, is full of machine-absolute paths — the cycle-log's `- test:` fields, the recorded green commands, and the green entries' generation steps all embed the recording machine's project root (`<root>/./<rel>`, the form `artifacts.json` and the runner template render), its dart binary, and its zfa checkout. Replay that history on any other machine — including a fresh clone at the standard location — and the run diverges before it starts: `red-missing-test-artifact` on paths that never exist locally, unspawnable `<recorded-dart> <recorded-zfa>` entrypoints, and sandbox registry records that point outside the sandbox so `tdd wire`/`tdd func` refuse to run.

The literal acceptance fixture proves it: `examples/todo_tdd` (the todo example, 27 machine-format entries recorded on a different agent box) currently replays `result=divergent replayed=0 skipped=1 diverged=9`, exit 1 — every behavior failing integrity on the other machine's absolute test paths. Issue #806's Done-when — "Replaying the todo example's full recorded history passes clean" — is unmet.

This spec makes replay **path-stable**: the recorded root is detected from the canonical `/./` anchor marker, re-anchored into the replay machine's project (integrity) and sandbox (command execution, registry), the recorded entrypoint pair re-resolved to the running dart / `--zfa-bin`, and the two generation commands that break fixed-point convergence (`entity create` clobbering an existing entity, `tdd func` refusing on an implemented subject because its stale doc comment still mentions `UnimplementedError`) made convergent — re-running a recorded gen step against the tree it already produced is a no-op with exit 0. Then the todo example's full recorded history replays clean on a fresh clone, and an injected mutation into any replayed step is still caught with the step named.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A history recorded on another machine replays clean here (Priority: P1)

A reviewer (or a fresh stateless agent) clones the repo and replays a feature whose cycle-log was recorded on a different machine: `- test:` fields read `/home/agent-box/workspace/todo_tdd/./test/tdd/a1_test.dart`, green commands embed the same absolute root, and generation steps read `<that-box's dart> <that-box's zuraffa checkout>/bin/zfa.dart tdd wire A1 --entity Todo`. Replay detects the recorded root from the `/./` marker, re-anchors the red-artifact existence check into the local project, strips the recorded root from executed commands so they run sandbox-relative, rewrites the sandbox's copied `artifacts.json` registry into the sandbox, and re-resolves the entrypoint pair to the locally running dart (or `--zfa-bin` when given). The recorded loop reproduces: `result=clean`, exit 0.

**Why this priority**: the issue's Done-when — "Replaying the todo example's full recorded history passes clean" — is false today for exactly this reason, and "agents are stateless — replay is how they regain context after a crash or handoff" only works if replay survives the handoff to a new machine.

**Independent Test**: A fixture whose cycle-log is seeded through the real `CycleLog.append` writer with absolute `<other-root>/./…` test paths and `<other-dart> <other-zfa>` generation steps (the todo example's recorded shape, on a scripted fake zfa): full-history replay exits 0 with `result=clean`, and the executed commands resolve inside the sandbox (no recorded root leaks into spawns).

### User Story 2 - Same-machine replay is unchanged (Priority: P1)

A history recorded on THIS machine (locally-resolvable paths, as every 066 fixture and same-box replay already is) replays exactly as before: no re-anchoring fires (recorded paths exist locally; no `/./` anchor detected means no command rewriting), `--zfa-bin` still substitutes bare `zfa` prefixes, and the 066 regression surface (37 fast-tier behaviors + SC-022) stays green byte-for-byte.

**Why this priority**: re-anchoring must be additive — the #778/#791 contracts and the 066 catch teeth (chain mismatch, drift paths, verify exits) are already proven; they must not regress.

**Independent Test**: the full 066 replay suite (replay_history/replay_sandbox/replay_runner/replay_command + SC-022) passes unmodified.

### User Scenarios 3/4 - The two Done-when criteria, literally (Priority: P1)

1. `zfa replay examples/todo_tdd/specs/001-todo-app/tdd/cycle-log.md` on a fresh clone: every recorded behavior's integrity verifies (test paths re-anchored, schema-0 entries warned-not-failed), every gen step re-runs convergently (entity create skips the existing entity; wire no-ops already-wired; func no-ops already-implemented; build regenerates byte-identical `.g.dart`/`.zorphy.dart`), every recorded green command re-runs green inside the sandbox — `replay: feature=001-todo-app result=clean replayed=9 skipped=1 diverged=0`, exit 0 (the skipped behavior is the refactor pseudo-behavior: refactors are recorded, never re-executed — FR-012 unchanged).
2. An injected mutation into any replayed step is caught with the step named — the 066 contract, now also over re-anchored paths: a drifted generation produces `gen -> drift (N paths: … modified)` naming project-relative paths; a history tamper still names the broken chain link; a verify break still names expected/actual exits.

**Independent Test**: the SC-023 scenario (this spec): the todo-shaped fixture replays clean, then a drift-config mutation flips it to `result=divergent` exit 1 with the path named; the live todo-example run and its mutation check are recorded as delivery evidence in `tdd/verification.md`.

### Edge Cases

- **No `/./` anchor in the history** (all paths relative or locally absolute): `detectRecordedRoot` returns null — no re-anchoring, no command rewriting; behavior identical to 066.
- **Inconsistent recorded roots** (two different `<root>/./` prefixes): no re-anchoring (defensive null); commands run as recorded — divergence names itself honestly rather than guessing.
- **Recorded entrypoint exists locally** (same-machine replay without `--zfa-bin`): the recorded pair runs as recorded — determinism preserved.
- **Recorded entrypoint broken locally AND no `--zfa-bin` AND the replay CLI is not running from source**: re-anchoring cannot resolve a zfa entrypoint — the step fails as `runner-error` (exit 1), never a silent pass.
- **Recorded root equals the local project root**: stripping still yields sandbox-relative paths — strictly more correct than 066 (which would spawn absolute paths into the real project, a sandbox escape).
- **Red test path exists locally AND is re-anchorable**: local existence wins (same-machine bit-exactness first); re-anchoring is only a fallback for missing paths.
- **The registry re-anchor rewrites every `<root>/./` occurrence in the feature's `tdd/*.json`** — `test_path`, `subject_path`, `runnable_test_name` — into `<sandbox>/./`; a registry with no anchor prefix is copied verbatim.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001 (recorded-root detection)**: Replay MUST derive the recorded project root from the history's `- test:` values: the `<root>/./<rel>` anchor form. All anchors MUST agree on one root; zero anchors or conflicting roots MUST disable re-anchoring entirely (null root, 066 behavior). The detection result MUST NOT appear in any report line (path-stable output, FR-009 of 066 unchanged).
- **FR-002 (integrity re-anchor)**: The red structural check's test-path existence resolution MUST fall back to re-anchoring: a recorded absolute path that does not exist locally, whose `<root>/./` prefix matches the detected root, resolves against the local project root. A path that still does not resolve remains a `red-missing-test-artifact: <recorded-path>` divergence (message unchanged — the recorded path is the fact).
- **FR-003 (command path re-anchor)**: When a root is detected, every recorded command re-executed in the sandbox (gen steps and green verify commands) MUST have every `<root>/./<rel>` occurrence rewritten to the sandbox-relative `<rel>` (cwd = sandbox). The recorded root MUST NOT survive into any spawned process argument.
- **FR-004 (entrypoint re-anchor)**: A recorded gen step's leading entrypoint pair MUST re-resolve when locally broken: (a) an explicit `--zfa-bin` replaces any zfa entrypoint form — bare `zfa` (066 contract, unchanged) or `<dart> <zfa.dart>` (drop both tokens, keep args); (b) without `--zfa-bin`, a locally-missing recorded dart binary re-resolves to the running dart and a locally-missing zfa script re-resolves to the running CLI's entrypoint; (c) a fully resolvable recorded pair runs as recorded. Unresolvable remains `runner-error`, exit 1.
- **FR-005 (sandbox registry re-anchor + build contracts)**: `ReplaySandbox` MUST rewrite `<root>/./` → `<sandbox>/./` in every `*.json` under the copied `specs/<feature>/tdd/` when a root is detected, and MUST additionally copy `build.yaml` and `dart_test.yaml` from the project root when present (the contracts recorded `zfa build` / `dart test` commands read — FR-006's own seeding rule, applied to the contracts 066 missed).
- **FR-006 (convergent generation)**: `zfa entity create` MUST be a fixed point: when the target entity file (`<outputDir>/<snake>/<snake>.dart>`, the zorphy `EntityCreator` path contract) already exists, the command prints the convergent skip and exits 0 without writing. `zfa tdd func` MUST treat a subject with no actual `throw UnimplementedError(` as already-implemented (exit 0) — the stale generated doc comment that merely *mentions* `UnimplementedError` MUST NOT trip the refusal; a genuine unrecognized throw still refuses with exit 1 (runner-error).
- **FR-007 (contracts preserved)**: All 066 contracts MUST hold unchanged: exit codes (0/1/2/64), the final `replay:` summary line, the NDJSON event vocabulary (re-anchored runs emit the same event shapes), the read-only contract, sandbox deletion, FR-004's tampered-commands-never-execute, and FR-012's refactors-recorded-never-re-executed.

### Key Entities

- `ReplayPaths` (new service) — recorded-root detection (`detectRecordedRoot`), test-path re-anchoring (`reAnchorTestPath`), command stripping (`reAnchorCommand`), entrypoint re-resolution (`reAnchorEntrypoint`). Pure functions; injectable platform facts for tests.
- `ReplaySandbox` (extended) — registry rewriting + `build.yaml`/`dart_test.yaml` seeding.
- `ReplayHistory.verifyIntegrity` (extended) — re-anchored red-path resolution via `recordedRoot`.
- `ReplayRunner` (extended) — threads the detected root through gen/verify; entrypoint seams (`resolvedDart`, `runningScript`) defaulting to the platform facts.
- `EntityCommand` / `FuncCommand` (convergent fixed-point fixes).

## Success Criteria *(mandatory)*

- **SC1**: A todo-shaped fixture (recorded root ≠ local root, absolute entrypoints, registry with anchored paths) full-history replays clean: exit 0, `result=clean`, gen steps identical, verify green, executed commands contain no recorded-root prefix.
- **SC2**: The same fixture with an injected generation mutation reports `result=divergent` exit 1 with the project-relative path named (066 catch contract over re-anchored history).
- **SC3**: The 066 suite (37 fast + 5 SC-022) passes unmodified — same-machine replay byte-identical.
- **SC4**: The LIVE todo example: `zfa replay examples/todo_tdd/specs/001-todo-app/tdd/cycle-log.md` exits 0 with `result=clean replayed=9 skipped=1 diverged=0`, and a live injected mutation (hand-edit of a generated artifact before replay) is caught as gen drift naming the path — recorded in `tdd/verification.md` from this run.
- **SC5**: `entity create` on an existing entity exits 0 without touching the file's bytes; `tdd func` on an implemented subject (stale doc comment) exits 0 `already-implemented`; a genuine unrecognized throw still exits 1.
- **SC6**: `dart analyze` shows zero new issues vs the pre-feature baseline; `dart format .` leaves zero diff; the chunked runner shows no new failures in any touched chunk.

## Out of Scope

- Red reproduction (pre-make state snapshots) — still out, per 066.
- Refactor re-execution — still out (FR-012); the todo example's `001-todo-app-refactor` behavior honestly reports skipped.
- Timestamp masking in the tree compare — NOT adopted: convergent generation (FR-006) makes regenerated trees byte-identical without masking; masking would weaken the bit-identical contract. A `// Generated at:` line only changes when a file is regenerated from a clobbered state, which FR-006 prevents.
- The `example/` Flutter app (specs/031, narrative log) — still the zero-parseable-entries edge case (exit 2).
- MCP streaming wiring — still #791's surface.

## Assumptions

- The `<root>/./<rel>` form is the canonical recorded-path shape (written by `artifacts.json`'s `test_path`/`subject_path`/`runnable_test_name` and the runner's substituted display commands); histories without it need no re-anchoring.
- The replay CLI runs from source (`dart bin/zfa.dart …`) in delivery; the entrypoint seam defaults cover it, and an unresolvable case fails loudly (runner-error).
- The todo example's pub-cache dependencies resolve identically on the replay machine (standard pub cache layout).
