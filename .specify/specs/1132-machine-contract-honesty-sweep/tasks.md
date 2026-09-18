# Tasks: 1132-machine-contract-honesty-sweep

- **Spec ID**: 1132-machine-contract-honesty-sweep
- **Created**: 2026-09-17
- **Plan**: [plan.md](./plan.md)

## Lane 0 — SDD scaffolding (this session)

- [x] T1.1 Audit master: subprocess fleet sweep (59 commands), dynamic
      receipts audit (25 generation verbs), envelope probes, openwiki
      regeneration attempt — evidence in `tdd/verification.md`.
- [x] T1.2 Write `spec.md` / `plan.md` / `tasks.md` (this directory).
- [x] T1.3 Write `tdd/test-list.md`; RED evidence from real runs.

## Lane 1 — exit-code sweep (FR-1, SC-1)

- [x] T2.1 RED: `test/commands/exit_code_sweep_1132_test.dart` — bare
      `cli|benchmark|bone|config|migrate|plugin` exit 2 + usage; `--help`
      exits 0; unknown subcommands exit 2; config's hard-exit removal
      (in-process runCapturing returns).
- [x] T2.2 GREEN: patch the six commands per plan (usage arms;
      ExitProtocol.usage; no hard exit()).
- [x] T2.3 Subprocess pins in the regression tier
      (`test/regression/issue_1132_bare_exit_code_fleet_test.dart`).

## Lane 2 — verdict envelope unification (FR-2, SC-2)

- [x] T3.1 RED: `test/commands/verdict_envelope_1132_test.dart` — the four
      machine-mode surfaces parse via `VerdictEnvelope.fromJson` with the
      real verdict/exit_class.
- [x] T3.2 GREEN: emit the canonical envelope (payload in `details`,
      findings carry fixes); text modes unchanged.
- [x] T3.3 Remove the three entries from the emitter-scan `kExcluded`;
      scan stays green.

## Lane 3 — receipts on standalone invocations (FR-3, SC-3)

- [x] T4.1 RED: `test/commands/standalone_receipts_1132_test.dart` —
      `zfa app shell` / `zfa skin kit` leave proof.v1 receipts covering
      the written artifacts (digests match disk; skipped runs ship none).
- [x] T4.2 GREEN: receipt writes after artifact flush (best-effort,
      success-only).

## Lane 4 — openwiki fleet docs (FR-4, SC-4)

- [x] T5.1 RED: `test/commands/openwiki_cli_docs_1132_test.dart` — the
      parser handles wrapped descriptions (fixture help text with
      continuation lines); committed cli.md covers the live command set.
- [x] T5.2 GREEN: fix the parser (pure function, shared by the tool),
      regenerate `docs/openwiki/cli.md`.
- [x] T5.3 Drift-guard regression test
      (`test/regression/openwiki_cli_docs_fleet_test.dart`).

## Lane 6 — verification + delivery

- [x] T6.1 `dart analyze` (changed files, zero new findings) + `dart
      format lib test` (zero drift).
- [x] T6.2 Fast tier: `dart test` (or chunked) — all green.
- [x] T6.3 Regression tier: `dart test --preset=regression
      test/regression/` — green; plain `flutter test test/regression/`
      documented as the #1382 false-green (not trusted as the criterion).
- [x] T6.4 Fleet sweep re-run: zero lying-success commands (SC-1).
- [x] T6.5 Receipts demo on a zik_zak-style fixture: generation paths →
      receipts → `zfa proof check <coverageRoots>` clean for those paths.
- [x] T6.6 `tdd/verification.md` written from the real runs above.
- [ ] T6.7 Conventional commits per lane, push, PR (closes #1132 when the
      exit criteria pass).
