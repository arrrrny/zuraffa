# Bug Assessment: GeneratorConfig round-trip cannot preserve generateRemote: false

- **Slug**: generator-config-remote-roundtrip
- **Created**: 2026-10-20
- **Source**: https://github.com/arrrrny/zuraffa/issues/1967 (host `github.com` — allowlisted; read via `gh issue view`, not an HTTP fetch)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Issue #1967 (open, filed by arrrrny, labeled `bug`, origin: follow-up found during
review of #1965):

> `GeneratorConfig.fromJson()` reads `generateRemote: json['remote'] != false`
> (`lib/src/models/generator_config.dart:263`), but `GeneratorConfig.toJson()`
> never emits a `'remote'` key. So `generateRemote: false` cannot survive a
> `toJson` → `fromJson` round-trip: the replayed config silently comes back as
> `generateRemote: true`.
>
> Suggested fix: Emit `'remote': generateRemote` from `toJson` alongside the
> other bool flags — a one-line write-side addition. (Read-side-only was the
> correct shape for #1965 because no producer existed under the overloaded
> keys; here it is the writer that is missing.)

## Symptom

A `GeneratorConfig` built with `generateRemote: false` serializes through
`toJson()` without any `'remote'` key; feeding that map back through
`GeneratorConfig.fromJson()` yields `generateRemote: true` (the key is absent,
and the read side defaults ON via `!= false`). Expected: the flag survives the
round-trip.

## Reproduction

1. Construct `GeneratorConfig(name: 'Product', generateRemote: false, outputDir: GeneratorConfig.fixedOutputDir)`.
2. `final json = config.toJson();`
3. `GeneratorConfig.fromJson(json, 'Product').generateRemote` → `true` (expected `false`).

Confirmed against `master`@HEAD of this clone: read side
`generateRemote: json['remote'] != false` (lib/src/models/generator_config.dart:271);
`toJson()` map (lines ~724-787) has `'local': generateLocal` and no `'remote'` entry.

## Suspected Code Paths

- `lib/src/models/generator_config.dart:271` — the only consumer of the
  `'remote'` key: `generateRemote: json['remote'] != false` (default-ON read).
- `lib/src/models/generator_config.dart` `toJson()` (~:724-787) — emits every
  sibling bool flag (`'local'`, `'state'`, `'init'`, `'test'`, …) but has no
  `'remote'` producer.

## Root Cause Hypothesis

Write-side omission, confidence **high** (verified on the tree): `fromJson`
was built to read `'remote'` (default-ON so legacy configs without the key
keep generating remote sources), but `toJson` never gained the matching
emitter. The round-trip is therefore asymmetric by construction — exactly the
class of bug #1965 fixed on the read side for overloaded keys, except here
the writer is missing outright.

## Proposed Remediation

**Preferred**: add `'remote': generateRemote,` to the `toJson()` map next to
`'local': generateLocal` — one line, unconditional, matching how every other
bool flag is emitted. `fromJson`'s `!= false` read then round-trips both
`true` and `false` correctly, and external JSON that omits `'remote'` keeps
its default-ON behaviour (no read-side change, no migration).

**Alternatives**:
- Emit `'remote'` only when `false` (sparse emission) — rejected: inconsistent
  with every sibling flag, which are all emitted unconditionally.
- Change the read side to a tri-state — rejected: no tri-state exists in the
  model, and the issue explicitly scopes the fix to the writer.

**Files likely to change**:
- `lib/src/models/generator_config.dart` (one line in `toJson()`)
- `test/fixes/bug_1967_generator_config_remote_roundtrip_test.dart` (new regression test)

**Tests to add or update**:
- `generateRemote: false` survives `toJson()` → `fromJson()` (and `toJson()`
  actually carries the `'remote'` key) — RED on the unfixed tree, GREEN after.
- Default (`true`) config still round-trips as `true` — locks in no regression.
- Explicit `{'remote': false}` external JSON still parses to `false` — pins the
  existing read-side contract (#1965 shape) as unchanged.

## Risks & Considerations

- Serialized `.zfa.json` / persisted configs gain a `'remote'` key; older
  readers ignore unknown keys, and the read side already consumes it — no
  compatibility risk.
- `fromJson`'s `json['remote'] != false` treats any non-`false` value as ON,
  so the emitted `true` round-trips identically to absence today.
- None generated code is touched (`generator_config.dart` is hand-written
  "Refactored modular version", not a `.zorphy.dart` artifact).

## Open Questions

- None — the issue names the root cause, evidence lines, and fix shape.

## Follow-up finding during reproduction (scope note)

The issue's round-trip scenario crashes on `master` before the remote flag is
reachable: `fromJson()` read the custom presenter/controller names from the
same `'presenter'`/`'controller'` keys `toJson()` emits as bools, so EVERY
full round-trip threw `type 'bool' is not a subtype of type 'String?'`
(generator_config.dart:318). The unmerged `origin/fix/issue-1962` branch
(`25f7231`, issue #1962) already fixes exactly this with dedicated-key reads
(`custom_presenter_name` / `custom_controller_name`); this fix applies that
identical shape so the two PRs converge instead of conflicting. Without it,
the #1967 acceptance ("round-trip preserves generateRemote: false") cannot
pass on master. Everything else in `fromJson` is type-safe against `toJson`'s
emissions (`seed` is guarded; every other `String?` read pairs with a
same-typed emission).
