# Quickstart: `html_to_markdown_ffi` migration (spec 064)

**Feature**: specs/064-migrate-html-to-markdown-ffi · **Issue**: #687 (epic #214)

## 1. Baseline of the pre-migration package (offline, host)

```bash
cd ~/Developer/html_to_markdown_ffi && git status --short   # clean clone
dart pub get && dart analyze && dart test                    # all green pre-migration
```

Expected: the 10 legacy test files pass on the macOS host via the bundled macos dylibs.

## 2. Scaffold a throwaway family (network; proves the generator)

```bash
cd "$(mktemp -d)" && zfa package create-plugin html_to_markdown_ffi \
  --description "…" --no-gate && ls html_to_markdown_ffi/packages
```

Expected: exactly `html_to_markdown_ffi`, `_android`, `_ios`, `_macos`, `_platform`, with
`arrrrny` repository stamps.

## 3. In-repo automated proof (fast, offline)

```bash
cd ~/Developer/zuraffa
dart test test/package_sdk/plugin_html_to_markdown_ffi_instance_test.dart
```

Expected: structural family + API-preservation behaviors green.

## 4. Family board (network; the delivered monorepo)

```bash
cd ~/Developer/html_to_markdown_ffi
for pkg in packages/*/; do (cd "$pkg" \
  && dart pub get && dart analyze --no-fatal-warnings \
  && dart test && dart pub publish --dry-run) || echo "FAILED: $pkg"; done
```

Expected: no `FAILED` lines. The app package's board run exercises the ported legacy suite
against the real macos dylib through the macos adapter (dev-only sibling override).

## 5. Publish (explicit user goal)

```bash
cd ~/Developer/html_to_markdown_ffi
./scripts/prepare_for_publish.sh 1.2.0
git push origin publish-1.2.0
bash scripts/publish.sh        # app → platform → android → ios → macos
bash scripts/push_to_master.sh -f
```

Expected: five published releases on pub.dev; repo master tagged.

## Prerequisites

- Dart SDK ≥ 3.11 on PATH; `zfa` at the 064-era checkout (rebuild via `scripts/rebuild.sh`).
- pub.dev uploader credentials for `arrrrny` (logged in via `dart pub publish` / `flutter pub publish`).
- `gh` CLI authenticated for the master push.
