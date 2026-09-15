# Quickstart: 1653-trim-heavy-deps

Validation scenarios proving the feature end-to-end. Prerequisites: Dart
3.11+ SDK, this repository checked out on `1653-trim-heavy-deps`.

## 1. Lean core (SC-001 / SC-002)

```bash
dart pub get --no-example          # resolves the TRIMMED root manifest
grep -E '^  (graphql|gql|minio|opentelemetry):' pubspec.yaml   # no matches
dart test test/core/lean_core_pin_test.dart   # manifest + import-graph pin
dart test                          # default fast lane green
```

Expected: the grep finds nothing; the pin suite and the fast lane pass.
A fresh consumer adding the core package resolves no heavy package
(the pin suite enforces the same invariant from the manifest side).

## 2. Plugin discovery and enable (SC-004)

```bash
zfa plugin list                    # three capabilities, disabled, packages named
zfa plugin enable graphql          # records plugins.graphql: true in .zfa.json
zfa plugin enable graphql          # no-op success ("already enabled")
zfa plugin list                    # graphql reports enabled
cat .zfa.json                      # other keys untouched
```

## 3. Gate behavior (SC-003, disabled side)

```bash
zfa plugin disable graphql         # or use a project without the enable step
zfa graphql generate ...           # exits non-zero with the enable guidance
```

Expected: guidance names `zfa plugin enable graphql` and
`package:zuraffa_graphql`; no partial artifacts are written.

## 4. Seamless enabled path (SC-003, enabled side)

```bash
# project depends on the companion (in-repo: path dep on packages/zuraffa_graphql)
zfa plugin enable graphql
zfa graphql generate ...           # completes with the pre-split command surface
```

Expected: identical outputs to the pre-split flow for the same inputs.

## 5. Companions are healthy

```bash
cd packages/zuraffa_graphql && dart pub get && dart analyze && dart test
cd ../zuraffa_storage && dart pub get && dart analyze && dart test
cd ../zuraffa_observability && dart pub get && dart analyze && dart test
```

Expected: all three companions analyze clean and their (moved) suites
pass.
