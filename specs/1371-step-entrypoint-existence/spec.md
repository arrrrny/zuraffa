**Template Version**: `zuraffa-1.0`

# Spec: 1371-step-entrypoint-existence

GitHub issue: arrrrny/zuraffa#1371 (verify-misfire / missing-integration,
EPIC #1012 Phase A step 6, #1008 two-cycle driver)

## Summary

`dart run bin/zfa.dart -C example tdd run 004-login-ui` died at the first
step: `Error when reading '<repo>/example/bin/zfa.dart'` (VM exit 254).
Root cause: the global `-C` chdir re-anchors the RELATIVE launch arg that
`Platform.script` reports, and `StepRunner.resolveEntrypoint` tier 1
returned that re-anchored path whenever its basename was zfa.dart /
zuraffa.dart — WITHOUT an existence check (tiers 2/4/5 all check). The
result: every step spawn targeted a file that does not exist. The same
invocation with `--project <abs>` (no `-C`) passed, proving the
resolution chain works standalone and breaks only under the CLI's own
global flag.

## Locked decisions

1. Tier 1 gains the same existence check tiers 2/4/5 use: a phantom
   script falls through to the package-path tier, which resolves
   `package:zuraffa/src/zfa_cli.dart` via the VM's package config and is
   immune to the chdir (verified by the issue's differential).
2. An existing zfa.dart/zuraffa.dart script is still returned verbatim —
   tier precedence is unchanged for every working invocation.
3. A phantom script with nothing resolvable still ends in the honest
   `cannot resolve the zfa entrypoint` StateError — no phantom path is
   ever returned as a spawn entrypoint.
4. No change to `-C` semantics, the step protocol, or the spawn shapes.

## Functional requirements

- **FR-1**: a re-anchored (phantom) zfa.dart script falls through to the
  package tier and resolves to an EXISTING bin/zfa.dart.
- **FR-2**: an existing zfa.dart script is returned verbatim.
- **FR-3**: a phantom script with nothing else resolvable throws the
  honest cannot-resolve StateError.

## Acceptance scenarios

1. Phantom `<tmp>/example/bin/zfa.dart` + a resolvable package tier →
   resolves to `<tmp>/pkg/bin/zfa.dart` (existing) (B1).
2. Existing zfa.dart script → returned verbatim (B2).
3. Phantom script + empty PATH + unresolvable package → the honest
   StateError (B3).

## Success criteria

- **SC-001**: `zfa tdd run <feature>` under the global `-C` flag drives
  the engine lane past gen (the epic's step 6 no longer dies at A1:gen).
- **SC-002**: The step runner suites stay green.

## Assumptions

- The package tier's resolution is chdir-immune (the VM resolves against
  the package config, not the cwd) — the issue's instrumentation verified
  this differential.
