# Bug Assessment: GeneratorConfig round-trip drops generateService / useService

- **Slug**: generator-config-service-roundtrip
- **Created**: 2026-10-20
- **Source**: https://github.com/arrrrny/zuraffa/issues/1972 (host `github.com` — allowlisted; read via `gh issue view`, not an HTTP fetch)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Issue #1972 (open, filed by arrrrny, labeled `bug`, origin: follow-up deferred
during the review of #1970 / the #1967 fix):

> `GeneratorConfig.toJson()` never emits a producer for the `generateService` /
> `useService` bool flags, and it overloads the `'service'` key with the
> service **name** (a `String?`) that `fromJson()` also reads as a **bool**.
> After a `toJson()` → `fromJson()` round-trip both flags silently revert to
> `false`.
>
> Suggested fix: dedicated keys on the write side, matching the reads that
> already exist — `'generate_service'` / `'use_service'` in `toJson()`, and
> `useService: json['use_service'] == true` in `fromJson()`. The name keeps its
> own `'service'` slot (`service: json['service']` stays as-is).

## Symptom

A `GeneratorConfig` built with `generateService: true` or `useService: true`
serializes through `toJson()` without any `'generate_service'` /
`'use_service'` key. Feeding that map back through `GeneratorConfig.fromJson()`
yields `generateService: false` and `useService: false`. Expected: both flags
survive the round-trip.

Downstream this is not a cosmetic loss — `hasService`
(`lib/src/models/generator_config.dart:537`), the `service` name fallback
(`effectiveService` `:562`, `effectiveProvider` `:580`, `providerSnake` `:608`)
and `hasRepo` (`:536`) all key off `useService`, so a replayed config
generates a data-source-less service (or a differently-named one) than the
user configured — silently, with no error and no warning.

## Reproduction

1. Construct `GeneratorConfig(name: 'Product', generateService: true, useService: true, outputDir: GeneratorConfig.fixedOutputDir)`.
2. `final json = config.toJson();`
3. `GeneratorConfig.fromJson(json, 'Product').generateService` → `false` (expected `true`); `.useService` → `false` (expected `true`).

## Suspected Code Paths

- `lib/src/models/generator_config.dart:245` — `service: json['service']` reads
  the service **name** from the same `'service'` key.
- `lib/src/models/generator_config.dart:255-256` —
  `generateService: json['service'] == true || json['generate_service'] == true`
  reads the same key as a **bool**; the dedicated `'generate_service'` read
  exists but nothing ever writes it.
- `lib/src/models/generator_config.dart` `toJson()` (`:728-792`) — emits
  `'service': service` (the name) and has no `'generate_service'` /
  `'use_service'` producer.
- `lib/src/models/generator_config.dart` `fromJson()` — `useService` is not
  read from any key at all.

## Root Cause Hypothesis

Write-side omission, confidence **high** (verified on the tree): the
`'service'` JSON key carries two different types across the round-trip — the
service *name* (`String?`) on the write side and a *flag* on the read side.
Because `toJson()` writes a name (a `String?`, never `== true`), the
`json['service'] == true` branch of the read side can never fire for a
round-tripped config, and `fromJson()` has no dedicated `'generate_service'`
producer to fall back on. `useService` is worse: it has neither a producer nor
a consumer, so it is always `false` after a replay.

Note the read-side collision named in the issue: `json['service']` feeds the
`String? service` field, so a bool under that key is a type error waiting to
happen (the same shape #1962 fixed for `'presenter'` / `'controller'`). The
`'service'` slot therefore has to keep carrying the name, and the flags need
their own keys.

## Proposed Remediation

**Preferred** — one line each in `toJson()`, one read in `fromJson()`:

```dart
// toJson()
'generate_service': generateService,
'use_service': useService,

// fromJson()
generateService: json['generate_service'] == true,
useService: json['use_service'] == true,
```

The `json['service'] == true` overload is dropped from the `generateService`
read: it is unreachable dead code — a bool under `'service'` already crashes
the `service: json['service']` name read above it (same failure shape as
#1962), so the clause can never be the one that decides the flag. The
`'service'` key keeps carrying the name, unchanged.

**Alternatives**:
- Emit the flags under the overloaded `'service'` key — rejected: the key
  already holds the name, and one key cannot carry both types.
- Sparse emission (only when `true`) — rejected: inconsistent with every
  sibling bool flag, which are all emitted unconditionally.

**Files likely to change**:
- `lib/src/models/generator_config.dart` (two producers in `toJson()`, two
  reads in `fromJson()`)
- `test/fixes/bug_1972_generator_config_service_roundtrip_test.dart` (new
  regression test)

**Tests to add or update**:
- `toJson()` carries the `'generate_service'` and `'use_service'` keys.
- `generateService: true` and `useService: true` survive
  `toJson()` → `fromJson()` — RED on the unfixed tree, GREEN after.
- The service *name* survives the round-trip and does **not** flip
  `generateService` (the overload regression).
- `useService: true` keeps `hasService` true and the `serviceSnake` fallback
  (`'productService'`) — the downstream effect the issue calls out.
- Explicit `{'generate_service': true}` / `{'use_service': true}` external
  JSON still parses true — pins the read-side contract.
- Default (`false`) config still round-trips as `false`.

## Risks & Considerations

- Persisted configs (`.zfa.json`) gain two keys; older readers ignore
  unknown keys, and the read side now consumes them — no compatibility risk.
- The `'service'` key keeps its meaning (the name), so no existing producer
  or consumer changes behaviour.
- None generated code is touched (`generator_config.dart` is the hand-written
  "Refactored modular version" model, not a `.zorphy.dart` artifact).

## Open Questions

- None — the issue names the root cause, the evidence lines and the fix shape.

## Follow-up finding during reproduction (scope note)

The sibling defect class is tracked separately in #1966 (sync/strategy half) —
out of scope here. This assessment covers only the two service flags the issue
names.
