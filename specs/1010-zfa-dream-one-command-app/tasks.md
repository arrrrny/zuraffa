# Tasks: 1010-zfa-dream-one-command-app — `zfa dream`, the one-command app

> Test-first. Every task below is driven red → green per the tdd extension;
> evidence lands in `tdd/cycle-log.md` and `tdd/verification.md` from the
> REAL runs. Branch: `spec/1010-zfa-dream-one-command-app`.

## 1. Unit behaviors

- [x] T001. U1 `zfa tdd ingest` accepts a schema-valid draft: writes
      `specs/<feature>/spec.md`, exit 0, summary line
      `ingest: feature=… result=accepted entities=… dependencies=… contracts=…`.
      RED: command does not exist (usage error).
- [x] T002. U2 ingest refuses on the plan-gate classes: template-version
      drift exit 3; coverage gap / undeclared dependency / declaration
      refusal exit 2 with `--> fix:` lines (same parser verdicts as plan).
- [x] T003. U3 ingest entity-collision gates: intra-draft duplicate
      entity names, framework-export collision (`Credentials`), contract
      ambiguity (interface under two layers, empty Contract cell) → exit 2
      `--> fix: rename the entity` (bug #942 language).
- [x] T004. U4 ingest refuses to overwrite an existing `spec.md` without
      `--force`; `--force` replaces it.
- [x] T005. U5 v2 tool: `dream_draft_spec` is listed by
      `v2ToolDefinitions()` (12 tools) with a valid input schema; dispatch
      through `handleV2ToolCall` returns `{specMarkdown, planMarkdown,
      drafter}`.
- [x] T006. U6 the deterministic drafter (no LLM configured) emits a spec
      the REAL `zfa tdd plan` accepts (exit 0) — schema-constrained draft.
- [x] T007. U7 the LLM path: a fake `LlmClient` returning labeled fenced
      blocks is used verbatim (`drafter=llm`); an empty completion falls
      back to the deterministic drafter (labeled, never a silent pass).
- [x] T008. U8 feedback repair: the deterministic drafter applies the
      ingest `--> fix: rename the entity` suggestion (colliding name →
      `<Name>Entity`) on the next attempt.

## 2. Acceptance behaviors

- [x] T009. A1 (SC1) — full happy path over a sandbox fixture with a fake
      LLM and a spawner delegating ingest/plan to the REAL in-process
      commands: exit 0; spec + 3 plan files + draft + 2 receipts on disk;
      PR argv recorded without `--draft` (engine green); summary line
      `dream: feature=… result=complete …`.
- [x] T010. A2 (SC2) — first draft collides (`Credentials`): ingest exit 2
      refusal reaches the LLM's second prompt; renamed second draft
      accepted; attempts=2 in the summary.
- [x] T011. A3 (SC4) — `scaffolded` view outcome → `git checkout -b
      skin/<feature>` argv + skin receipt with hand-edit pending;
      non-green engine → PR argv carries `--draft` and dream exits 1.
- [x] T012. A4 — `zfa dream` is a top-level command (RED: "Could not find
      a command named dream"); `--json` emits the verdict.v1 envelope;
      `--no-pr` skips the git/gh phase.

## 3. Delivery

- [x] T013. LIVE demo run recorded in `tdd/verification.md`
      (deterministic drafter, real ingest/plan; engine/skin steps driven
      by the fixture's fake zfa — labeled honestly).
- [x] T014. Gates — `dart analyze` (zero new vs baseline), `dart format
      lib test` (zero diff), chunked fast suite green.
- [ ] T015. `/speckit.tdd.verify` dispatch (`zfa tdd verify --feature
      1010-zfa-dream-one-command-app`) + `tdd/verification.md` written
      from the REAL run; tasks ticked; commit + PR.
