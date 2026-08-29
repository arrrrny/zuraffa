# Quickstart: Skeleton Plugin — Bare-Bones Feature Scaffold

Runnable validation for the feature. Prerequisites: repo root, Dart SDK
^3.11.0, `dart pub get` already run.

## Scenario 1 — Generate a standalone bone (US1)

```bash
dart run bin/zfa.dart bone generate 020-skeleton-plugin-bones
```

Expected: `.zfa/bones/020-skeleton-plugin-bones/` exists with `bone.yaml`,
`lib/entities/*.dart`, `lib/skeleton_plugin_bones.dart` barrel, and
`domain/`, `data/`, `presentation/` placeholders. `bone.yaml` lists the
spec's entities (Bone, Manifest, Dependency Graph) and a `spec_version`
hash. Command completes in under 10 seconds (SC-001).

## Scenario 2 — Dependency detection (US2)

With two features where B references an entity of A:

```bash
dart run bin/zfa.dart bone generate <feature-a>
dart run bin/zfa.dart bone generate <feature-b>
```

Expected: B's `bone.yaml` `dependencies` contains
`- bone: <feature-a>` with the shared entity listed. A bone with no
cross-references has `dependencies: []`.

## Scenario 3 — Cycle refusal (US2, FR-004)

Create two features that reference each other's entities, then:

```bash
dart run bin/zfa.dart bone generate <feature-a>
```

Expected: non-zero exit; stderr names the bones forming the cycle; no bone
directory is created.

## Scenario 4 — Export (US4)

```bash
dart run bin/zfa.dart bone export 020-skeleton-plugin-bones
tar -tzf .zfa/bones/020-skeleton-plugin-bones.tar.gz | head
```

Expected: one `.tar.gz` artifact listing `bone.yaml`, the stubs, and the
layer placeholders — everything a delegate agent needs.

## Scenario 5 — Validate + staleness (FR-005, FR-008)

```bash
dart run bin/zfa.dart bone validate 020-skeleton-plugin-bones
echo "# touched" >> specs/020-skeleton-plugin-bones/spec.md
dart run bin/zfa.dart bone validate 020-skeleton-plugin-bones   # now fails
```

Expected: first run exits 0; after editing the spec, validation fails with a
stale-spec message (hash mismatch).

## Scenario 6 — Test suite

```bash
dart test test/plugins/skeleton/
```

Expected: all unit tests green (generator, dependency resolver, spec reader,
manifest builder, command).

See `contracts/cli.md` for the full command contract and
`contracts/bone-manifest.md` for the manifest schema.

---

## Validation record (2026-08-29, T029)

- **Scenario 1** — PASS. `zfa bone generate 020-skeleton-plugin-bones` produced
  `.zfa/bones/020-skeleton-plugin-bones/` with `bone.yaml`, 3 entity stubs
  (`bone.dart`, `manifest.dart`, `dependency_graph.dart`), barrel, layer
  placeholders, and test stubs. Exposed and fixed two parser gaps (cycles
  41–42: h3 `### Key Entities` sections, multi-word entity names).
- **Scenario 2/3** — PASS via `sc_002_dependency_graph_test.dart` fixtures
  (cross-feature reference, cycle refusal, empty deps). The real spec 020 has
  no cross-feature entity references; its manifest correctly renders
  `dependencies: []`.
- **Scenario 4** — PASS. `zfa bone export` produced
  `.zfa/bones/020-skeleton-plugin-bones.tar.gz` containing all 11 bone files.
- **Scenario 5** — PASS. `zfa bone validate` exits 0 clean, reports
  `bone is stale` with expected/actual hashes after touching the spec, passes
  again after restore. Exposed and fixed the process exit-code clobber (cycle
  43, U36 in `cli_runner.dart`).
- **Scenario 6** — PASS. `dart test test/plugins/skeleton/` → 52 passed, 0 failed.
