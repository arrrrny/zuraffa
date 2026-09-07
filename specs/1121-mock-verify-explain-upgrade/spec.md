# SPEC 1121 — [A+ UPGRADE] mock: add `zfa mock verify` command and flesh out explain capability

## Summary

The mock plugin has `--certify` (generation + certification in one shot, spec 970/1001) but no
`zfa mock verify <Entity>` to re-prove existing mocks after entity drift. `MockExplainCapability`
does not exist on this branch at all (the A+ brief calls it a stub — there is nothing to flesh
out, so this spec creates it whole). This is the gap keeping mock at B+.

Two new surfaces close the gap:

1. **`zfa mock verify <Entity>`** — read-only re-certification: re-runs the certification gate
   against the mock files already on disk and the current entity source. Exit 0 when the mock
   conforms; exit 1 with `--> fix:` lines when drift is detected; exit 2 on usage errors.
   `--json` emits the canonical `zuraffa.verdict.v1` envelope (issue #1105).
2. **`zfa mock explain <Entity>`** (`MockExplainCapability`) — for the entity's mock artifacts,
   reports: which entity methods the mock covers, which interface methods it skips, the
   certification status per method (from the committed `mock-cert.<Entity>.json` receipt,
   spec 1001), and the per-method fixture selector (`MockData.forMethod`, issue #1034) bindings.

## Motivation

- `zfa mock create <Entity> --certify` proves conformance at generation time, but nothing
  re-proves it later: an entity edit (add/rename/remove a datasource method) silently drifts the
  committed mock. The agent's only recovery is regenerating — a destructive act — when what it
  needs first is an honest read-only verdict.
- Every other A+ surface speaks `zuraffa.verdict.v1` under `--json` (issue #1105; service
  verify landed the pattern in spec 1127). Mock verify must speak the same envelope so one
  parser covers the fleet.
- A mock's consumer (human or agent) cannot currently ask "what does this mock actually cover,
  what does it skip, is it certified, and does it bind per-method fixtures?" without reading
  generated Dart by hand.

## Success criteria (measurable)

- **AC-1** `zfa mock verify <Entity>` exits **0** on a conforming on-disk mock and prints a
  conformance line naming the interface class and the certification registry id.
- **AC-2** `zfa mock verify <Entity>` exits **1** and prints at least one `--> fix:` line naming
  the drifted member(s) and the interface class when the mock is missing a member the current
  entity interface declares, invents a member the interface does not declare, or fails the
  scoped `dart analyze`.
- **AC-3** `zfa mock verify <Entity>` exits **1** with a `missing_file` finding and a
  `--> fix:` line naming `zfa mock create <Entity> --certify` when no mock exists on disk.
- **AC-4** `zfa mock verify <Entity> --json` emits exactly one canonical envelope as the last
  stdout line: `schema == "zuraffa.verdict.v1"`, `verdict ∈ {pass, fail}`, `exit_class ∈ {0,1}`,
  `subject == {kind: "mock", id: <Entity>}`, structured `findings` (kind/member/file/fix), and
  `drifts` carrying the fix lines. Diagnostics go to stderr.
- **AC-5** `zfa mock verify <Entity>` (no flags) is read-only: it creates, modifies, and deletes
  nothing under the target project (no generation, no receipt write, no registry write) —
  verify is NOT a duplicate of MockCertify.
- **AC-6** `zfa mock explain <Entity>` prints, for the entity's mock: the mock/interface file
  paths and class names; per-method coverage with certification status (`certified`,
  `certified-red`, `uncertified`, `missing`); the skipped list (interface methods the mock does
  not implement); the invented list (mock methods the interface never declared); and the
  `MockData.forMethod` selector status (declared/discriminator type) with the per-method
  binding form where the selector is bound on disk.
- **AC-7** `zfa mock explain <Entity> --json` emits the same report under the canonical
  envelope's `details` (schema `zuraffa.verdict.v1`).
- **AC-8** `test/plugins/mock/mock_verify_test.dart` covers the pass path, the drift path, and
  the `--json` path (plus the no-mock refusal and the explain surface) and passes.
- **AC-9** The conformance shape is the SAME machinery `zfa mock create --certify` uses
  (`MockCertificationService.certify` + `MockCertifier.gate`) so verify and certify can never
  disagree about what "conforms" means.

## Constraints

- Verify is read-only; certify remains the generation + certification combo. Verify must not
  duplicate MockCertify's registry/receipt writes.
- Same conformance shape as MockCertify (`MockCertification` + `CertifyReport`), shared code
  path, no parallel reimplementation.
- Exit codes follow the ratified protocol (spec 917): 0 success, 1 failure/drift, 2 usage.
- The `--> fix:` line convention (errors-are-an-API) applies to every refusal.

## Out of scope

- Service-mode (`--service`) provider conformance (service verify already covers the service
  grammar; mock verify targets the entity datasource lane).
- Re-running the sandbox contract test (`zfa mock certify` remains the live re-proof).
- Migrating other plugins' envelopes.
