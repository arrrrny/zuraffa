# TDD Cycle Log — 978-service-aplus-upgrade

Toolchain: Dart 3.13.2 / spec-kit TDD extension v1.1.2. All evidence from
real runs (commands + output quoted verbatim).

## RED phase (2026-09-05)

Suite: `dart test test/plugins/service/` on the pristine master checkout
(77e69f24) + new failing-first tests.

| test file | order | RED? | failure evidence (verbatim) |
| --- | --- | --- | --- |
| service_plugin_skip_verdict_test.dart | 1 | RED (2 of 4) | `Expected: prints (contains 'Skipping service generation' ...) Actual: <Closure> Which: printed nothing` — the silent empty success reproduced. FR-3 (empty list, no artifact) and the no-regression case passed as expected (they pin current behavior). |
| service_schema_grammar_parity_test.dart | 2 | RED (4 of 5) | `the service command grammar offers knobs configSchema does not advertise: {help, params, returns, type, init}`; create subcommand missing `--init`; `type` has no enum. The `--init` end-to-end execute test passed (execute() handles init; only the CLI flag was unreachable). |
| make_service_triad_test.dart | 3 | RED (1 of 2) | `Expected: (contains 'Future<Product>' or contains 'getProduct')` — actual service artifact: `abstract class ProductService {}` (EMPTY interface). Manual probe (`dart run bin/zfa.dart -C /tmp/triad_ws make Product --service Product di`) confirmed the triad is a hollow shell: empty interface at the FLAT path `domain/services/product_service.dart` while the generated usecase imports the ENTITY path `domain/services/product/product_service.dart` and calls `_service.toggle(params)` — three internally-broken contracts. The proof-check test passed (receipts green). |
| service_method_append_test.dart | 4 | GREEN on landing | Behavior already correct (preservation + append + idempotency) — the bug was the missing test (coverage gap), recorded honestly. No production change needed for order 4. |
| service_create_json_verdict_test.dart | 5 | RED (3 of 4) | machine mode: `Expected: not null / Actual: <null>` — no verdict object printed (prose `✅ Success!` instead); error path printed `❌ Error: Missing required arguments: name` with no `--> fix:` line and no verdict. Prose-mode regression-guard test passed. |

RED totals: 10 failing tests across 4 files (order 1: 2, order 2: 4,
order 3: 1, order 5: 3), 6 passing characterization/guard tests.

## Root-cause notes (carried into GREEN)

- `service_plugin.dart` guard (93-99) is dead code
  (`!isEntityBased && !isCustomUseCase` unsatisfiable — the getters are
  complements); the live silent path is `serviceSnake == null → return []`.
- `generateWithContext` passes `methods: data['methods'] ?? []` while the
  triad siblings (usecase, repository) default `['get','update','toggle']`
  for entity flows — hence the empty interface + flat path mismatch.
- `ServiceInterfaceBuilder._buildEntityMethod` lacks a `toggle` case (the
  repository interface generator has one) — required once the default lands.
- configSchema advertises only `service`; `CreateServiceCapability.inputSchema`
  lacks `init` (so `zfa service create --init` cannot parse) and `type` has
  no enum.
- No machine verdict channel on create; no `--> fix:` on error paths.

## GREEN phase (2026-09-05)

Changes:
1. `service_plugin.dart` — dead guard removed; structured skip note +
   `--> fix:` on the decline; configSchema maps params/returns/type/init
   (+enum, defaults mirroring the command grammar); generateWithContext
   defaults entity methods to get/update/toggle (mirroring usecase +
   repository) and reads init/params/returns/type from context data.
2. `service_interface_builder.dart` — `case 'toggle'` mirroring the
   repository signature (`Future<E> toggle(ToggleParams<Id, Field<E, dynamic>>)`).
3. `create_service_capability.dart` — inputSchema adds `init`, `type` enum,
   params/returns defaults; execute() attaches `data['verdict']`
   `{schema:1, ok, file, methods, type}`.
4. `capability_command.dart` — verdict hook (machine mode = `--json` input),
   `--> fix:` line on the missing-required error path.
5. No changes to make/plan_resolver triad activation (hard constraint held).

GREEN evidence: see verification.md (all five files green, full fast suite
green via tools/run_tests_chunked.sh).

## Mutation spot-check + process incident (2026-09-05)

Four targeted manual mutants, all killed:

- **A** (silence the skip note) → 2 skip-verdict tests fail
  (`Which: printed nothing`).
- **B** (drop `init` from configSchema) → 2 parity tests fail (drift named).
- **C** (strip the verdict from the create result) → 2 json-verdict tests
  fail (`Actual: <null>`); the error-path test still passes — its verdict
  comes from CapabilityCommand, proving the two channels are independent.
- **D** (drop the entity-methods default) → make-triad test fails (the
  interface regresses to the empty shell).

**Honest incident**: the first pass reverted mutants with
`git checkout <file>`, which restored the unstaged index (pristine master)
and wiped the GREEN edits to `service_plugin.dart` and
`create_service_capability.dart`. Mutants A and C were clean kills; B and D
had degraded into "GREEN-code-absent" kills. Both files were rewritten to
the exact GREEN content, the service suite re-verified (25/25), and B and D
re-run properly with copy-based backup/restore and asserted pattern
matches — both killed cleanly. The final diff is byte-identical to the
pre-incident GREEN state (4 files, +226/−12; confirmed via
`dart format .` → 0 changed and full re-runs).

## Cycle 2 — provider mirror of the service surface (2026-09-05, post-merge)

The master merge (5196caf6) surfaced the second half of the triad contract:
the service interface now declares the entity surface, but the PROVIDER
generated in the same make run did not implement it — the #921 provider
conformance guard (merged to master since the original GREEN) failed the run.

### RED evidence (verbatim, `dart test test/plugins/service/make_service_triad_test.dart`)

```
❌ Provider conformance failed for "Product" — 3 finding(s):
  [missing_method] ProductProvider does not implement ProductService.get ...
  [missing_method] ProductProvider does not implement ProductService.update ...
  [missing_method] ProductProvider does not implement ProductService.toggle ...
```

### Root cause (traced, three-link chain)

1. `ProviderPlugin.generateWithContext` passed
   `methods: data['methods'] ?? []` — no entity-methods default (the
   service plugin got its default in cycle 1; the provider did not).
2. `GeneratorConfig.isEntityBased => methods.isNotEmpty && !noEntity` —
   with methods empty the provider config is NOT entity-based, so
   `ProviderBuilder.generate` built the service lookup path as the FLAT
   `domain/services/<name>_service.dart` while the service (entity-based
   since cycle 1) wrote the ENTITY path
   `domain/services/<domain>/<name>_service.dart`.
3. Extraction returned 0 methods → the builder fell through to the
   params/returns fallback and emitted the phantom
   `Future<void> product(NoParams)` member.
   Instrumented probe (temporary print, since removed) confirmed:
   `servicePath=lib/src/domain/services/product_service.dart exists=false
   extracted=0 configMethods=[]`.

### GREEN changes

1. `provider_plugin.dart` — generateWithContext mirrors the service's
   entity-methods default (`['get','update','toggle']`), gated:
   explicit `--methods` wins; `--no-entity` stays hollow; `use-service`
   keeps the extraction-from-disk mirror semantic (#768/#979) because an
   EXISTING interface may carry a custom surface.
2. `provider_builder.dart` — `case 'toggle'` in `_buildEntityMethod`,
   mirroring the service builder signature exactly
   (`Future<E> toggle(ToggleParams<Id, Field<E, dynamic>>)`).

### GREEN evidence

- `make Product --service Product di` repro: provider now emits
  `get`/`update`/`toggle` with signatures identical to the interface; the
  conformance guard passes (`✅ Done.`).
- `dart test test/plugins/service/ test/plugins/provider/` → 53/53 green.
- Full fast suite: re-run at commit time (see verification.md).
