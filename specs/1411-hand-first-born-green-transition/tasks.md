# Tasks — Spec 1411 hand-first born-green transition

MVP-first: the transition itself (B1) is the smallest shippable slice;
the messaging and compatibility pins follow.

- [ ] T001. [behavior: B1] make `--born-green` full gate → exit 0,
  `outcome=born-green`, green evidence in the existing format. Traces
  FR-1/AS-1/SC-001.
- [ ] T002. [behavior: B2] No flag + attested shape → the refusal OFFERS
  the exact `--born-green` command. Traces FR-2/SC-002.
- [ ] T003. [behavior: B3] Flag + marker present → `vacuous-green`
  safe-failure naming the completion remedy. Traces FR-3.
- [ ] T004. [behavior: B4] Flag + header absent → `not-certified-red`
  naming the exact header line. Traces FR-3.
- [ ] T005. [behavior: B5] Flag + failing test → `not-certified-red`
  naming `verify-red` (honest red-first remedy). Traces FR-3/SC-001.
- [ ] T006. [behavior: B6] Certified red + flag → the #694 skip
  transition stands (flag inert; backward compat). Traces FR-5/AS-3.
- [ ] T006b. [behavior: B7] Flag + passing test against a placeholder
  subject → `vacuous-green` refusal (the #1036 class). Traces FR-3/SC-001.
- [ ] T007. [behavior: D1] Driver: attested catch-22 → hand-off naming
  `--born-green`, `stopped_at=<id>:hand`, journal violation. Traces
  FR-4/AS-2/SC-002.
- [ ] T008. [behavior: D2] Driver: un-attested → the exact header line
  is named in the hand-off. Traces FR-4.
- [ ] T009. [behavior: D3] Driver: red-first-shaped refusal → the
  generic stop stands (no hand-off). Traces FR-5/AS-3.
- [ ] T010. Implement: born_green.dart service; make flag + offer +
  transition block; `born-green` outcome token; step-contract grading;
  driver arm + journal vocabulary. Traces FR-1..FR-5.
- [ ] T011. Regression pin: #1308 remedy driver, #1373 hand-off driver,
  make-command, verify-red suites stay green. Traces SC-003.
