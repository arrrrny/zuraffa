# Publish Configuration

**Mono version policy:** every package in the zuraffa fleet shares one version number. Bump the whole fleet with `../zuraffa/scripts/update_fleet.sh <version>`. Whenever a version is updated, the install guide in this repo's README.md MUST be updated to that release version in the same change — no old version constraints may linger in README install snippets. Dependency constraints on `zuraffa` itself must move to `^<version>` in the same bump.

## Child packages: independent patch releases (allowed)

A **child package may ship on its own** without a fleet-wide bump. The core
bump and the child bump are different operations, and both are legitimate:

- **Child fix, no core change** — `zuraffa_notifications` 7.4.2 → 7.4.3 alone:
  ```bash
  ./scripts/publish_fleet.sh 7.4.3 --only zuraffa_notifications
  ```
  The version defaults to the core's own `version:` when omitted, so
  `--only zuraffa_notifications` is enough. An unknown package name is a hard
  error, never a silent no-op.
- **Core change** — the whole fleet moves together, and the core bump **satisfies
  every child already published**: a child on 7.4.3 depending on
  `zuraffa: ^7.4.3` is compatible with a fleet at 7.5.0, because a caret range
  admits any `>=7.4.3 <8.0.0`.

**Rule of thumb:** a child follows the **current minor line** (7.4.x). Do not
jump a child to 7.5.0 on its own — leave that to the fleet bump, which is what
makes one core version satisfy all children at once. If a child genuinely needs
a breaking change, that IS a core bump; take the whole fleet.

**Do not run `update_fleet.sh` for a child-only release.** It mono-versions
every repo, which is exactly what a single-package fix must not do.

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
- **Publish**: `./scripts/publish_fleet.sh <version> [--dry-run-only] [--only <pkgs>]` —
  publishes every fleet package topologically (Kahn order from a hardcoded
  inventory + edges), skipping anything already on pub.dev at the target
  version; gates each publish on fleet deps being resolvable at the target
  (pub.dev API + throwaway `dart pub get` probe); `--dry-run` validation
  errors abort, warnings tolerated; retries on rate limit. The
  `zuraffa_ffi` family publishes as a set (intra-family cycle → deferred
  resolvability gates). `--only <pkg…>` narrows the run to a subset (a single
  child shipping without a fleet bump — see "Child packages" above); an
  unknown name is a hard error. The version defaults to the core package's
  own `version:` when omitted.
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
- pub does NOT strip `dependency_overrides` from published archives, and
  publish_fleet.sh does not strip them either. `update_fleet.sh` adds dev-mode
  sibling overrides that DO land committed; BEFORE publishing, strip the
  sibling `path:` entries from every fleet pubspec (keep the `xml: 7.1.0`
  pin), commit as
  "build(fleet): strip sibling path overrides from the adapter pubspecs", and
  push. Reference: zuraffa_notifications cb06a07; the 7.3.8 archives on
  pub.dev still carry the pollution, verified 2026-11-11.
- Workspace members must never carry `dependency_overrides`: a pub workspace
  shares one resolution governed by its root, and a member with its own
  override makes `dart pub publish` in the member fail with
  "overridden in both" (bit the zuraffa_ffi family during the 7.4.1 release).
- Per-repo pre-publish compile gate: a repo may carry an executable
  `scripts/prepublish_compile_gate.sh`; publish_fleet.sh runs it once before
  that repo's first package publishes and aborts the fleet run on failure.
  First user: zuraffa_notifications (`flutter build macos --release` of the
  example) — a resolvability gate cannot catch native Swift that never
  compiles (#6, then #15 / zuraffa#2063).
- Split default branch (e.g. zuraffa_notifications: default `main`, pool PRs
  targeting `master`): unify before publishing — merge the alignment into
  the PR branch and fast-forward the default to the same commit, or the fix
  lands on a branch the publish never sees.
- 7.4.1 released 2026-11-11: whole fleet (64 packages incl. `vendure`'s
  first publish) live at 7.4.1; `zuraffa_notifications_macos` 7.4.1 verified
  to carry the #15 Swift fix in the hosted archive.
