import 'dart:io';

import 'package:path/path.dart' as p;

import '../version.dart';
import 'package_scaffold.dart';
import 'plugin_family_names.dart';

export 'plugin_family_names.dart' show PluginFamilyNames, PluginPlatform;

/// Result of a successful federated-plugin scaffold.
class PluginScaffoldResult {
  const PluginScaffoldResult({
    required this.rootPath,
    required this.packagePaths,
    required this.createdFiles,
  });

  /// Absolute path of the created monorepo root.
  final String rootPath;

  /// Absolute paths of every created package, publish order
  /// (app-facing package first, platform core, then adapters).
  final List<String> packagePaths;

  /// Paths relative to the monorepo root of every file written.
  final List<String> createdFiles;
}

/// Scaffolds a publish-ready federated plugin monorepo (issue #1604).
///
/// `zfa package create-plugin <name>` delegates here. The shape follows
/// the house convention established by `zuraffa_auth` and
/// `zuraffa_permissions`:
///
/// ```text
/// <name>/
/// ├── README.md                          # monorepo table
/// ├── LICENSE                            # MIT
/// ├── CHANGELOG.md                       # root release notes (publish prep reads it)
/// ├── PUBLISH.md                         # publish-manager configuration
/// ├── scripts/                           # the zikzak publish pipeline
/// ├── specs/                             # spec-driven development records
/// └── packages/
///     ├── <name>                         # app-facing: Port + Service + register
///     ├── <name>_platform                # shared channel-envelope core
///     └── <name>_<platform>/…            # one adapter per --platforms entry
/// ```
///
/// Every package resolves, analyzes, and tests green with zero manual
/// edits, and the app-facing package passes `dart pub publish --dry-run`.
/// Native code stays out of the repo by design: adapters speak over an
/// *injected* `ChannelInvoke` seam, so the packages are pure Dart and the
/// consuming app (or a later native shell) wires the transport.
///
/// Templates are raw strings with `@@TOKEN@@` placeholders — no Dart
/// interpolation — so generated bash and generated Dart carry their own
/// `$` characters verbatim through one `_render` pass.
class PluginScaffold {
  static final RegExp _validName = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Scaffold dependency versions — aligned with `PackageScaffold` and the
  /// published zuraffa release the family currently targets.
  static const String _lintsConstraint = '^4.0.0';
  static const String _testConstraint = '^1.25.0';
  static const String _sdkConstraint = '^3.11.0';
  static const String _repoOwner = 'arrrrny';
  static const String _licenseHolder = 'Ahmet TOK';
  static const String _initialVersion = '0.1.0';

  /// Creates the federated plugin monorepo [name] under [outputParent].
  ///
  /// - [platforms] selects the adapter packages (normalized to android,
  ///   ios, macos order regardless of input order).
  /// - [description] lands in every pubspec + the root README.
  /// - [repository] overrides the GitHub `owner/name` slug stamped into
  ///   every package's `repository`/`issue_tracker` metadata (FR-012);
  ///   defaults to `arrrrny/<name>`.
  /// - [zuraffaPath], when given, resolves zuraffa from a local checkout
  ///   via `dependency_overrides` while the hosted constraint stays
  ///   declared — dev-only resolution that never leaks into a release
  ///   (FR-006, FR-013).
  /// - [dryRun] reports what would be written without touching the disk.
  ///
  /// Throws [PackageScaffoldException] (same contract as `zfa package
  /// create`) for invalid names, an empty platform list, or an existing
  /// target directory — nothing is ever overwritten.
  Future<PluginScaffoldResult> create({
    required String name,
    required String outputParent,
    required List<PluginPlatform> platforms,
    String? description,
    String? repository,
    String? zuraffaPath,
    bool dryRun = false,
  }) async {
    if (!_validName.hasMatch(name)) {
      throw PackageScaffoldException(
        'Invalid package name: "$name". '
        'Use snake_case (lowercase letters, digits, underscores), '
        'starting with a letter.',
      );
    }
    if (platforms.isEmpty) {
      throw PackageScaffoldException(
        'At least one platform is required (--platforms android,ios,macos).',
      );
    }
    // Normalize to family order (android, ios, macos) regardless of the
    // caller's input order — publish order and the README's platform
    // example must be stable for library callers too, not just for the
    // CLI (whose `platformsFromCsv` already returns enum order).
    platforms = PluginPlatform.values.where(platforms.contains).toList();
    if (zuraffaPath != null && !Directory(zuraffaPath).existsSync()) {
      throw PackageScaffoldException(
        'Invalid --zuraffa-path: "$zuraffaPath" is not a directory.',
      );
    }

    final rootPath = p.join(outputParent, name);
    if (Directory(rootPath).existsSync()) {
      throw PackageScaffoldException(
        'Cannot create plugin "$name": directory already exists at '
        '"${Directory(rootPath).absolute.path}". '
        'Choose a different name or remove the existing directory '
        '(the scaffold never overwrites existing content).',
      );
    }

    // Publish order: app-facing package first (every sibling declares it
    // hosted), then the shared envelope core, then the adapters.
    final family = PluginFamilyNames(name, platforms);
    final packageNames = family.packageNames;

    final repoSlug = repository ?? '$_repoOwner/$name';
    final repoUrl = 'https://github.com/$repoSlug';
    final effectiveDescription = _singleLine(
      description ??
          '${family.appPascal} support for the Zuraffa ecosystem: a pure-Dart '
              'port behind an injected platform channel with federated adapters.',
    );
    // The hosted constraint is always declared; a local checkout resolves
    // through dependency_overrides instead, so dev-only path resolution
    // never leaks into a publish (FR-006, FR-013).
    final zuraffaDep = '  zuraffa: ^$version';
    final zuraffaPathEntry = (zuraffaPath != null)
        ? '  zuraffa:\n    path: $zuraffaPath\n'
        : '';
    final appOverrides = (zuraffaPath != null)
        ? 'dependency_overrides:\n'
              '  # Local development only — resolve zuraffa to this checkout;\n'
              '  # stripped on publish.\n'
              '$zuraffaPathEntry'
        : '';

    final tokens = <String, String>{
      '@@PKG@@': name,
      '@@NOUN@@': family.noun,
      '@@PASCAL@@': family.appPascal,
      '@@DESC@@': effectiveDescription,
      // The custom --description, kept separate from @@DESC@@ so the
      // adapters can tell "author chose this text" from "use the
      // per-platform default sentence".
      '@@CUSTOM_DESC@@': _singleLine(description ?? ''),
      '@@REPO@@': repoUrl,
      '@@ZURAFFA_DEP@@': zuraffaDep,
      '@@APP_OVERRIDES@@': appOverrides,
      '@@ZURAFFA_PATH_ENTRY@@': zuraffaPathEntry,
      '@@CORE_DESC@@':
          description ??
          'Shared channel-envelope core for the $name platform adapters: '
              'decode, typed-error plumbing, and timeout policy over an '
              'injected platform channel.',
      '@@TOPICS@@': _topicsYaml(_topicsFor(family.noun)),
      '@@PKGS@@': packageNames.map((pkg) => '"$pkg"').join(' '),
      '@@FAMILY_SEDS@@': _familyConstraintSeds(name),
      '@@ADAPTERS@@': platforms.map((platform) => platform.label).join(', '),
      '@@PACKAGE_TABLE@@': _packageTable(name, platforms),
      '@@INITIAL_VERSION@@': _initialVersion,
      '@@HOLDER@@': _licenseHolder,
      '@@PLATFORM_EXAMPLE@@': platforms.first.classPrefix,
      '@@PUBLISH_ORDER@@': [
        for (var i = 0; i < packageNames.length; i++)
          '${i + 1}. `${packageNames[i]}`',
      ].join('\n'),
    };

    final files = <String, String>{
      'README.md': _render(_rootReadmeTemplate, tokens),
      'LICENSE': _render(_licenseTemplate, tokens),
      'CHANGELOG.md': _render(_rootChangelogTemplate, tokens),
      'PUBLISH.md': _render(_publishMdTemplate, tokens),
      '.gitignore': _render(_rootGitignoreTemplate, tokens),
      p.join('specs', 'README.md'): _render(_specsReadmeTemplate, tokens),
      p.join('scripts', 'prepare_for_publish.sh'): _render(
        _prepareForPublishTemplate,
        tokens,
      ),
      p.join('scripts', 'publish.sh'): _render(_publishTemplate, tokens),
      p.join('scripts', 'push_to_master.sh'): _render(
        _pushToMasterTemplate,
        tokens,
      ),
      p.join('scripts', 'restore_dev_setup.sh'): _render(
        _restoreDevSetupTemplate,
        tokens,
      ),
      p.join('scripts', 'revert_publish_changes.sh'): _render(
        _revertPublishChangesTemplate,
        tokens,
      ),
      // App-facing package.
      ..._appPackageFiles(tokens),
      // Platform (envelope core) package.
      ..._platformPackageFiles(tokens),
      // Adapter packages.
      for (final platform in platforms)
        ..._adapterPackageFiles(tokens, platform: platform),
    };

    final created = <String>[];
    if (dryRun) {
      created.addAll(files.keys);
      return PluginScaffoldResult(
        rootPath: rootPath,
        packagePaths: [
          for (final packageName in packageNames)
            p.join(rootPath, 'packages', packageName),
        ],
        createdFiles: created,
      );
    }

    final dirs = <String>{
      rootPath,
      p.join(rootPath, 'scripts'),
      p.join(rootPath, 'specs'),
      for (final packageName in packageNames) ...[
        p.join(rootPath, 'packages', packageName),
        p.join(rootPath, 'packages', packageName, 'lib', 'src'),
        p.join(rootPath, 'packages', packageName, 'test'),
      ],
    };
    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }
    for (final entry in files.entries) {
      final file = File(p.join(rootPath, entry.key));
      await file.create(recursive: true);
      await file.writeAsString(entry.value);
      created.add(entry.key);
    }
    if (!Platform.isWindows) {
      for (final script in const [
        'prepare_for_publish.sh',
        'publish.sh',
        'push_to_master.sh',
        'restore_dev_setup.sh',
        'revert_publish_changes.sh',
      ]) {
        await Process.run('chmod', ['+x', p.join(rootPath, 'scripts', script)]);
      }
    }

    return PluginScaffoldResult(
      rootPath: rootPath,
      packagePaths: [
        for (final packageName in packageNames)
          p.join(rootPath, 'packages', packageName),
      ],
      createdFiles: created,
    );
  }

  /// Parses a `--platforms` CSV into the platform set. Whitespace is
  /// tolerated; empty input and unknown names are operator-fixable errors
  /// naming the supported set (FR-005, FR-010). Shared by the
  /// `package plugin` command so the engine owns the whole contract.
  static Set<PluginPlatform> platformsFromCsv(String csv) {
    final names = csv
        .split(',')
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toSet();
    if (names.isEmpty) {
      throw PackageScaffoldException(
        'No platforms selected. '
        'Supported: ${PluginPlatform.values.map((p) => p.dirSuffix).join(', ')}.',
      );
    }
    final unknown = names
        .where(
          (name) => PluginPlatform.values.every((p) => p.dirSuffix != name),
        )
        .toList();
    if (unknown.isNotEmpty) {
      throw PackageScaffoldException(
        'Unknown platform(s): ${unknown.join(", ")}. '
        'Supported: ${PluginPlatform.values.map((p) => p.dirSuffix).join(", ")}.',
      );
    }
    return {
      for (final platform in PluginPlatform.values)
        if (names.contains(platform.dirSuffix)) platform,
    };
  }

  /// Pub topics: the noun plus house topics. Underscores become hyphens
  /// (pub.dev rejects underscores in topics).
  List<String> _topicsFor(String noun, {PluginPlatform? platform}) => [
    noun.replaceAll('_', '-'),
    if (platform != null) platform.dirSuffix,
    'clean-architecture',
    'zuraffa',
  ];

  String _topicsYaml(List<String> topics) =>
      'topics:\n'
      '${topics.map((topic) => '  - $topic').join('\n')}\n';

  String _singleLine(String text) => text.replaceAll('\n', ' ');

  /// The sed lines every family pubspec gets during a version bump: the
  /// app-facing constraint and the platform-core constraint are aligned to
  /// the release version wherever they appear (hosted in-family deps).
  ///
  /// `-i.bak` is the in-place form BSD and GNU sed both accept (bare
  /// `-i ''` is the macOS spelling; GNU sed reads the empty string as the
  /// script and dies) — the same portable form the repo's pipeline tests
  /// pin. The backup is removed after each rewrite.
  String _familyConstraintSeds(String name) {
    final lines = StringBuffer();
    for (final familyPkg in [name, '${name}_platform']) {
      lines.write(
        "    sed -i.bak -E \"/^( *$familyPkg: \\^)/s|.*|  $familyPkg: ^\$VERSION|\" \"\$pubspec\" && rm -f \"\$pubspec.bak\"\n",
      );
    }
    return lines.toString();
  }

  String _packageTable(String name, List<PluginPlatform> platforms) {
    final pascalNoun = PluginFamilyNames(name).appPascal;
    final rows = <String>[
      '| [`packages/$name`](packages/$name/) | App-facing package: `${pascalNoun}Port`, `${pascalNoun}Service`, typed failures + DI registration |',
      '| [`packages/${name}_platform`](packages/${name}_platform/) | Shared channel-envelope core over an injected platform channel |',
      for (final platform in platforms)
        '| [`packages/${name}_${platform.dirSuffix}`](packages/${name}_${platform.dirSuffix}/) | ${platform.label} adapter (typed taxonomy over the injected channel) |',
    ];
    return rows.join('\n');
  }

  String _render(String template, Map<String, String> tokens) {
    var out = template;
    for (final entry in tokens.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    // Templates open with a newline for readability; generated files start
    // with content.
    if (out.startsWith('\n')) out = out.substring(1);
    return out;
  }

  // ─────────────────────────────────────────────────────────────────
  // Root templates
  // ─────────────────────────────────────────────────────────────────

  static const String _rootReadmeTemplate = r'''
# @@PKG@@ — monorepo

@@DESC@@

Built on the [Zuraffa](https://pub.dev/packages/zuraffa) framework as part
of the zuraffa-native package family (EPIC #214).

## Packages

| Package | Description |
| --- | --- |
@@PACKAGE_TABLE@@

Publish from each package directory (`packages/<name>`); the federated
siblings depend on each other via hosted dependencies — see
[`PUBLISH.md`](PUBLISH.md) and `scripts/` for the publish pipeline.

See [`specs/`](specs/) for the spec-driven development records.

Repository: @@REPO@@
''';

  static const String _licenseTemplate = r'''
MIT License

Copyright (c) 2026 @@HOLDER@@

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

  static const String _rootChangelogTemplate = r'''
# Changelog

## @@INITIAL_VERSION@@

- Initial federated scaffold for `@@PKG@@` (EPIC #214 migration): the
  app-facing package, the shared `@@PKG@@_platform` envelope core, and the
  @@ADAPTERS@@ adapters.
''';

  static const String _packageChangelogTemplate = r'''
# Changelog

## @@INITIAL_VERSION@@

- Initial scaffold as part of the `@@PKG@@` federated monorepo (EPIC #214).
''';

  static const String _rootGitignoreTemplate = r'''
.dart_tool/
build/
coverage/
pubspec.lock
.DS_Store
''';

  static const String _specsReadmeTemplate = r'''
# Specs

Spec-driven development records live here, one folder per feature
(`NNNN-slug/spec.md`), matching the zuraffa house workflow.
''';

  static const String _publishMdTemplate = r'''
# Publish Configuration for `@@PKG@@`

<!-- Managed with the publish-manager skill. Edit if the workflow changes. -->

## Package Manager

- **Type**: `pub.dev`
- **Packages** (in publish order — the app package first; the platform core
  and the federated adapters declare their in-family dependencies hosted):
@@PUBLISH_ORDER@@
- **All packages are public**

## Scripts

- **Pre-publish**: `./scripts/prepare_for_publish.sh <version> [-f]` — creates the `publish-<version>` branch, bumps all package versions + in-family constraints, resolves the changelog (root CHANGELOG entry first, git-history generation as fallback), checks pub.dev status + stray path deps, commits. Asks for a commit message on a TTY; `-f` (or automation) takes the default
- **Publish**: `./scripts/publish.sh` — per package in order: skips already-published, waits until every in-family dependency is on pub.dev AND pub-resolvable, then pub get → format → analyze → dry-run → publish; tags the release at the end (needs dart on PATH)
- **Post-publish**: `./scripts/push_to_master.sh [-f]` — merges the publish branch to master, tags, pushes; `-f` auto-commits dirty trees and deletes the branch
- **Restore dev**: `./scripts/restore_dev_setup.sh` — re-links the whole family via `dependency_overrides` (dev-only; pub strips overrides on publish)
- **Revert**: `./scripts/revert_publish_changes.sh` — abandons a publish: back to master, deletes the publish branch, restores dev setup (interactive)

## Workflow

### Automated (single command — no prompts)

```bash
bash scripts/prepare_for_publish.sh <version> -f && \
  git push origin "publish-$(grep '^version:' packages/@@PKG@@/pubspec.yaml | sed 's/version: //' | tr -d '[:space:]')" && \
  bash scripts/publish.sh && \
  bash scripts/push_to_master.sh -f
```

⚠️ `publish.sh` needs a 20–30 min timeout: every in-family dependency is
waited on until it is not just API-visible but actually resolvable by pub.

### Manual

1. Write the release notes as a `## <version>` entry in the root `CHANGELOG.md` (or let the prep script generate them from git history)
2. `./scripts/prepare_for_publish.sh <version>`
3. `git push origin publish-<version>`
4. `bash scripts/publish.sh`
5. `bash scripts/push_to_master.sh -f`

## Notes

- Sibling `dependency_overrides` never need converting: pub strips them when publishing. `restore_dev_setup.sh` re-links the family for local development.
- Sibling packages fail `dart pub publish --dry-run` until their hosted in-family dependencies exist on pub.dev — publish in order; `publish.sh` waits for each one and verifies resolvability, not just API presence.
- pub.dev's new-package rate limit can block first publishes of a whole family at once — re-run `publish.sh` later; it is idempotent.
''';

  // ─────────────────────────────────────────────────────────────────
  // Publish pipeline templates (the zikzak_inappwebview pipeline)
  // ─────────────────────────────────────────────────────────────────

  static const String _prepareForPublishTemplate = r'''
#!/bin/bash
set -e
# Generated by `zfa package create-plugin` — the zikzak_inappwebview publish
# pipeline (issue #1621): version auto-detect, dated changelog entries with
# git-history fallback, pub.dev status summary, path-dependency check, and a
# commit message prompt. -f/--force (or any non-interactive shell) skips the
# prompts with defaults.

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

FORCE=false
VERSION=""
for arg in "$@"; do
    case "$arg" in
        -f|--force) FORCE=true ;;
        *) VERSION="$arg" ;;
    esac
done
if [ -z "$VERSION" ]; then
    APP_PUBSPEC="$(cd "$(dirname "$0")/.." >/dev/null 2>&1; pwd -P)/packages/@@PKG@@/pubspec.yaml"
    VERSION=$(grep "^version:" "$APP_PUBSPEC" 2>/dev/null | sed 's/version: //' | tr -d '[:space:]')
    [ -z "$VERSION" ] && { echo -e "${RED}Usage: $0 <version> [-f]${NC}"; exit 1; }
    echo -e "${GREEN}Detected version from @@PKG@@: $VERSION${NC}"
fi
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Version must be semver (X.Y.Z)${NC}"; exit 1
fi
BRANCH="publish-$VERSION"

git diff --quiet || { echo -e "${RED}Working tree is dirty - commit or stash first.${NC}"; exit 1; }
git checkout -b "$BRANCH" 2>/dev/null || { echo -e "${RED}Branch $BRANCH already exists${NC}"; exit 1; }
echo -e "${GREEN}Created branch $BRANCH${NC}"

# Bump every package version and align in-family constraints to ^VERSION.
# -i.bak is the in-place form BSD and GNU sed both accept (bare -i '' is
# macOS-only; GNU sed dies on it).
for pkg in @@PKGS@@; do
    pubspec="packages/$pkg/pubspec.yaml"
    sed -i.bak -E "s/^version: .*/version: $VERSION/" "$pubspec" && rm -f "$pubspec.bak"
@@FAMILY_SEDS@@    echo -e "${BLUE}$pkg -> $VERSION (in-family deps ^$VERSION)${NC}"
done

# Changelog content: the root CHANGELOG.md entry for this version is the
# single source of truth. With none, generate one from git history since the
# last tag (Feature/Change/Fix grouping) and prepend it to the root
# CHANGELOG so it stays the source of truth.
ENTRY=$(awk -v v="$VERSION" 'BEGIN{p=0} /^## /{{if (p) exit} if ($0 ~ "^## " v) p=1} p{{print}}' CHANGELOG.md 2>/dev/null || true)
if [ -z "$ENTRY" ]; then
    echo -e "${BLUE}No root CHANGELOG entry for $VERSION - generating from git history...${NC}"
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
    if [ -n "$LAST_TAG" ]; then
        LOGS=$(git log --pretty=format:"%s" "$LAST_TAG..HEAD")
    else
        LOGS=$(git log --pretty=format:"%s")
    fi
    FEATURES=$(echo "$LOGS" | grep -i "^feat" | sed 's/^/* /' || true)
    CHANGES=$(echo "$LOGS" | grep -i "^change\|^refactor\|^perf" | sed 's/^/* /' || true)
    FIXES=$(echo "$LOGS" | grep -i "^fix" | sed 's/^/* /' || true)
    ENTRY=$(printf '%s\n%s\n%s' "$FEATURES" "$CHANGES" "$FIXES" | sed '/^[[:space:]]*$/d')
    [ -z "$ENTRY" ] && ENTRY=$(echo "$LOGS" | sed 's/^/* /' | sed '/^[[:space:]]*$/d')
    [ -z "$ENTRY" ] && ENTRY="* Prepare for publishing version $VERSION"
    printf '## %s - %s\n\n%s\n\n' "$VERSION" "$(date +%Y-%m-%d)" "$ENTRY" \
        | cat - CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
fi

# Propagate the entry into every package CHANGELOG as a dated entry.
RELEASE_DATE=$(date +%Y-%m-%d)
for pkg in @@PKGS@@; do
    f="packages/$pkg/CHANGELOG.md"
    grep -q "^## $VERSION" "$f" && continue
    printf '## %s - %s\n\n%s\n\n' "$VERSION" "$RELEASE_DATE" "$ENTRY" \
        | cat - "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

# Publication status summary (tolerates being offline).
echo -e "${BLUE}=== Publication status on pub.dev ===${NC}"
for pkg in @@PKGS@@; do
    if curl -s "https://pub.dev/api/packages/$pkg" | grep -q "\"$VERSION\""; then
        echo -e "  $pkg $VERSION: ${RED}already published${NC}"
    else
        echo -e "  $pkg $VERSION: ${GREEN}ready to publish${NC}"
    fi
done

# Path-dependency check: dependency_overrides entries are the dev-only
# local-resolution seam (pub strips them on publish) and are expected; a
# path dep OUTSIDE the overrides section would leak into the release.
echo -e "${BLUE}=== Path-dependency check (overrides excluded) ===${NC}"
PATH_PROBLEMS=0
for pkg in @@PKGS@@; do
    HITS=$(awk '/^dependency_overrides:/{skip=1; next} /^[^[:space:]]/{skip=0} !skip && /path:/{print}' "packages/$pkg/pubspec.yaml")
    if [ -n "$HITS" ]; then
        echo -e "${RED}$pkg has path dependencies outside dependency_overrides:${NC}"
        echo "$HITS"
        PATH_PROBLEMS=1
    fi
done
if [ "$PATH_PROBLEMS" = "1" ]; then
    echo -e "${RED}Fix the path dependencies above before publishing.${NC}"
    exit 1
fi
echo -e "${GREEN}No stray path dependencies.${NC}"

# Commit message: prompted on a TTY, defaulted under -f / automation.
COMMIT_MESSAGE=""
if [ "$FORCE" = false ] && [ -t 0 ]; then
    echo -e "${YELLOW}Commit message (default: 'Prepare for publishing version $VERSION'):${NC}"
    read -r COMMIT_MESSAGE || COMMIT_MESSAGE=""
fi
[ -z "$COMMIT_MESSAGE" ] && COMMIT_MESSAGE="Prepare for publishing version $VERSION"

git add -A
git commit -q -m "$COMMIT_MESSAGE" -m "$ENTRY"
echo -e "${GREEN}Committed publish prep for $VERSION on $BRANCH.${NC}"
echo "Next: bash scripts/publish.sh (allow 20-30 min for pub.dev propagation)"
echo "Abandon this publish: ./scripts/revert_publish_changes.sh"
''';

  static const String _publishTemplate = r'''
#!/bin/bash
set -e
# Generated by `zfa package create-plugin` — the zikzak_inappwebview publish
# pipeline (issue #1621): dependency-order publishing where every in-family
# dependency is verified not just API-visible but actually pub-resolvable
# from a clean harness before the dependent publishes, then format/analyze/
# dry-run/publish per package, and the release tag is pushed at the end.
# Needs dart on PATH.

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

PACKAGES_IN_ORDER=(@@PKGS@@)
FAMILY_PREFIX="@@PKG@@"
ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1; pwd -P)"
MAX_RETRIES=30
RETRY_INTERVAL=20

on_pub_dev() {
    local pkg=$1 version=$2
    curl -s "https://pub.dev/api/packages/$pkg" | grep -q "\"$version\""
}

# API-visible is not resolvable: verify pub can actually resolve the
# dependency from a clean harness (no dependency_overrides in play).
verify_resolvable() {
    local pkg=$1 version=$2
    local harness
    harness=$(mktemp -d)
    cat > "$harness/pubspec.yaml" <<EOF
name: resolution_probe
version: 1.0.0

environment:
  sdk: ^3.0.0

dependencies:
  $pkg: ^$version
EOF
    if (cd "$harness" && dart pub get >/dev/null 2>&1); then
        rm -rf "$harness"
        return 0
    fi
    rm -rf "$harness"
    return 1
}

# Wait until every in-family dependency of $1 is on pub.dev AND resolvable.
wait_for_family_deps() {
    local pkg=$1
    local deps version retry
    deps=$(awk -v prefix="$FAMILY_PREFIX" \
        '/^dependency_overrides:/{skip=1; next} /^dependencies:/{in_deps=1; next} in_deps && /^[^[:space:]]/{in_deps=0} in_deps && $1 ~ "^"prefix {gsub(":", "", $1); print $1}' \
        "$ROOT_DIR/packages/$pkg/pubspec.yaml")
    [ -z "$deps" ] && return 0
    version=$(grep "^version:" "$ROOT_DIR/packages/$pkg/pubspec.yaml" | sed 's/version: //' | tr -d '[:space:]')
    for dep in $deps; do
        [ "$dep" = "$pkg" ] && continue
        retry=0
        while :; do
            if on_pub_dev "$dep" "$version" && verify_resolvable "$dep" "$version"; then
                echo -e "${GREEN}$dep $version is live and resolvable.${NC}"
                break
            fi
            retry=$((retry + 1))
            if [ "$retry" -ge "$MAX_RETRIES" ]; then
                echo -e "${RED}$dep $version never became resolvable - publish it first.${NC}"
                return 1
            fi
            echo -e "${YELLOW}Waiting for $dep to propagate ($retry/$MAX_RETRIES)...${NC}"
            sleep "$RETRY_INTERVAL"
        done
    done
}

publish_package() {
    local pkg=$1
    local version
    version=$(grep "^version:" "$ROOT_DIR/packages/$pkg/pubspec.yaml" | sed 's/version: //' | tr -d '[:space:]')
    echo -e "${BLUE}=== Publishing $pkg $version ===${NC}"

    if on_pub_dev "$pkg" "$version"; then
        echo -e "${GREEN}$pkg $version is already on pub.dev - nothing to do.${NC}"
        return 0
    fi

    if ! wait_for_family_deps "$pkg"; then
        echo -e "${RED}Cannot publish $pkg yet.${NC}"
        return 1
    fi

    cd "$ROOT_DIR/packages/$pkg"

    echo -e "${BLUE}Final resolution check: dart pub get...${NC}"
    dart pub get || { echo -e "${RED}pub get failed for $pkg${NC}"; return 1; }

    echo -e "${BLUE}Formatting lib/ and test/...${NC}"
    dart format lib test >/dev/null

    echo -e "${BLUE}Analyzing...${NC}"
    dart analyze || { echo -e "${RED}Analyze failed for $pkg${NC}"; return 1; }

    echo -e "${BLUE}Dry-run...${NC}"
    dart pub publish --dry-run || { echo -e "${RED}Dry-run failed for $pkg${NC}"; return 1; }

    echo -e "${YELLOW}Publishing $pkg $version to pub.dev...${NC}"
    dart pub publish --force || { echo -e "${RED}Publish failed for $pkg${NC}"; return 1; }
    echo -e "${GREEN}$pkg $version published.${NC}"
}

for pkg in "${PACKAGES_IN_ORDER[@]}"; do
    publish_package "$pkg" || { echo -e "${RED}Publication stopped at $pkg.${NC}"; exit 1; }
done

# Tag the release (idempotent).
VERSION=$(grep "^version:" "$ROOT_DIR/packages/$FAMILY_PREFIX/pubspec.yaml" | sed 's/version: //' | tr -d '[:space:]')
if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
    echo -e "${YELLOW}Tag $VERSION already exists.${NC}"
else
    git tag "$VERSION" && git push origin "$VERSION" 2>/dev/null \
        || echo -e "${YELLOW}Tag $VERSION created; push it with: git push origin $VERSION${NC}"
fi

echo -e "${GREEN}All packages published.${NC}"
echo -e "${BLUE}Next: merge the publish branch - ./scripts/push_to_master.sh (or -f)${NC}"
''';

  static const String _pushToMasterTemplate = r'''
#!/bin/bash
set -e
# Generated by `zfa package create-plugin` — the zikzak_inappwebview publish
# pipeline (issue #1621): merges the publish branch into master, tags, and
# pushes. -f/--force runs non-interactively: dirty trees are auto-committed
# with the default message and the publish branch is deleted afterwards.

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

FORCE=false
if [ "$1" = "-f" ] || [ "$1" = "--force" ]; then
    FORCE=true
fi

BRANCH=$(git branch --list 'publish-*' --format '%(refname:short)' | head -1)
[ -z "$BRANCH" ] && { echo -e "${RED}No publish-* branch found${NC}"; exit 1; }
VERSION=${BRANCH#publish-}
echo -e "${BLUE}Publish branch: $BRANCH (version $VERSION)${NC}"

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    if [ "$FORCE" = true ]; then
        git add -A
        git commit -q -m "Prepare for publishing version $VERSION"
        echo -e "${YELLOW}Force mode: committed the dirty tree.${NC}"
    else
        echo -e "${RED}Working tree is dirty - commit or stash first (or use -f).${NC}"
        exit 1
    fi
fi

if [ "$FORCE" = false ]; then
    read -r -p "Merge $BRANCH into master, tag $VERSION and push? [y/N] " a || a=""
    [[ "$a" != [yY]* ]] && exit 0
fi

git rev-list master.."$BRANCH" | grep -q . || {
    echo -e "${RED}$BRANCH has no commits beyond master - nothing to merge.${NC}"
    exit 1
}

git checkout master
if git remote | grep -q "^origin"; then
    git pull origin master || echo -e "${YELLOW}Pull from origin failed - continuing with the local merge.${NC}"
fi
git merge --no-ff "$BRANCH" -m "Merge publish-$VERSION into master" || {
    echo -e "${RED}Merge conflict. Resolve it, then: git add -A && git commit && git push origin master${NC}"
    exit 1
}
git tag "$VERSION" 2>/dev/null || echo -e "${YELLOW}Tag $VERSION already exists.${NC}"
git push origin master --tags
if [ "$FORCE" = true ]; then
    git branch -d "$BRANCH"
    git push origin --delete "$BRANCH" 2>/dev/null || true
fi
echo -e "${GREEN}Publish $VERSION merged to master and tagged.${NC}"
''';

  static const String _restoreDevSetupTemplate = r'''
#!/bin/bash
set -e
# Generated by `zfa package create-plugin` — restores full dev interlink
# (issue #1621): every package gets a dependency_overrides section pointing
# at every OTHER family package, so the whole family resolves from this
# checkout. Pub strips overrides on publish, so this is dev-only state; the
# hosted constraints in `dependencies:` stay untouched (FR-006/FR-013).

GREEN='\033[0;32m'; NC='\033[0m'
PACKAGES=(@@PKGS@@)
ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1; pwd -P)"
cd "$ROOT_DIR"

for pkg in "${PACKAGES[@]}"; do
    pubspec="packages/$pkg/pubspec.yaml"
    [ -f "$pubspec" ] || continue

    # Drop any existing overrides section, then append a fresh one covering
    # every other family package.
    tmp="$pubspec.tmp"
    awk '/^dependency_overrides:/{skip=1; next} skip && /^[^[:space:]]/{skip=0} !skip{print}' "$pubspec" > "$tmp"
    {
        cat "$tmp"
        echo ""
        echo "dependency_overrides:"
        echo "  # Local development only - resolve the family to this checkout;"
        echo "  # stripped by pub on publish."
        for other in "${PACKAGES[@]}"; do
            [ "$other" = "$pkg" ] && continue
            echo "  $other:"
            echo "    path: ../$other"
        done
    } > "$pubspec"
    rm -f "$tmp"
    echo -e "${GREEN}Restored dev overrides in $pkg${NC}"
done

echo "Run \`dart pub get\` in each package to refresh resolution."
echo "Back to publish mode: ./scripts/prepare_for_publish.sh <version>"
''';

  static const String _revertPublishChangesTemplate = r'''
#!/bin/bash
set -e
# Generated by `zfa package create-plugin` — the zikzak_inappwebview publish
# pipeline's abort tool (issue #1621): leaves the publish branch, restores
# master, deletes the branch, and re-links the dev setup. Interactive on
# purpose — this discards work.

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}=== Publish revert ===${NC}"
echo -e "Current branch: ${YELLOW}$CURRENT_BRANCH${NC}"

if [[ "$CURRENT_BRANCH" != publish-* ]]; then
    echo -e "${RED}Not on a publish-* branch.${NC}"
    read -r -p "Continue anyway? [y/N] " proceed || proceed=""
    [[ "$proceed" != [yY]* ]] && exit 0
fi

read -r -p "Branch to return to (default: master): " target || target=""
[ -z "$target" ] && target="master"
if ! git show-ref --verify --quiet "refs/heads/$target"; then
    echo -e "${RED}Branch '$target' does not exist.${NC}"
    exit 1
fi

echo -e "${RED}This discards every change made for publishing on $CURRENT_BRANCH.${NC}"
read -r -p "Revert to '$target' and delete the publish branch? [y/N] " confirm || confirm=""
[[ "$confirm" != [yY]* ]] && { echo -e "${YELLOW}Aborted.${NC}"; exit 0; }

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    read -r -p "Discard uncommitted changes? [y/N] " discard || discard=""
    [[ "$discard" != [yY]* ]] && { echo -e "${YELLOW}Commit or stash first.${NC}"; exit 0; }
    git reset --hard HEAD
fi

git checkout "$target"
if [ "$CURRENT_BRANCH" != "$target" ]; then
    git branch -D "$CURRENT_BRANCH"
fi
./scripts/restore_dev_setup.sh
echo -e "${GREEN}Reverted to '$target'; dev setup restored.${NC}"
''';

  // ─────────────────────────────────────────────────────────────────
  // App-facing package templates
  // ─────────────────────────────────────────────────────────────────

  Map<String, String> _appPackageFiles(Map<String, String> tokens) {
    final name = tokens['@@PKG@@']!;
    final noun = tokens['@@NOUN@@']!;
    return {
      p.join('packages', name, 'pubspec.yaml'): _render(
        r'''
# Federated plugin monorepo created by `zfa package create-plugin` (issue #1604).
name: @@PKG@@
description: >-
  @@DESC@@
version: @@INITIAL_VERSION@@
homepage: https://zuraffa.com

environment:
  sdk: @@SDK@@

dependencies:
@@ZURAFFA_DEP@@

dev_dependencies:
  lints: @@LINTS@@
  test: @@TEST@@

@@APP_OVERRIDES@@repository: @@REPO@@
issue_tracker: @@REPO@@/issues

@@TOPICS@@''',
        {
          ...tokens,
          '@@SDK@@': _sdkConstraint,
          '@@LINTS@@': _lintsConstraint,
          '@@TEST@@': _testConstraint,
        },
      ),
      p.join('packages', name, 'analysis_options.yaml'): _analysisOptions(),
      p.join('packages', name, 'CHANGELOG.md'): _render(
        _packageChangelogTemplate,
        tokens,
      ),
      p.join('packages', name, 'README.md'): _render(r'''
# @@PKG@@

@@DESC@@

Part of the [@@PKG@@](@@REPO@@) federated monorepo, built on the
[Zuraffa](https://pub.dev/packages/zuraffa) framework.

## Use

```dart
final service = @@PASCAL@@Service(port: myPlatformPort);
final module = await service.compile(id: 'demo', bytes: moduleBytes);
final results = await service.call(
    id: 'demo', export: 'run', args: [@@PASCAL@@I32(1)]);
await service.unload(id: 'demo');
```

Wire the platform adapter for the running platform first — e.g.
`register@@PLATFORM_EXAMPLE@@@@PASCAL@@Dependencies(getIt, channel: ...)` from
the adapter package — then resolve `@@PASCAL@@Service`, or call
`register@@PASCAL@@Dependencies(getIt, port: ...)` directly. Without a
wired port every call surfaces the typed `port_not_wired` failure.

## Develop

```bash
dart pub get
dart test
```
''', tokens),
      p.join('packages', name, 'LICENSE'): _render(_licenseTemplate, tokens),
      p.join('packages', name, 'lib', '$name.dart'): _render(r'''
/// @@PKG@@ — @@PASCAL@@ support for the Zuraffa ecosystem.
///
/// A pure-Dart port (`@@PASCAL@@Port`), a facade (`@@PASCAL@@Service`),
/// typed failures, and DI registration. Platform adapters implement the
/// port over an injected platform channel — the shared envelope machinery
/// lives in `@@PKG@@_platform`.
library;

export 'src/@@NOUN@@_exception.dart';
export 'src/@@NOUN@@_module.dart';
export 'src/@@NOUN@@_port.dart';
export 'src/@@NOUN@@_service.dart';
export 'src/@@NOUN@@_value.dart';
''', tokens),
      p.join('packages', name, 'lib', 'src', '${noun}_exception.dart'): _render(
        r'''
/// The typed failure surfaced by the @@PKG@@ port and service.
class @@PASCAL@@Exception implements Exception {
  final String code;
  final String message;
  final bool recoverable;

  const @@PASCAL@@Exception(
    this.code,
    this.message, {
    required this.recoverable,
  });

  @override
  String toString() =>
      '@@PASCAL@@Exception($code, recoverable: $recoverable): $message';
}
''',
        tokens,
      ),
      p.join('packages', name, 'lib', 'src', '${noun}_value.dart'): _render(
        _appValueTemplate,
        tokens,
      ),
      p.join('packages', name, 'lib', 'src', '${noun}_module.dart'): _render(
        _appModuleTemplate,
        tokens,
      ),
      p.join('packages', name, 'lib', 'src', '${noun}_port.dart'): _render(
        _appPortTemplate,
        tokens,
      ),
      p.join('packages', name, 'lib', 'src', '${noun}_service.dart'): _render(
        _appServiceTemplate,
        tokens,
      ),
      p.join('packages', name, 'test', '${noun}_service_test.dart'): _render(
        _appServiceTestTemplate,
        tokens,
      ),
      p.join('packages', name, 'test', '${noun}_value_test.dart'): _render(
        _appValueTestTemplate,
        tokens,
      ),
    };
  }

  static const String _appValueTemplate = r'''
import '@@NOUN@@_exception.dart';

/// A WebAssembly scalar value crossing the platform boundary.
///
/// The scaffold ships the four numeric types; the migration extends the
/// family (reference types, vectors) without breaking the contract.
sealed class @@PASCAL@@Value {
  const @@PASCAL@@Value();

  /// Encodes this value into the primitive representation transported over
  /// the platform channel. i64 travels as a decimal string — channel
  /// payloads cannot carry a BigInt losslessly.
  Object encode() => switch (this) {
        @@PASCAL@@I32(:final value) => value,
        @@PASCAL@@I64(:final value) => value.toString(),
        @@PASCAL@@F32(:final value) => value,
        @@PASCAL@@F64(:final value) => value,
      };

  /// Decodes a channel payload into a [@@PASCAL@@Value]: ints decode as
  /// i32, doubles as f64, and decimal strings as i64.
  static @@PASCAL@@Value decode(Object? raw) {
    if (raw is int) return @@PASCAL@@I32(raw);
    if (raw is double) return @@PASCAL@@F64(raw);
    if (raw is String) {
      final parsed = BigInt.tryParse(raw);
      if (parsed != null) return @@PASCAL@@I64(parsed);
    }
    throw @@PASCAL@@Exception(
      'malformed_value',
      'Cannot decode "$raw" into a @@PASCAL@@Value.',
      recoverable: false,
    );
  }
}

/// A 32-bit integer value.
class @@PASCAL@@I32 extends @@PASCAL@@Value {
  final int value;

  const @@PASCAL@@I32(this.value);
}

/// A 64-bit integer value (transported as a decimal string).
class @@PASCAL@@I64 extends @@PASCAL@@Value {
  final BigInt value;

  const @@PASCAL@@I64(this.value);
}

/// A 32-bit float value.
class @@PASCAL@@F32 extends @@PASCAL@@Value {
  final double value;

  const @@PASCAL@@F32(this.value);
}

/// A 64-bit float value.
class @@PASCAL@@F64 extends @@PASCAL@@Value {
  final double value;

  const @@PASCAL@@F64(this.value);
}
''';

  static const String _appModuleTemplate = r'''
/// A compiled WebAssembly module, bound to [id] inside the owning
/// engine/adapter until unloaded.
class @@PASCAL@@Module {
  final String id;
  final int byteLength;

  const @@PASCAL@@Module({required this.id, required this.byteLength});
}
''';

  static const String _appPortTemplate = r'''
import 'dart:typed_data';

import '@@NOUN@@_module.dart';
import '@@NOUN@@_value.dart';

/// The platform-neutral port every adapter implements. Pure Dart — the
/// transport is injected behind the platform envelope, so tests run
/// offline with fake channels.
abstract class @@PASCAL@@Port {
  const @@PASCAL@@Port();

  /// Whether the host platform can run WebAssembly at all.
  Future<bool> isSupported();

  /// Compiles [bytes] and binds the result to [id].
  Future<@@PASCAL@@Module> compile({
    required String id,
    required Uint8List bytes,
  });

  /// Invokes [export] on the compiled module [id].
  Future<List<@@PASCAL@@Value>> invoke({
    required String id,
    required String export,
    List<@@PASCAL@@Value> args = const [],
  });

  /// Releases the compiled module [id].
  Future<void> unload({required String id});
}
''';

  static const String _appServiceTemplate = r'''
import 'dart:typed_data';

import 'package:zuraffa/zuraffa.dart';

import '@@NOUN@@_exception.dart';
import '@@NOUN@@_module.dart';
import '@@NOUN@@_port.dart';
import '@@NOUN@@_value.dart';

/// Facade over the [@@PASCAL@@Port]: owns the compiled-module registry
/// and turns lifecycle mistakes (double compile, call-before-compile)
/// into typed failures before they reach the platform.
class @@PASCAL@@Service {
  final @@PASCAL@@Port port;
  final Map<String, @@PASCAL@@Module> _modules = {};

  @@PASCAL@@Service({required this.port});

  /// The compiled modules currently held by this service.
  Set<String> get compiledModules => Set.unmodifiable(_modules.keys);

  Future<bool> supported() => port.isSupported();

  Future<@@PASCAL@@Module> compile({
    required String id,
    required Uint8List bytes,
  }) async {
    if (_modules.containsKey(id)) {
      throw @@PASCAL@@Exception(
        'already_compiled',
        'Module "$id" is already compiled — unload it first.',
        recoverable: false,
      );
    }
    final module = await port.compile(id: id, bytes: bytes);
    _modules[id] = module;
    return module;
  }

  Future<List<@@PASCAL@@Value>> call({
    required String id,
    required String export,
    List<@@PASCAL@@Value> args = const [],
  }) async {
    _requireCompiled(id);
    return port.invoke(id: id, export: export, args: args);
  }

  Future<void> unload({required String id}) async {
    _requireCompiled(id);
    await port.unload(id: id);
    _modules.remove(id);
  }

  void _requireCompiled(String id) {
    if (!_modules.containsKey(id)) {
      throw @@PASCAL@@Exception(
        'not_compiled',
        'Module "$id" is not compiled — call compile() first.',
        recoverable: false,
      );
    }
  }
}

/// A port placeholder registered when no platform adapter was wired:
/// every operation surfaces the typed `port_not_wired` failure instead of
/// a null dereference at resolve time.
class _Unwired@@PASCAL@@Port implements @@PASCAL@@Port {
  const _Unwired@@PASCAL@@Port();

  Never _unwired() => throw const @@PASCAL@@Exception(
        'port_not_wired',
        'No @@PASCAL@@Port was registered — wire the platform adapter '
        'for the running platform before resolving @@PASCAL@@Service.',
        recoverable: false,
      );

  @override
  Future<bool> isSupported() async => _unwired();

  @override
  Future<@@PASCAL@@Module> compile({
    required String id,
    required Uint8List bytes,
  }) =>
      _unwired();

  @override
  Future<List<@@PASCAL@@Value>> invoke({
    required String id,
    required String export,
    List<@@PASCAL@@Value> args = const [],
  }) =>
      _unwired();

  @override
  Future<void> unload({required String id}) => _unwired();
}

/// Registers the @@PKG@@ stack onto [getIt]: the [@@PASCAL@@Port] is
/// normally supplied by the platform adapter package for the running
/// platform (e.g. `registerAndroid@@PASCAL@@Dependencies`), so the
/// service falls back to the GetIt-registered port when no explicit one
/// is passed. Without any registered port the service resolves over the
/// unwired placeholder and surfaces typed `port_not_wired` failures.
void register@@PASCAL@@Dependencies(
  GetIt getIt, {
  @@PASCAL@@Port? port,
}) {
  getIt.registerLazySingleton<@@PASCAL@@Service>(
    () => @@PASCAL@@Service(
      port:
          port ??
          (getIt.isRegistered<@@PASCAL@@Port>()
              ? getIt<@@PASCAL@@Port>()
              : const _Unwired@@PASCAL@@Port()),
    ),
  );
}
''';

  static const String _appServiceTestTemplate = r'''
// Generated by `zfa package create-plugin` — app-package test harness.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:@@PKG@@/@@PKG@@.dart';

class _RecordingPort implements @@PASCAL@@Port {
  final List<String> calls = [];

  @override
  Future<bool> isSupported() async {
    calls.add('isSupported');
    return true;
  }

  @override
  Future<@@PASCAL@@Module> compile({
    required String id,
    required Uint8List bytes,
  }) async {
    calls.add('compile:$id');
    return @@PASCAL@@Module(id: id, byteLength: bytes.lengthInBytes);
  }

  @override
  Future<List<@@PASCAL@@Value>> invoke({
    required String id,
    required String export,
    List<@@PASCAL@@Value> args = const [],
  }) async {
    calls.add('invoke:$id:$export');
    return [const @@PASCAL@@I32(42)];
  }

  @override
  Future<void> unload({required String id}) async {
    calls.add('unload:$id');
  }
}

void main() {
  group('@@PASCAL@@Service', () {
    late _RecordingPort port;
    late @@PASCAL@@Service service;

    setUp(() {
      port = _RecordingPort();
      service = @@PASCAL@@Service(port: port);
    });

    test('compile registers the module and call routes through the port',
        () async {
      final module = await service.compile(
        id: 'demo',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(module.byteLength, 3);
      expect(service.compiledModules, contains('demo'));

      final results = await service.call(
        id: 'demo',
        export: 'run',
        args: const [@@PASCAL@@I32(1)],
      );

      expect(port.calls, contains('invoke:demo:run'));
      expect(results.single, isA<@@PASCAL@@I32>());
      expect((results.single as @@PASCAL@@I32).value, 42);
    });

    test('call before compile surfaces the typed not_compiled failure',
        () async {
      await expectLater(
        service.call(id: 'missing', export: 'run'),
        throwsA(
          isA<@@PASCAL@@Exception>()
              .having((e) => e.code, 'code', 'not_compiled')
              .having((e) => e.recoverable, 'recoverable', isFalse),
        ),
      );
    });

    test('double compile surfaces already_compiled', () async {
      await service.compile(id: 'demo', bytes: Uint8List(0));

      await expectLater(
        service.compile(id: 'demo', bytes: Uint8List(0)),
        throwsA(
          isA<@@PASCAL@@Exception>()
              .having((e) => e.code, 'code', 'already_compiled'),
        ),
      );
    });

    test('unload releases the module and further calls fail typed',
        () async {
      await service.compile(id: 'demo', bytes: Uint8List(0));
      await service.unload(id: 'demo');

      expect(service.compiledModules, isNot(contains('demo')));
      await expectLater(
        service.call(id: 'demo', export: 'run'),
        throwsA(isA<@@PASCAL@@Exception>()),
      );
    });

    test('registration without a port surfaces typed port_not_wired',
        () async {
      final getIt = GetIt.instance;
      await getIt.reset();
      register@@PASCAL@@Dependencies(getIt);

      final service = getIt<@@PASCAL@@Service>();
      await expectLater(
        service.supported(),
        throwsA(
          isA<@@PASCAL@@Exception>()
              .having((e) => e.code, 'code', 'port_not_wired'),
        ),
      );
    });

    test('registration with a port binds the service to it', () async {
      final getIt = GetIt.instance;
      await getIt.reset();
      register@@PASCAL@@Dependencies(getIt, port: _RecordingPort());

      expect(await getIt<@@PASCAL@@Service>().supported(), isTrue);
    });
  });

  group('@@PASCAL@@Value', () {
    test('round-trips through the channel encoding', () {
      final i32 = @@PASCAL@@Value.decode(@@PASCAL@@I32(7).encode());
      expect(i32, isA<@@PASCAL@@I32>());

      final i64 = @@PASCAL@@Value.decode(
        @@PASCAL@@I64(BigInt.parse('9007199254740993')).encode(),
      );
      expect((i64 as @@PASCAL@@I64).value, BigInt.parse('9007199254740993'));

      final f64 = @@PASCAL@@Value.decode(@@PASCAL@@F64(1.5).encode());
      expect((f64 as @@PASCAL@@F64).value, 1.5);
    });

    test('rejects payloads it cannot decode', () {
      expect(
        () => @@PASCAL@@Value.decode(const [1, 2, 3]),
        throwsA(
          isA<@@PASCAL@@Exception>()
              .having((e) => e.code, 'code', 'malformed_value'),
        ),
      );
    });
  });
}
''';

  static const String _appValueTestTemplate = r'''
// Generated by `zfa package create-plugin` — value codec contract.
import 'package:test/test.dart';
import 'package:@@PKG@@/@@PKG@@.dart';

void main() {
  test('i32 encodes to an int', () {
    expect(@@PASCAL@@I32(42).encode(), 42);
  });

  test('i64 encodes to a decimal string and decodes back', () {
    final value = @@PASCAL@@I64(BigInt.parse('9007199254740993'));

    expect(value.encode(), '9007199254740993');
    expect(
      (@@PASCAL@@Value.decode(value.encode()) as @@PASCAL@@I64).value,
      BigInt.parse('9007199254740993'),
    );
  });

  test('f64 encodes to a double', () {
    expect(@@PASCAL@@F64(0.5).encode(), 0.5);
  });
}
''';

  // ─────────────────────────────────────────────────────────────────
  // Platform (envelope core) package templates
  // ─────────────────────────────────────────────────────────────────

  Map<String, String> _platformPackageFiles(Map<String, String> tokens) {
    final name = tokens['@@PKG@@']!;
    final noun = tokens['@@NOUN@@']!;
    final platformName = '${name}_platform';
    return {
      p.join('packages', platformName, 'pubspec.yaml'): _render(
        r'''
# Federated plugin monorepo created by `zfa package create-plugin` (issue #1604).
name: @@PKG@@_platform
description: >-
  @@CORE_DESC@@
version: @@INITIAL_VERSION@@
homepage: https://zuraffa.com

environment:
  sdk: @@SDK@@

dependencies:
@@ZURAFFA_DEP@@
  @@PKG@@: ^@@INITIAL_VERSION@@

dev_dependencies:
  lints: @@LINTS@@
  test: @@TEST@@

dependency_overrides:
  # Local development only — resolve the app-facing package to this
  # checkout; stripped on publish.
  @@PKG@@:
    path: ../@@PKG@@
@@ZURAFFA_PATH_ENTRY@@
repository: @@REPO@@
issue_tracker: @@REPO@@/issues

@@TOPICS@@''',
        {
          ...tokens,
          '@@SDK@@': _sdkConstraint,
          '@@LINTS@@': _lintsConstraint,
          '@@TEST@@': _testConstraint,
        },
      ),
      p.join('packages', platformName, 'analysis_options.yaml'):
          _analysisOptions(),
      p.join('packages', platformName, 'CHANGELOG.md'): _render(
        _packageChangelogTemplate,
        tokens,
      ),
      p.join('packages', platformName, 'README.md'): _render(r'''
# @@PKG@@_platform

Shared channel-envelope core for the @@PKG@@ platform adapters: decode,
typed-error plumbing, and timeout policy over an injected platform
channel. Adapters bring their own typed exception and taxonomy; the core
never invents one.

Part of the [@@PKG@@](@@REPO@@) federated monorepo.

## Develop

```bash
dart pub get
dart test
```
''', tokens),
      p.join('packages', platformName, 'LICENSE'): _render(
        _licenseTemplate,
        tokens,
      ),
      p.join('packages', platformName, 'lib', '$platformName.dart'): _render(
        r'''
/// Shared envelope core for the `@@PKG@@` platform adapters.
library;

export 'src/platform_@@NOUN@@_envelope.dart';
''',
        tokens,
      ),
      p.join(
        'packages',
        platformName,
        'lib',
        'src',
        'platform_${noun}_envelope.dart',
      ): _render(
        _envelopeTemplate,
        tokens,
      ),
      p.join(
        'packages',
        platformName,
        'test',
        'platform_${noun}_envelope_test.dart',
      ): _render(
        _envelopeTestTemplate,
        tokens,
      ),
    };
  }

  static const String _envelopeTemplate = r'''
import 'dart:async';

/// The injected transport seam (moved from the adapters): the consuming
/// app (or native shell) supplies the actual channel call.
typedef ChannelInvoke = FutureOr<Object?> Function(
  String method,
  Map<String, Object?> args,
);

/// Builds the calling adapter's own typed exception — the core never
/// invents an exception type of its own.
typedef PlatformExceptionFactory = Exception Function(
  String code,
  String message, {
  required bool recoverable,
});

/// The adapter's taxonomy hook: map a native code to the typed failure, or
/// return null to fall through to the core default.
typedef PlatformErrorMapper = Exception? Function(String code, String message);

/// Recognizes the calling adapter's typed exceptions so a typed failure
/// thrown inside [ChannelInvoke] passes through
/// [Platform@@PASCAL@@Envelope.call] without double wrapping.
typedef TypedErrorPredicate = bool Function(Object error);

/// Sentinel for the envelope's own timeout: thrown by the `onTimeout`
/// callback and converted to the adapter's typed `timeout` failure — never
/// observable outside [call].
class _EnvelopeTimeout implements Exception {
  const _EnvelopeTimeout();
}

/// The shared channel envelope: every adapter platform call goes through
/// [call] — success payloads decode to the returned map, native error
/// payloads and thrown transport failures surface as typed exceptions
/// (built by the calling adapter's own factory), and a call past [timeout]
/// surfaces as a recoverable `timeout`.
class Platform@@PASCAL@@Envelope {
  final ChannelInvoke invoke;
  final Duration timeout;
  final PlatformExceptionFactory onTyped;
  final PlatformErrorMapper? mapNativeError;
  final TypedErrorPredicate? isTypedError;

  const Platform@@PASCAL@@Envelope({
    required this.invoke,
    required this.onTyped,
    this.mapNativeError,
    this.isTypedError,
    this.timeout = const Duration(seconds: 30),
  });

  Future<Map<String, Object?>?> call(
    String method,
    Map<String, Object?> args,
  ) async {
    Object? raw;
    try {
      raw = await Future.sync(() => invoke(method, args)).timeout(
        timeout,
        onTimeout: () => throw const _EnvelopeTimeout(),
      );
    } on _EnvelopeTimeout {
      throw onTyped(
        'timeout',
        'The platform call exceeded the timeout window.',
        recoverable: true,
      );
    } catch (e) {
      if (isTypedError != null && isTypedError!(e)) rethrow;
      throw onTyped(
        'channel_error',
        'The platform call "$method" failed: $e',
        recoverable: false,
      );
    }
    if (raw == null) return null;
    if (raw is! Map) {
      throw onTyped(
        'malformed_response',
        'The platform call "$method" returned a non-map payload: $raw',
        recoverable: false,
      );
    }
    final result = Map<String, Object?>.from(raw);
    final error = result['error'];
    if (error is Map) {
      throw _typedError(Map<String, Object?>.from(error));
    }
    return result;
  }

  /// Evaluates the adapter's taxonomy hook, falling back to the adapter's
  /// own typed factory for unmapped codes.
  Exception _typedError(Map<String, Object?> error) {
    final code = (error['code'] as String?) ?? 'unknown';
    final message = (error['message'] as String?) ?? '';
    final mapped = mapNativeError?.call(code, message);
    if (mapped != null) return mapped;
    return onTyped(code, message, recoverable: false);
  }
}
''';

  static const String _envelopeTestTemplate = r'''
// Generated by `zfa package create-plugin` — envelope contract tests.
import 'dart:async';

import 'package:test/test.dart';
import 'package:@@PKG@@_platform/@@PKG@@_platform.dart';

class _Typed implements Exception {
  final String code;

  const _Typed(this.code);
}

class _EnvelopeFailure implements Exception {
  final String code;
  final String message;
  final bool recoverable;

  const _EnvelopeFailure(this.code, this.message, {required this.recoverable});
}

void main() {
  Exception typedFactory(
    String code,
    String message, {
    required bool recoverable,
  }) =>
      _EnvelopeFailure(code, message, recoverable: recoverable);

  group('Platform@@PASCAL@@Envelope', () {
    test('decodes success payloads', () async {
      final envelope = Platform@@PASCAL@@Envelope(
        invoke: (_, __) async => {'supported': true},
        onTyped: typedFactory,
      );

      expect(
        await envelope.call('isSupported', const {}),
        {'supported': true},
      );
    });

    test('native error payloads surface through the taxonomy', () async {
      final envelope = Platform@@PASCAL@@Envelope(
        invoke: (_, __) async => {
          'error': {'code': 'not_supported', 'message': 'no engine'},
        },
        onTyped: typedFactory,
        mapNativeError: (code, message) => _Typed(code),
      );

      await expectLater(
        envelope.call('isSupported', const {}),
        throwsA(isA<_Typed>().having((e) => e.code, 'code', 'not_supported')),
      );
    });

    test('unmapped native codes fall through to the adapter factory',
        () async {
      final envelope = Platform@@PASCAL@@Envelope(
        invoke: (_, __) async => {
          'error': {'code': 'weird', 'message': 'unexpected'},
        },
        onTyped: typedFactory,
      );

      await expectLater(
        envelope.call('isSupported', const {}),
        throwsA(
          isA<_EnvelopeFailure>()
              .having((e) => e.code, 'code', 'weird')
              .having((e) => e.recoverable, 'recoverable', isFalse),
        ),
      );
    });

    test('a past-timeout call surfaces as the typed recoverable timeout',
        () async {
      final envelope = Platform@@PASCAL@@Envelope(
        invoke: (_, __) => Completer<Map<String, Object?>>().future,
        onTyped: typedFactory,
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        envelope.call('isSupported', const {}),
        throwsA(
          isA<_EnvelopeFailure>()
              .having((e) => e.code, 'code', 'timeout')
              .having((e) => e.recoverable, 'recoverable', isTrue),
        ),
      );
    });

    test('non-map payloads surface as malformed_response', () async {
      final envelope = Platform@@PASCAL@@Envelope(
        invoke: (_, __) async => [1, 2, 3],
        onTyped: typedFactory,
      );

      await expectLater(
        envelope.call('batch', const {}),
        throwsA(
          isA<_EnvelopeFailure>()
              .having((e) => e.code, 'code', 'malformed_response'),
        ),
      );
    });

    test('adapter-typed failures thrown by the transport pass through',
        () async {
      final envelope = Platform@@PASCAL@@Envelope(
        invoke: (_, __) => throw const _Typed('already_typed'),
        onTyped: typedFactory,
        isTypedError: (error) => error is _Typed,
      );

      await expectLater(
        envelope.call('isSupported', const {}),
        throwsA(isA<_Typed>().having((e) => e.code, 'code', 'already_typed')),
      );
    });
  });
}
''';

  // ─────────────────────────────────────────────────────────────────
  // Adapter package templates
  // ─────────────────────────────────────────────────────────────────

  Map<String, String> _adapterPackageFiles(
    Map<String, String> tokens, {
    required PluginPlatform platform,
  }) {
    final name = tokens['@@PKG@@']!;
    final noun = tokens['@@NOUN@@']!;
    final adapterName = '${name}_${platform.dirSuffix}';
    final adapterTokens = {
      ...tokens,
      // A custom --description mirrors onto the adapters; without one the
      // per-platform sentence is the default (a generic app-level
      // sentence would waste the per-platform pub.dev surface).
      '@@ADAPTER_DESC@@': tokens['@@CUSTOM_DESC@@']!.isEmpty
          ? '${platform.label} adapter for $name — the '
                '${tokens['@@PASCAL@@']} port over an injected platform '
                'channel with a typed failure taxonomy.'
          : tokens['@@CUSTOM_DESC@@']!,
      '@@TOPICS@@': _topicsYaml(_topicsFor(noun, platform: platform)),
      '@@PLATFORM_CLASS@@': platform.classPrefix,
      '@@PLATFORM_FILE@@': platform.dirSuffix,
      '@@PLATFORM_LABEL@@': platform.label,
    };
    return {
      p.join('packages', adapterName, 'pubspec.yaml'): _render(
        r'''
# Federated plugin monorepo created by `zfa package create-plugin` (issue #1604).
name: @@PKG@@_@@PLATFORM_FILE@@
description: >-
  @@ADAPTER_DESC@@
version: @@INITIAL_VERSION@@
homepage: https://zuraffa.com

environment:
  sdk: @@SDK@@

dependencies:
@@ZURAFFA_DEP@@
  @@PKG@@: ^@@INITIAL_VERSION@@
  @@PKG@@_platform: ^@@INITIAL_VERSION@@

dev_dependencies:
  lints: @@LINTS@@
  test: @@TEST@@

dependency_overrides:
  # Local development only — resolve the in-family siblings to this
  # checkout; stripped on publish.
  @@PKG@@:
    path: ../@@PKG@@
  @@PKG@@_platform:
    path: ../@@PKG@@_platform
@@ZURAFFA_PATH_ENTRY@@
repository: @@REPO@@
issue_tracker: @@REPO@@/issues

@@TOPICS@@''',
        {
          ...adapterTokens,
          '@@SDK@@': _sdkConstraint,
          '@@LINTS@@': _lintsConstraint,
          '@@TEST@@': _testConstraint,
        },
      ),
      p.join('packages', adapterName, 'analysis_options.yaml'):
          _analysisOptions(),
      p.join('packages', adapterName, 'CHANGELOG.md'): _render(
        _packageChangelogTemplate,
        tokens,
      ),
      p.join('packages', adapterName, 'README.md'): _render(r'''
# @@PKG@@_@@PLATFORM_FILE@@

@@PLATFORM_LABEL@@ adapter for the [@@PKG@@](@@REPO@@) federated monorepo:
the @@PASCAL@@ port over an injected platform channel, with the shared
envelope machinery from `@@PKG@@_platform` and a typed failure taxonomy
as pure data.

The channel transport is injected — no Flutter plugin boilerplate, no
native code in this repo. The consuming app (or a native shell) supplies
the `ChannelInvoke` seam:

```dart
import 'package:zuraffa/zuraffa.dart';
import 'package:@@PKG@@_@@PLATFORM_FILE@@/@@PKG@@_@@PLATFORM_FILE@@.dart';

void register() {
  register@@PLATFORM_CLASS@@@@PASCAL@@Dependencies(
    GetIt.instance,
    channel: @@PLATFORM_CLASS@@@@PASCAL@@Channel(
      invoke: (method, args) => nativeBridge.call(method, args),
    ),
  );
}
```

Without an injected channel every call surfaces the typed
`channel_not_wired` failure instead of hanging.

## Develop

```bash
dart pub get
dart test
```
''', adapterTokens),
      p.join('packages', adapterName, 'LICENSE'): _render(
        _licenseTemplate,
        tokens,
      ),
      p.join('packages', adapterName, 'lib', '$adapterName.dart'): _render(r'''
/// @@PKG@@_@@PLATFORM_FILE@@ — the @@PLATFORM_LABEL@@ adapter of the
/// `@@PKG@@` federated plugin: register, channel, typed exception, port.
library;

export 'src/register.dart';
export 'src/@@PLATFORM_FILE@@_@@NOUN@@_channel.dart';
export 'src/@@PLATFORM_FILE@@_@@NOUN@@_exception.dart';
export 'src/@@PLATFORM_FILE@@_@@NOUN@@_port.dart';
''', adapterTokens),
      p.join(
        'packages',
        adapterName,
        'lib',
        'src',
        '${platform.dirSuffix}_${noun}_exception.dart',
      ): _render(
        _adapterExceptionTemplate,
        adapterTokens,
      ),
      p.join(
        'packages',
        adapterName,
        'lib',
        'src',
        '${platform.dirSuffix}_${noun}_channel.dart',
      ): _render(
        _adapterChannelTemplate,
        adapterTokens,
      ),
      p.join(
        'packages',
        adapterName,
        'lib',
        'src',
        '${platform.dirSuffix}_${noun}_port.dart',
      ): _render(
        _adapterPortTemplate,
        adapterTokens,
      ),
      p.join('packages', adapterName, 'lib', 'src', 'register.dart'): _render(
        _adapterRegisterTemplate,
        adapterTokens,
      ),
      p.join(
        'packages',
        adapterName,
        'test',
        '${platform.dirSuffix}_${noun}_adapter_test.dart',
      ): _render(
        _adapterTestTemplate,
        adapterTokens,
      ),
    };
  }

  static const String _adapterExceptionTemplate = r'''
/// The typed native failure on @@PLATFORM_LABEL@@.
class @@PLATFORM_CLASS@@@@PASCAL@@Exception implements Exception {
  final String code;
  final String message;
  final bool recoverable;

  const @@PLATFORM_CLASS@@@@PASCAL@@Exception(
    this.code,
    this.message, {
    required this.recoverable,
  });

  @override
  String toString() =>
      '@@PLATFORM_CLASS@@@@PASCAL@@Exception($code, recoverable: $recoverable): $message';
}
''';

  static const String _adapterChannelTemplate = r'''
import 'package:@@PKG@@_platform/@@PKG@@_platform.dart';

import '@@PLATFORM_FILE@@_@@NOUN@@_exception.dart';

/// The @@PLATFORM_LABEL@@ channel: the shared
/// [Platform@@PASCAL@@Envelope] machinery with the @@PLATFORM_LABEL@@
/// taxonomy as a pure data set.
class @@PLATFORM_CLASS@@@@PASCAL@@Channel {
  /// Native codes that map recoverable; everything else (including
  /// unknown codes) is non-recoverable, preserved verbatim.
  static const Set<String> recoverableCodes = {
    'user_cancelled',
    'api_unavailable',
    'not_supported',
    'timeout',
  };

  final ChannelInvoke invoke;
  final Duration timeout;

  const @@PLATFORM_CLASS@@@@PASCAL@@Channel({
    required this.invoke,
    this.timeout = const Duration(seconds: 30),
  });

  Future<Map<String, Object?>?> call(
    String method,
    Map<String, Object?> args,
  ) =>
      Platform@@PASCAL@@Envelope(
        invoke: invoke,
        timeout: timeout,
        onTyped: @@PLATFORM_CLASS@@@@PASCAL@@Exception.new,
        mapNativeError: _mapNativeError,
        isTypedError: (error) => error is @@PLATFORM_CLASS@@@@PASCAL@@Exception,
      ).call(method, args);

  static Exception _mapNativeError(String code, String message) =>
      @@PLATFORM_CLASS@@@@PASCAL@@Exception(
        code,
        message,
        recoverable: recoverableCodes.contains(code),
      );
}
''';

  static const String _adapterPortTemplate = r'''
import 'dart:typed_data';

import 'package:@@PKG@@/@@PKG@@.dart';

import '@@PLATFORM_FILE@@_@@NOUN@@_channel.dart';
import '@@PLATFORM_FILE@@_@@NOUN@@_exception.dart';

/// @@PLATFORM_LABEL@@ [@@PASCAL@@Port] over the typed
/// [@@PLATFORM_CLASS@@@@PASCAL@@Channel].
class @@PLATFORM_CLASS@@@@PASCAL@@Port implements @@PASCAL@@Port {
  final @@PLATFORM_CLASS@@@@PASCAL@@Channel channel;

  const @@PLATFORM_CLASS@@@@PASCAL@@Port({required this.channel});

  @override
  Future<bool> isSupported() async {
    final result = await channel.call('isSupported', const {});
    return result?['supported'] == true;
  }

  @override
  Future<@@PASCAL@@Module> compile({
    required String id,
    required Uint8List bytes,
  }) async {
    final result = await channel.call('compile', {
      'id': id,
      'bytes': bytes,
    });
    return @@PASCAL@@Module(
      id: id,
      byteLength:
          (result?['byteLength'] as num?)?.toInt() ?? bytes.lengthInBytes,
    );
  }

  @override
  Future<List<@@PASCAL@@Value>> invoke({
    required String id,
    required String export,
    List<@@PASCAL@@Value> args = const [],
  }) async {
    final result = await channel.call('invoke', {
      'id': id,
      'export': export,
      'args': [for (final arg in args) arg.encode()],
    });
    final values = result?['values'];
    if (values is! List) {
      throw const @@PLATFORM_CLASS@@@@PASCAL@@Exception(
        'malformed_response',
        'The invoke result carried no value list.',
        recoverable: false,
      );
    }
    return [for (final raw in values) @@PASCAL@@Value.decode(raw)];
  }

  @override
  Future<void> unload({required String id}) async {
    await channel.call('unload', {'id': id});
  }
}
''';

  static const String _adapterRegisterTemplate = r'''
import 'package:zuraffa/zuraffa.dart';
import 'package:@@PKG@@/@@PKG@@.dart';

import '@@PLATFORM_FILE@@_@@NOUN@@_channel.dart';
import '@@PLATFORM_FILE@@_@@NOUN@@_exception.dart';
import '@@PLATFORM_FILE@@_@@NOUN@@_port.dart';

/// Registers the @@PLATFORM_LABEL@@ adapter on [GetIt.instance]: the
/// [@@PASCAL@@Port] over an injected channel. An injected [timeout] is
/// applied to the wired channel. Without a channel every call surfaces
/// the typed `channel_not_wired` failure.
void register@@PLATFORM_CLASS@@@@PASCAL@@Dependencies(
  GetIt getIt, {
  @@PLATFORM_CLASS@@@@PASCAL@@Channel? channel,
  Duration? timeout,
}) {
  final wired = (channel == null)
      ? @@PLATFORM_CLASS@@@@PASCAL@@Channel(
          invoke: (_, __) => throw const @@PLATFORM_CLASS@@@@PASCAL@@Exception(
            'channel_not_wired',
            'No @@PLATFORM_LABEL@@ channel was injected — pass one to '
            'register@@PLATFORM_CLASS@@@@PASCAL@@Dependencies.',
            recoverable: false,
          ),
        )
      : (timeout == null)
          ? channel
          : @@PLATFORM_CLASS@@@@PASCAL@@Channel(
              invoke: channel.invoke,
              timeout: timeout,
            );
  getIt.registerLazySingleton<@@PASCAL@@Port>(
    () => @@PLATFORM_CLASS@@@@PASCAL@@Port(channel: wired),
  );
}
''';

  static const String _adapterTestTemplate = r'''
// Generated by `zfa package create-plugin` — adapter test harness over a
// fake injected channel (success, taxonomy, timeout, unwired).
import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:@@PKG@@/@@PKG@@.dart';
import 'package:@@PKG@@_@@PLATFORM_FILE@@/@@PKG@@_@@PLATFORM_FILE@@.dart';

void main() {
  group('@@PLATFORM_CLASS@@@@PASCAL@@Adapter', () {
    test('isSupported decodes the native payload', () async {
      final channel = @@PLATFORM_CLASS@@@@PASCAL@@Channel(
        invoke: (_, __) async => {'supported': true},
      );
      final port = @@PLATFORM_CLASS@@@@PASCAL@@Port(channel: channel);

      expect(await port.isSupported(), isTrue);
    });

    test('invoke success decodes values through the envelope', () async {
      final channel = @@PLATFORM_CLASS@@@@PASCAL@@Channel(
        invoke: (method, args) async => {
          'values': [42],
        },
      );
      final port = @@PLATFORM_CLASS@@@@PASCAL@@Port(channel: channel);

      final values = await port.invoke(
        id: 'demo',
        export: 'run',
        args: const [@@PASCAL@@I32(1)],
      );

      expect(values.single, isA<@@PASCAL@@I32>());
    });

    test('native error payloads surface as typed failures', () async {
      final channel = @@PLATFORM_CLASS@@@@PASCAL@@Channel(
        invoke: (_, __) async => {
          'error': {'code': 'not_supported', 'message': 'no wasm engine'},
        },
      );

      await expectLater(
        channel.call('isSupported', const {}),
        throwsA(
          isA<@@PLATFORM_CLASS@@@@PASCAL@@Exception>()
              .having((e) => e.code, 'code', 'not_supported')
              .having((e) => e.recoverable, 'recoverable', isTrue),
        ),
      );
    });

    test('timeout surfaces as the typed recoverable timeout', () async {
      final channel = @@PLATFORM_CLASS@@@@PASCAL@@Channel(
        invoke: (_, __) => Completer<Map<String, Object?>>().future,
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        channel.call('isSupported', const {}),
        throwsA(
          isA<@@PLATFORM_CLASS@@@@PASCAL@@Exception>()
              .having((e) => e.code, 'code', 'timeout'),
        ),
      );
    });

    test('without a wired channel registration stays safe and typed',
        () async {
      final getIt = GetIt.instance;
      await getIt.reset();
      register@@PLATFORM_CLASS@@@@PASCAL@@Dependencies(getIt);

      final port = getIt<@@PASCAL@@Port>();
      await expectLater(
        port.isSupported(),
        throwsA(
          isA<@@PLATFORM_CLASS@@@@PASCAL@@Exception>()
              .having((e) => e.code, 'code', 'channel_not_wired'),
        ),
      );
    });
  });
}
''';

  String _analysisOptions() => 'include: package:lints/recommended.yaml\n';
}
