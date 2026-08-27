# Running the test suite

Tests are split into a **fast unit suite** (default) and **slow tiers**
(E2E generation, full CLI runs, property/benchmark). This keeps day-to-day
feedback quick while still letting you target exactly the slice you care about.

## Tiers

| Tier        | Tag             | Folder(s)                                  | Speed  |
|-------------|-----------------|--------------------------------------------|--------|
| unit (default) | —             | `core`, `plugins`, `commands`, `state`, `graphql`, `config`, `domain`, `dda`, `cli`, `utils`, `src`-derived | fast   |
| regression  | `regression`    | `test/regression`                          | slow (E2E codegen) |
| integration | `integration`   | `test/integration`                        | slow (spawns CLI)   |
| property    | `property`      | `test/property`                           | slow   |
| benchmark   | `benchmark`     | `test/benchmark`                          | slow   |

Every slow test is also tagged `slow`. The default `dart test` run excludes
the `slow` tier (see `dart_test.yaml`).

## Commands

Run the fast unit suite (default — this is the quick one):

```bash
dart test
```

Run the **full** suite (CI / pre-commit — includes all slow tiers):

```bash
dart test --preset=all
```

Run a single slow tier:

```bash
dart test --preset=regression
dart test --preset=integration
dart test --preset=property
dart test --preset=benchmark
```

Target a **semantic folder** (fast feedback while working on one area):

```bash
dart test test/core
dart test test/plugins/route
dart test test/commands
dart test test/graphql
```

Run a **single file**:

```bash
dart test test/core/result_test.dart
```

## How it is wired

- Slow tiers carry `@Tags([...])` at the top of each file (library-level).
- `dart_test.yaml` sets `exclude_tags: slow` so the default run is fast, and
  defines `presets` for the full suite and each tier.
- Add the `slow` tag (plus the tier tag) to any new E2E / heavy test so it is
  excluded from the default run automatically.
