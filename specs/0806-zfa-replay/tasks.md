# Tasks: 0806-zfa-replay — path-stable replay of recorded TDD history

> Test-first. Every task below is driven red → green → refactor per the tdd
> extension; evidence lands in `tdd/cycle-log.md` through the real
> `CycleLog.append` writer. Branch: `spec/0806-zfa-replay`.

## 1. Unit behaviors

- [x] T001. U1 `ReplayPaths.detectRecordedRoot` — single consistent
      `<root>/./` anchor detected; none / conflicting → null.
      RED: `test/plugins/tdd/services/replay_paths_test.dart` fails
      (service does not exist — load error).
- [x] T002. U2 integrity re-anchor — a recorded-elsewhere red test path
      resolves against the local project root
      (`ReplayHistory.verifyIntegrity` with `recordedRoot`); an unresolvable
      path still reports `red-missing-test-artifact: <recorded-path>`.
- [x] T003. U3 entrypoint re-anchor — `<abs-dart> <abs-zfa.dart> args`:
      `--zfa-bin` precedence (drop the pair), locally-missing dart → running
      dart, locally-missing zfa → running entrypoint, resolvable pair →
      unchanged; unresolvable → runner-error.
- [x] T004. U4 command path re-anchor — every `<root>/./<rel>` occurrence in
      recorded gen/verify commands is stripped to sandbox-relative before
      spawn (no recorded root survives into a process argument).
- [x] T005. U5 sandbox re-anchor — `ReplaySandbox.create` rewrites
      `<root>/./` → `<sandbox>/./` in `specs/<feature>/tdd/*.json` and seeds
      `build.yaml` / `dart_test.yaml` when present.
- [x] T006. U6 convergent `entity create` — existing target entity file →
      exit 0, bytes untouched.
- [x] T007. U7 convergent `tdd func` — implemented subject (stale doc
      comment mentioning `UnimplementedError`) → exit 0
      `already-implemented`; genuine unrecognized throw → exit 1.

## 2. Acceptance behaviors

- [x] T008. A1 (SC1) — todo-shaped fixture (recorded root ≠ local, absolute
      entrypoints, anchored registry) full-history replay: exit 0
      `result=clean`, no recorded root in spawns.
- [x] T009. A2 (SC2) — the same fixture + injected generation mutation:
      exit 1 `result=divergent`, path named.
- [x] T010. A3 (SC3) — the 066 suite passes unmodified (same-machine
      contract).

## 3. Delivery

- [x] T011. LIVE SC4 — run `zfa replay
      examples/todo_tdd/specs/001-todo-app/tdd/cycle-log.md` (exit 0,
      clean) and the live mutation catch; record both outputs in
      `tdd/verification.md`.
- [x] T012. Gates — `dart analyze` (zero new vs baseline), `dart format .`
      (zero diff), chunked runner over every touched chunk.
- [x] T013. `/speckit.tdd.verify` dispatch (`zfa tdd verify --feature
      0806-zfa-replay`) + `tdd/verification.md` written fresh from the real
      runs; tasks ticked; commit + PR.
