# Test List: 1010-zfa-dream-one-command-app

Format: `[status] BEHAVIOR-ID — one-line behavior (traces to SC/FR)`.
Statuses: PENDING → RED → GREEN → DONE. Tier: fast (unit) / integration (scenario).

## Outer acceptance behaviors (drive the CLI surface end-to-end)

- [DONE] A1 [fast] `zfa dream "<description>"` over a sandbox fixture
  (fake LLM, spawner delegating ingest/plan to the REAL commands): exit 0;
  spec + plan.md + tdd/test-list.md + tdd/traceability.md + tdd/draft-spec.md
  on disk; exactly 2 dream receipts in .zfa/receipts/; PR argv recorded
  without --draft (engine green); summary `dream: feature=… result=complete
  drafter=llm attempts=1 engine=green skin=… pr=…`. (SC1, FR-001..FR-008; US1)
- [DONE] A2 [fast] A colliding first draft (`Credentials`, a real
  framework export) is refused by the real ingest command (exit 2, `--> fix:
  rename`); the refusal text reaches the LLM's second prompt; the renamed
  second draft is accepted; attempts=2. (SC2, FR-002/FR-003; US2)
- [DONE] A3 [fast] A `scaffolded` view outcome records the `git checkout -b
  skin/<feature>` argv and a skin receipt with the hand-edit pending; a
  non-green engine opens the PR with `--draft` and dream exits 1. (SC4,
  FR-005/FR-006/FR-008; US4)

## Inner unit behaviors (one proven fact each)

- [DONE] U1 [fast] `zfa tdd ingest <feature> --draft <path>` accepts a
  schema-valid draft: writes specs/<feature>/spec.md, exit 0, summary
  `ingest: feature=<f> result=accepted entities=<n> dependencies=<n>
  contracts=<n>`. (FR-002)
- [DONE] U2 [fast] ingest refuses on the plan-gate classes with the same
  parser verdicts as `zfa tdd plan`: template-version drift exit 3; coverage
  gap / undeclared dependency / declaration refusal exit 2 with `--> fix:`
  lines, and no spec.md is written. (FR-002)
- [DONE] U3 [fast] ingest entity/contract gates: intra-draft duplicate
  entity names, framework-export collision (Credentials), interface under
  two layers, empty Contract cell → exit 2 with `--> fix: rename the entity`
  (bug #942 language). (FR-002)
- [DONE] U4 [fast] ingest refuses to overwrite an existing spec.md
  without --force; --force replaces it. (FR-002)
- [DONE] U5 [fast] `dream_draft_spec` is listed by v2ToolDefinitions()
  (12 tools) with a valid input schema; handleV2ToolCall dispatch returns
  {specMarkdown, planMarkdown, drafter}. (FR-010)
- [DONE] U6 [fast] The deterministic drafter (no LLM configured) emits a
  spec the REAL `zfa tdd plan` accepts (exit 0). (FR-001/FR-010; US3)
- [DONE] U7 [fast] The LLM path: a fake LlmClient returning labeled
  fenced blocks is used verbatim (drafter=llm); an empty completion falls
  back to the deterministic drafter, labeled. (FR-010)
- [DONE] U8 [fast] Feedback repair: the deterministic drafter applies
  the ingest `--> fix: rename the entity` suggestion (colliding name →
  <Name>Entity). (FR-003)
- [DONE] U9 [fast] `zfa dream` is a registered top-level command (RED
  today: "Could not find a command named dream"); --json emits the
  verdict.v1 envelope; --no-pr skips the git/gh phase. (FR-009/FR-008)

## Live delivery evidence (not a dart test; recorded in verification.md)

- [DONE] L1 LIVE demo: `zfa dream "A page that lists the user's favorite
  deals, sorted by expiration"` on a scratch project (deterministic
  drafter; real ingest + plan; engine/skin steps via the fixture's fake
  zfa, labeled honestly) — artifacts + receipts + PR argv recorded. (SC1)
