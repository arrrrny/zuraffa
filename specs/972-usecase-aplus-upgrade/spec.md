# Spec 972 — usecase A+ upgrade: honest grammar, --json verdicts, receipts, close #921, drop toggle default

Issue: #972 (closes)

## Problem

Four dishonest behaviors in the usecase plugin's CLI surface:

1. **Silent no-op grammar** — bare `zfa usecase` printed
   `❌ Usage: zfa usecase <EntityName> [options]` (an unreachable
   positional grammar, per bug #856's analysis) and exited **0**. No
   `exitCode` was set, so automation read a usage error as success.
2. **No machine verdicts** — `zfa usecase create` printed human-only
   text; `--json` (as declared on the auto-registered capability
   subcommand) was an *input* option that a bare flag invocation could
   not even parse.
3. **No receipts** — usecase generation shipped no proof; `zfa proof
   check` could not verify a single usecase artifact's provenance.
4. **#921 fail-open hole** — `SourceInterfaceGuard` returns the
   requested method set unchanged when the source interface file is
   absent. In a same-plan run (service plugin runs *after* the usecase
   plugin; repository muted by `--use-service`) the generated usecases
   call methods nobody declared and the project cannot compile — the
   failure surfaces later, in `zfa build`, with no hint why.
5. **Silent toggle default** — `usecase_plugin.dart:119` defaulted
   every entity to `['get','update','toggle']`; entities with no toggle
   semantics got a `ToggleXUseCase` calling a method that does not
   exist (#921's original misfire).

## Requirements

- FR-1: bare `zfa usecase` reports the subcommand grammar and exits 64
  (mirror `repository_command.dart:42-49`); the dead positional body
  (old `run()` lines 67-123) is deleted.
- FR-2: `zfa usecase create <E> --json` prints only a per-method
  verdict envelope `{schema: 1, methods: [{name, action:
  created|appended|skipped, reason}]}`.
- FR-3: every successful create run ships a receipt at
  `.zfa/receipts/usecase-<entity>.json` recording requested vs
  generated vs skipped methods + guard reason codes, digest-bound
  (schema `proof.v1`); `zfa proof check` verifies it.
- FR-4: when the interface is absent (same-plan case) the guard records
  the requested method set as an expectation in the plan; a `zfa make`
  post-pass verifies the responsible plugin (repository/service)
  declared them; mismatch → exit 1 +
  `--> fix: zfa repository create <E> --methods=...`.
- FR-5: toggle leaves the silent default vocabulary — generated only
  when explicit in `--methods` or evidenced on the interface.
- FR-6: tests (failing-first) under `test/plugins/usecase/` —
  expectation post-pass (positive + negative), revert path,
  stream-append.

## Constraints

- Do not touch generator emission semantics beyond the toggle default.
- Validation: `dart analyze` (touched files) +
  `dart test test/plugins/usecase/`.

## Acceptance criteria

- AC-1: bare `zfa usecase` exits 64 with usage (regression test).
- AC-2: `--json` envelope asserted by test; receipt written and
  proof-checkable.
- AC-3: same-plan misfire (repository without declared methods) FAILS
  the make run with the `--> fix:` line — tested both ways.
- AC-4: no entity gets toggle without explicit request — tested.
