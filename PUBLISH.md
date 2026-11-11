# Publish Configuration

**Mono version policy:** every package in the zuraffa fleet shares one version number. Bump the whole fleet with `../zuraffa/scripts/update_fleet.sh <version>`. Whenever a version is updated, the install guide in this repo's README.md MUST be updated to that release version in the same change — no old version constraints may linger in README install snippets. Dependency constraints on `zuraffa` itself must move to `^<version>` in the same bump.

<!-- Auto-generated/updated by publish-manager skill. Edit if the workflow changes. -->

## Package Manager

- **Type**: `pub.dev` (requires `dart pub login` credentials on this machine)
- **Fleet**: 23 repos under `~/Developer`, all sharing ONE mono version
  (`zuraffa`, `zuraffa_flutter`, `zuraffa_ui`, `zuraffa_agent`,
  `zuraffa_code_editor`, `zuraffa_ffi`, `zuraffa_graphql`,
  `zuraffa_observability`, `zuraffa_storage`, `zuraffa_session`,
  `zuraffa_intents`, `zuraffa_minio`, `zuraffa_auth`, `zuraffa_dashboard`,
  `zuraffa_file_picker`, `zuraffa_inappwebview`, `zuraffa_ocr`,
  `zuraffa_permissions`, `zuraffa_purchase`, `zuraffa_subscriptions`,
  `zuraffa_notifications`, `zuraffa_tui`, `zuraffa_vendure`)
- Federated repos publish several packages from one repo (root + `packages/*`
  + root-level platform dirs, e.g. `zuraffa_auth` → `zuraffa_auth`,
  `zuraffa_auth_platform`, `zuraffa_auth_android`, ...). `zuraffa_vendure`
  publishes under the package name `vendure`.
- Not part of the fleet: `zuraffa_browser` (standalone product), review
  clones, sandboxes, `examples/`, `apps/`.

## Scripts

- **Pre-publish**: `./scripts/update_fleet.sh <version> [--pull] [--changelog "<msg>"] [--no-commit]` —
  sets every fleet pubspec version, rewrites `zuraffa: ^x.y.z` constraints to
  `^<version>`, ensures the `xml: 7.1.0` override policy, refreshes README
  install guides, prepends a CHANGELOG entry, ensures PUBLISH.md policy, and
  commits per repo (default; `--no-commit` to keep dirty). Adds dev-mode
  `--sibling` path overrides for fleet deps not yet live on pub.dev.
  Needs bash >= 4 (`/usr/local/bin/bash` on macOS).
  `--check` mode reports drift only.
- **Publish**: `./scripts/publish_fleet.sh <version> [--dry-run-only]` —
  publishes every fleet package topologically (Kahn order from a hardcoded
  inventory + edges), skipping anything already on pub.dev at the target
  version; gates each publish on fleet deps being resolvable at the target
  (pub.dev API + throwaway `dart pub get` probe); `--dry-run` validation
  errors abort, warnings tolerated; retries on rate limit. The
  `zuraffa_ffi` family publishes as a set (intra-family cycle → deferred
  resolvability gates).
- **Post-publish (dev mode)**: `./scripts/restore_dev.sh` — rewrites core
  repo `dependency_overrides` back to local path deps (zorphy etc.).
- **Legacy core-only**: `./scripts/publish.sh <version>` — publishes only the
  core `zuraffa` package; aborts if dev-mode path deps are present.
- **Tag cleanup**: `./scripts/delete_tag.sh` if a tag was cut wrongly.

## Workflow

1. `git pull` every fleet repo (`update_fleet.sh --pull` does `--ff-only --rebase` per repo)
2. Decide the target version from **pub.dev**, not the local checkouts: the
   fleet never republishes an existing version, so if ANY package already
   sits at the candidate version on pub.dev, go one higher. (Example:
   2026-11: most packages at 7.3.8, `zuraffa_purchase` 7.3.9,
   `zuraffa_notifications` 7.4.0 → fleet target 7.4.1.)
3. `./scripts/update_fleet.sh <version> --pull --changelog "<release message>"`
4. Verify: `./scripts/update_fleet.sh <version> --check` must be clean
5. Push every fleet repo to its default branch (straight to master/main —
   fleet convention, no PRs, no release branch)
6. `./scripts/publish_fleet.sh <version> --dry-run-only` first, then
   `./scripts/publish_fleet.sh <version>`
7. Tag `<version>` in the core repo and push the tag
8. Optional: `./scripts/restore_dev.sh` to return the core repo to dev mode

## Notes

- Local checkouts can LAG the published fleet (versions were published from
  states that were never pushed back); trust pub.dev as the source of truth
  for "already taken" versions and let `update_fleet.sh` normalize the tree.
- The publish order and inventory live inside `publish_fleet.sh`; when a
  package or a dependency edge is added, update its `INVENTORY`/`EDGES` and
  `update_fleet.sh`'s `FLEET_REPOS` in the same change.
- pub does NOT strip `dependency_overrides` from published archives —
  dev-only overrides must be removed before publishing (update_fleet's
  `--sibling` overrides are dev-mode only; the strip-before-push/publish
  convention applies to hand-added ones).
