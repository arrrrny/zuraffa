# Migration Plan — Migrate all ZikZak pub.dev packages to Zuraffa v6 (EPIC #214)

**Spec**: `specs/032-migrate-pubdev-packages/spec.md`
**Playbook**: `docs/package_migration_guide.md`
**Status**: Draft — consolidated plan

## 0. Goal

Rewrite every ZikZak package published under the `zuzu.dev` publisher onto
Zuraffa v6, so the whole family shares one architecture (entities, ports,
repositories, use cases, module lifecycle, DI), one TDD pipeline, and one
publish pipeline. In parallel: fork orphaned dependencies, stand up a
PRO-only private Unpub at `zikzak.zuzu.dev`, and ship a macOS/iOS/Android
showcase ecommerce app built entirely on the migrated stack.

## 1. Inventory

### 1.1 Already migrated (Zuraffa-native, on pub.dev under zuzu.dev)

| Package | Shape | Version | Spec |
|---|---|---|---|
| zuraffa | core framework | (this repo) | — |
| zuraffa_flutter | Flutter bindings | 7.1.0 | — |
| zuraffa_auth | federated plugin | 1.1.1 | 058 |
| zuraffa_browser | package | 1.5.1+10 | 056 |
| zuraffa_code_editor | package | 0.3.6 | — |
| zuraffa_file_picker | federated plugin | 1.0.0 | 060 |
| zuraffa_graphql | package | 0.1.1 | — |
| zuraffa_inappwebview | federated plugin | 0.1.0 | — |
| zuraffa_intents | package | 1.0.3 | 062 |
| zuraffa_minio | package | 0.1.1 | — |
| zuraffa_observability | package | 0.1.1 | — |
| zuraffa_ocr | federated plugin | 0.1.1 | — |
| zuraffa_permissions | federated plugin | 1.0.1 | 055 |
| zuraffa_session | package | 1.2.1 | — |
| zuraffa_storage | package | 0.1.1 | — |
| zuraffa_subscriptions | package | 2.0.0 | — |
| zuraffa_ui | package | 0.4.0 | — |
| zuraffa_agent | package | 0.6.0 | 054 |

### 1.2 Legacy (still on the old stack — to be migrated)

| Legacy package | Target | Migration shape | Status |
|---|---|---|---|
| zikzak (app) | showcase app host | Flutter app on zuraffa | in progress (V5_MIGRATION_PLAN) |
| zikzak_inappwebview | zuraffa_inappwebview | federated plugin (rebrand) | migrated (0.1.0) |
| zikzak_json | zuraffa_* (TBD) | pure package | pending |
| zikzak_ml_kit_flutter | zuraffa_* (TBD) | federated plugin | pending |
| zikzak_session | zuraffa_session | pure package | migrated (1.2.1) |
| zikzak_share_handler | zuraffa_* (TBD) | federated plugin | pending |
| zikzak_useragent (pub.dev) | zuraffa_* (TBD) | federated plugin | pending |
| html_to_markdown / html_to_markdown_ffi | zuraffa_* (TBD) | pure package + FFI | 064 |
| vendure_flutter_sdk | vendure-flutter-sdk (separate) | package | 065 |

### 1.3 Orphaned third-party dependencies (fork candidates)

Packages ZikZak depends on that are unmaintained. Each gets a fork strategy
(fork-and-maintain / replace-with-Zuraffa-native / drop) per §3 of the
playbook. Legal review precedes any fork action.

## 2. Execution order (dependency-resolved)

Foundational packages first; dependents later. One PR per package.

1. **Core pure packages** — `zuraffa_session`, `zuraffa_storage`,
   `zuraffa_minio`, `zuraffa_observability`, `zuraffa_graphql`.
   (Already migrated; keep as the parity baseline.)
2. **Platform/wrapper packages** — `zuraffa_auth`, `zuraffa_permissions`,
   `zuraffa_file_picker`, `zuraffa_inappwebview`, `zuraffa_ocr`,
   `zuraffa_subscriptions`.
3. **Feature-rich packages** — `zuraffa_browser`, `zuraffa_intents`,
   `zuraffa_code_editor`, `zuraffa_ui`, `html_to_markdown_ffi`.
4. **Rebrands** — `zikzak_inappwebview` → `zuraffa_inappwebview` (done),
   `zikzak_session` → `zuraffa_session` (done), remaining `zikzak_*` →
   `zuraffa_*` (pending).
5. **Orphaned forks** — per dependency audit.
6. **Private PRO repo** — `zikzak.zuzu.dev` Unpub for PRO-only packages
   (network interceptor, etc.).
7. **Showcase app** — macOS/iOS/Android ecommerce app (mag Magento-like
   builder) consuming only Zuraffa v6 packages.

## 3. Per-package migration recipe (from the playbook)

For each legacy package:

1. Phase 0 — Inventory (public API census, behavior census, native/platform
   census, dependency census, consumers). Write
   `specs/<NNN>-zuraffa-rewrite/migration-contract.md`.
2. Phase 1 — Scaffold (`zfa package create` / `zfa package create-plugin`).
3. Phase 2 — Map old API to Zuraffa shapes (Port + Service + UseCases,
   entities, StreamUseCase, module lifecycle, DI, AppFailure, strategies).
4. Phase 3 — Port tests first (TDD loop: `zfa tdd init/plan/run/status/verify`).
5. Phase 4 — Compatibility facade (old barrel re-exports, `@Deprecated`).
6. Phase 5 — Parity gates (§4 below).
7. Phase 6 — Publish (pub.dev minor bump; major only when facades deleted).

## 4. Parity gates (completion criteria)

A package migration is complete only when ALL hold:

- API parity: every Phase-0 symbol exported, or listed as intentionally broken.
- Behavior parity: full ported suite green; test count ≥ baseline; no test
  deleted without a contract note.
- Layer discipline: `lib/src/domain` imports no `dart:io`/`dart:ffi`/channel code.
- DI completeness: every public usecase/repository resolves from a fresh
  container after `registerPackage`.
- Statics: `dart analyze` clean; `zfa build` clean.
- Module lifecycle: bootstrap/ready/shutdown test passes.
- Publish: `dart pub publish --dry-run` clean (per package).
- Journal: `specs/<NNN>/tdd/cycle-log.md` shows red→green evidence per behavior.

## 5. Private repository (zikzak.zuzu.dev)

- Unpub instance behind PRO subscription auth.
- PRO subscribers configure it as a Dart package source; non-subscribers
  rejected with a clear subscription-required error.
- High-value packages (network interceptor, etc.) published there with private
  access.
- SLA-backed availability; graceful degradation (cached resolution) on outage.

## 6. Showcase app

- macOS / iOS / Android ecommerce app (Magento-like app builder).
- Exclusively consumes Zuraffa v6 packages (open-source + private).
- Reference implementation demonstrating open-source + private resources.
- Core flows: browse, search, cart, checkout.

## 7. Tracking

Progress is tracked per package in the corresponding spec under `specs/`
(053-065, 032). The parent EPIC is GitHub issue #214. Each completed
package migration closes its per-package issue and updates this plan's
inventory table.

## 8. Single-prompt execution

The whole migration can be driven by a single prompt that points an agent at
this plan + `docs/package_migration_guide.md` and instructs it to migrate the
next pending package in §2 order, one PR per package, following §3 and
gating on §4. The agent must not start package N+1 until package N's parity
gates are green.
EOF
