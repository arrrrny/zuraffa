# Spec 0973 — repository A+ upgrade

> Source of truth: https://github.com/arrrrny/zuraffa/issues/973

## Mission

Make `repository` an **A+ plugin**. The backbone of every preset. Make
"it compiles and conforms" a proven claim at generation time, kill the
flag-maze opacity, and test the untested variants.

## Orders

1. **Post-generation conformance check (in-process AST):** every interface
   method has an `@override` impl and vice versa. Verdict + failure list;
   mismatch → exit 1 + `--> fix:` naming the method and side.
2. **Repository contract manifest:** per-entity
   `.zfa/receipts/repository-<entity>.json` — method set + params/returns
   signatures, hashed. Upgrade `SourceInterfaceGuard` to consume the manifest
   when fresh, falling back to source parsing — one source of truth.
3. **`--explain` / `--json` resolved-plan object:** what will be emitted and
   why (which variants, which flags triggered them).
4. **Tests:** conformance check positive/negative, synced variant content,
   simple/append variants, manifest hash stability.

## Constraints

- Do not reorder PluginManager wiring — surface the resolved plan instead of
  changing activation.
- Receipts via existing ReceiptStore (`entity create` is the reference).
- Failing-first tests under `test/plugins/repository/`.
- One PR for the spec.

## Acceptance — all must hold

- Generating an interface/impl pair with a deliberate mismatch fails at
  generation time with `--> fix:` — tested.
- Fresh generation writes the contract manifest; `zfa proof check` green,
  red on hand-edit.
- `--explain` output shows the resolved emission plan for a
  cache+sync+datasource config — snapshot-tested.
- Synced, simple, and append variants each have content-asserting tests.
