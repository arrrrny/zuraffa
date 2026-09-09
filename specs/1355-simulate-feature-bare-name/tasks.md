# Tasks — Spec 1355 simulate --feature bare-name resolves under specs/

Dependency-ordered, MVP first. Behavior tests are written and proven RED
before the implementation lands.

## Phase A — legacy replay resolution (MVP)

- [x] T001. [behavior: B1] CLI: bare-name `--feature <f>` after
      `--scaffold specs/<f>` replays GREEN from `specs/<f>/tdd/fixtures/`
      (exit 0) — the issue's exact repro. Traces FR-1, SC-001, AS-1.
- [x] T002. [behavior: B2, B4] CLI: path form `--feature specs/<f>` stays
      GREEN (regression guard); `--fixtures <dir>` outside specs/ is used
      verbatim (no specs/ resolution). Traces FR-2, AS-2, AS-4.
- [x] T003. [behavior: B3] CLI: bare name without a specs dir exits 1 RED
      naming the raw value (honest miss, pre-fix behavior preserved).
      Traces FR-3, AS-3.
- [x] T004. [behavior: B5] Help: the parent `--feature` help documents the
      bare-name rule (help output contains the bare-name wording).
      Traces FR-4.

## Phase B — implementation + hardening

- [x] T005. Implement the bare-name specs/ resolution in the legacy branch
      (only when `--fixtures` is absent and the specs dir exists) + help
      text (turns B1–B5 GREEN). Traces FR-1..FR-4.
- [x] T006. Regression pin: the simulate suites stay green — scoped files
      only (worlds command file, simulate command file, skin command
      file, worlds unit tests). Traces SC-002.
- [x] T007. `dart analyze` clean on touched files; `dart format` zero
      diffs.

## Dependencies

- T001–T004 are the behavior list; T005 is the single green-step change;
  T006–T007 harden after green.
