#!/usr/bin/env bash
# update_fleet.sh — mono-version fleet manager for the zuraffa package family.
#
# The whole zuraffa fleet shares ONE version number (mono versioning). This
# script aligns every fleet repo in ~/Developer to a target version:
#
#   ./scripts/update_fleet.sh 7.3.0              # bump everything to 7.3.0
#   ./scripts/update_fleet.sh 7.3.0 --pull       # pull latest master first
#   ./scripts/update_fleet.sh 7.3.0 --check      # report drift only, change nothing
#   ./scripts/update_fleet.sh 7.3.0 --no-commit  # leave the working tree dirty
#
# Per package pubspec it:
#   1. sets `version:` to the target,
#   2. rewrites any single-line `zuraffa: ^x.y.z` dependency to ^target
#      (path blocks `zuraffa:\n    path:` are dev-mode and left alone),
#   3. ensures `dependency_overrides: xml: 7.1.0` (fleet-wide xml policy),
#   4. rewrites stale version constraints in README.md install guides
#      (`zuraffa: ^old` and `<package>: ^old` install lines),
#   5. prepends a CHANGELOG.md entry for the target version.
#
# Per repo it also ensures PUBLISH.md documents the mono-version + README
# install-guide policy, and (unless --no-commit) commits the result on the
# current branch. No PRs are opened — the fleet pushes straight to master.
#
# Excluded from the fleet (review clones / sandboxes / demos / standalone
# products):
#   zuraffa_175, zuraffa_demo, zuraffa-pr271-review, zuraffa-review-clone,
#   pristine-base-zuraffa, zfa_spec*, zfa_tdd_probe, zfa_todo_app, zfa-fix,
#   zuraffa_browser (standalone browser PRODUCT, not a fleet package)
set -euo pipefail

# macOS ships bash 3.2; the fleet maps below need associative arrays (bash 4+).
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "update_fleet.sh needs bash >= 4 (macOS: brew install bash; /usr/local/bin/bash)." >&2
  exit 1
fi

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

DEV_ROOT="${ZURAFFA_DEV_ROOT:-$HOME/Developer}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
XML_OVERRIDE="${ZURAFFA_XML_OVERRIDE:-7.1.0}"

FLEET_REPOS=(
  zuraffa
  zuraffa_flutter
  zuraffa_ui
  zuraffa_agent
  zuraffa_code_editor
  zuraffa_ffi
  zuraffa_graphql
  zuraffa_observability
  zuraffa_storage
  zuraffa_session
  zuraffa_intents
  zuraffa_minio
  zuraffa_auth
  zuraffa_dashboard
  zuraffa_file_picker
  zuraffa_inappwebview
  zuraffa_ocr
  zuraffa_permissions
  zuraffa_purchase
  zuraffa_subscriptions
  zuraffa_notifications
  zuraffa_tui
  zuraffa_vendure
)

PUBLISH_POLICY_LINE="**Mono version policy:** every package in the zuraffa fleet shares one version number. Bump the whole fleet with \`../zuraffa/scripts/update_fleet.sh <version>\`. Whenever a version is updated, the install guide in this repo's README.md MUST be updated to that release version in the same change — no old version constraints may linger in README install snippets. Dependency constraints on \`zuraffa\` itself must move to \`^<version>\` in the same bump."

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -30; exit 1; }

VERSION=""
MODE="apply"
DO_PULL=0
DO_COMMIT=1
CHANGELOG_MSG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --pull) DO_PULL=1; shift ;;
    --no-commit) DO_COMMIT=0; shift ;;
    --changelog) CHANGELOG_MSG="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    *) if [ -z "$VERSION" ]; then VERSION="$1"; shift; else echo -e "${RED}Unexpected argument: $1${NC}"; exit 1; fi ;;
  esac
done

if [ -z "$VERSION" ]; then
  echo -e "${YELLOW}No version given — reading the current version from $DEV_ROOT/zuraffa/pubspec.yaml${NC}"
  VERSION=$(grep '^version:' "$DEV_ROOT/zuraffa/pubspec.yaml" | sed 's/version: //' | tr -d '[:space:]')
  if [ -z "$VERSION" ]; then echo -e "${RED}Could not detect version${NC}"; exit 1; fi
fi

if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "${RED}Version must be semver (x.y.z), got: $VERSION${NC}"; exit 1
fi

CURRENT_DATE=$(date +"%Y-%m-%d")
FAILURES=0

# --- pubspec discovery -------------------------------------------------------
# Fleet packages per repo: the root pubspec (if any), one level of packages/*,
# and platform packages checked in at the repo root (zuraffa_permissions_android
# style). Deliberately NOT swept: examples/, apps/, fixtures, .worktrees,
# sandboxes — those are private dev surfaces, not published fleet members.
find_pkg_pubspecs() {
  local repo_root="$1"
  local specs=()
  [ -f "$repo_root/pubspec.yaml" ] && specs+=("pubspec.yaml")
  local d base
  if [ -d "$repo_root/packages" ]; then
    for d in "$repo_root"/packages/*/; do
      [ -f "${d}pubspec.yaml" ] && specs+=("packages/$(basename "$d")/pubspec.yaml")
    done
  fi
  for d in "$repo_root"/*/; do
    base=$(basename "$d")
    case "$base" in
      example|examples|apps|build|tool|tools|test|tests|docs|doc|specs|sandbox|playground|scripts|bin|.worktrees|.gym|.zfa|.zread|web|android|ios|macos|windows|linux) continue ;;
      zuraffa_*|zikzak_*) [ -f "${d}pubspec.yaml" ] && specs+=("$base/pubspec.yaml") ;;
    esac
  done
  printf '%s\n' "${specs[@]:-}" | grep -v '^$' | sort -u
}

pkg_name() { grep '^name:' "$1" | sed 's/name: *//' | tr -d '[:space:]'; }
pkg_version() { grep '^version:' "$1" | sed 's/version: //' | tr -d '[:space:]'; }

# --- operations ---------------------------------------------------------------



update_readme() {
  # 1. Any `zuraffa: ^x.y.z` constraint (yaml or backticked prose) -> target.
  sed -i '' -E "s/zuraffa:[[:space:]]*\^[0-9]+\.[0-9]+\.[0-9]+/zuraffa: ^$VERSION/g" "$1"
  # 2. This package's own install line `<pkg>: ^x.y.z` -> target.
  local name
  name=$(grep '^name:' "$1" >/dev/null 2>&1 || true)
  :
}

update_readme_pkg() {
  local readme="$1" pkg="$2"
  sed -i '' -E "s/^\s*${pkg}:[[:space:]]*\^[0-9]+\.[0-9]+\.[0-9]+/${pkg}: ^$VERSION/" "$readme"
  # prose mentions like `resolving zuraffa_session 1.2.1` in install guides
  sed -i '' -E "s/(${pkg})[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+([[:space:]]*$|['\`])/\1 $VERSION\2/g" "$readme" 2>/dev/null || true
}

ensure_changelog() {
  local file="$1" msg="$2"
  [ -f "$file" ] || { printf '# Changelog\n\n' > "$file"; }
  if grep -q "^## \[$VERSION\]\|^## $VERSION" "$file"; then
    return 0
  fi
  local tmp="$file.tmp"
  {
    # Zikzak-style heading `## <version> - <date>` — no brackets. Fleet
    # changelog-format tests (e.g. zuraffa_ui barrel_surface_test) pin the
    # bare version heading; the core repo's bracketed style is its own.
    if [ -n "$msg" ]; then
      printf '## %s - %s\n\n%s\n\n' "$VERSION" "$CURRENT_DATE" "$msg"
    else
      printf '## %s - %s\n\n- Mono-version fleet alignment to %s; internal dependencies refreshed; xml override %s.\n\n' "$VERSION" "$CURRENT_DATE" "$VERSION" "$XML_OVERRIDE"
    fi
    cat "$file"
  } > "$tmp"
  mv "$tmp" "$file"
}

ensure_publish_policy() {
  local file="$1"
  [ -f "$file" ] || { printf '# Publish Configuration\n\n' > "$file"; }
  if grep -qF 'update_fleet.sh' "$file"; then return 0; fi
  printf '\n---\n\n%s\n' "$PUBLISH_POLICY_LINE" >> "$file"
}

# --- check mode ---------------------------------------------------------------

check_pubspec() {
  local file="$1" repo_root="$2" name ver ok=0
  name=$(pkg_name "$file")
  ver=$(pkg_version "$file")
  [ "$ver" == "$VERSION" ] || { echo -e "  ${RED}version drift: $name $ver != $VERSION${NC}"; ok=1; }
  if grep -qE "^[[:space:]]*zuraffa:[[:space:]]*\^?[0-9]+\.[0-9]+\.[0-9]+" "$file"; then
    grep -qE "^[[:space:]]*zuraffa:[[:space:]]*\^$VERSION([[:space:]]|$)" "$file" || { echo -e "  ${RED}zuraffa constraint drift in $name${NC}"; ok=1; }
  fi
  # xml override presence — workspace MEMBERS are exempt: a pub workspace
  # shares one resolution governed by the root, and pub rejects a member
  # that overrides the same package its root overrides.
  if is_workspace_member "$file" "$repo_root"; then
    return $ok
  fi
  if grep -q '^dependency_overrides:' "$file"; then
    python3 - "$file" <<'PY' || ok=1
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r'^dependency_overrides:\s*$', text, re.M)
body_lines = []
if m:
    for line in text[m.end():].split('\n'):
        if line and not line.startswith((' ', '\t', '#')):
            break
        body_lines.append(line)
body = '\n'.join(body_lines)
assert re.search(r'^\s*xml\s*:\s*7\.1\.0\s*$', body, re.M), 'xml override missing/incorrect'
PY
  else
    echo -e "  ${RED}no dependency_overrides section (xml policy) in $name${NC}"; ok=1
  fi
  return $ok
}

check_readme() {
  local repo_root="$1" readme
  # Top-level + packages/*/README.md only — fixture/worktree copies are not
  # the install guide.
  for readme in "$repo_root"/README.md "$repo_root"/packages/*/README.md; do
    [ -f "$readme" ] || continue
    if grep -nE 'zuraffa:[[:space:]]*\^[0-9]+\.[0-9]+\.[0-9]+' "$readme" 2>/dev/null \
       | grep -v "\^$VERSION" | grep -q .; then
      echo -e "  ${RED}stale zuraffa constraint in README: $readme${NC}"
      grep -nE 'zuraffa:[[:space:]]*\^[0-9]+\.[0-9]+\.[0-9]+' "$readme" | grep -v "\^$VERSION" | sed 's/^/    /'
      return 1
    fi
  done
  return 0
}

# --- main ---------------------------------------------------------------------

echo -e "${BLUE}=== zuraffa fleet update: target $VERSION (xml override $XML_OVERRIDE) ===${NC}"

[ "$MODE" == "check" ] || [ -d "$DEV_ROOT/zuraffa" ] || { echo -e "${RED}$DEV_ROOT/zuraffa not found${NC}"; exit 1; }

# Pass 0: collect every fleet package name (repo roots, packages/*, root-level
# platform dirs). Cross-fleet constraints (an adapter pinning `zuraffa_auth:
# ^1.1.1`) must move with the release too — that is what mono version means.
declare -a FLEET_PKG_NAMES=()
declare -A FLEET_PKG_DIR=()   # name -> absolute dir of its pubspec
declare -A FLEET_PKG_REPO=()  # name -> repo
for repo in "${FLEET_REPOS[@]}"; do
  repo_root="$DEV_ROOT/$repo"
  [ -d "$repo_root" ] || continue
  while IFS= read -r rel; do
    name=$(pkg_name "$repo_root/$rel" 2>/dev/null) || continue
    [ -z "$name" ] && continue
    FLEET_PKG_NAMES+=("$name")
    FLEET_PKG_DIR["$name"]="$repo_root/$(dirname "$rel")"
    FLEET_PKG_REPO["$name"]="$repo"
  done < <(find_pkg_pubspecs "$repo_root")
done
echo -e "${BLUE}fleet packages (${#FLEET_PKG_NAMES[@]})${NC}"

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

# latest published version of a package on pub.dev ("" when unknown)
published_version() {
  local pkg="$1"
  local cache="$TMPD/pub_$pkg"
  if [ ! -f "$cache" ]; then
    curl -s --max-time 15 "https://pub.dev/api/packages/$pkg" \
      | python3 -c 'import json,sys;
try: print(json.load(sys.stdin)["latest"]["version"])
except Exception: print("")' > "$cache" 2>/dev/null || echo "" > "$cache"
  fi
  cat "$cache"
}

# version_gt A B -> A > B (semver, numeric segments only)
version_gt() { [ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" != "$1" ] && [ "$1" != "$2" ]; }

# can_hosted_resolve NAME — true when pub.dev's latest >= $VERSION
can_hosted_resolve() {
  local latest
  latest=$(published_version "$1")
  [ -n "$latest" ] || return 1
  if [ "$latest" == "$VERSION" ]; then return 0; fi
  version_gt "$latest" "$VERSION" && return 0
  return 1
}


# Ensure every cross-repo fleet constraint that pub.dev cannot satisfy at
# $VERSION resolves against the sibling checkout (dev mode only — the
# strip-before-push step removes these overrides; pub does NOT strip them
# itself, they persist in the archive). Overrides only apply from the root
# package, so a versioned constraint that arrives TRANSITIVELY through a
# same-repo path dependency (adapter -> app package -> other-repo package)
# breaks the adapter's own pub get — those transitive deps get an override
# here too.
fleet_deps_of() { # pubspec -> print fleet names it constrains (single-line)
  local file="$1" pkg
  for pkg in "${FLEET_PKG_NAMES[@]}"; do
    grep -qE "^[[:space:]]*${pkg}:[[:space:]]*\^?[0-9]+\.[0-9]+\.[0-9]+" "$file" && echo "$pkg" || true
  done
}

path_override_targets() { # pubspec -> print pubspec paths of its path: deps
  # Scans the WHOLE file, not just dependency_overrides: examples and
  # federated platform packages declare their parent via a `path:` dep in
  # `dependencies:` (dart >= 3.6 resolves example/ as its own root where the
  # parent's overrides do not apply), and the inherited deps are the same.
  python3 - "$1" <<'PY'
import re, os, sys
lines = open(sys.argv[1]).read().split('\n')
base = os.path.dirname(os.path.abspath(sys.argv[1]))
seen = set()
for i in range(len(lines) - 1):
    if not re.match(r'^\s*[\w][\w-]*:\s*$', lines[i]):
        continue
    pm = re.match(r'^\s+path:\s*(\S+)', lines[i + 1])
    if not pm:
        continue
    target = os.path.normpath(os.path.join(base, pm.group(1)))
    pspec = os.path.join(target, 'pubspec.yaml')
    if os.path.isfile(pspec) and pspec not in seen:
        seen.add(pspec)
        print(pspec)
PY
}


# is_workspace_member FILE REPO_ROOT — pub workspaces share one resolution
# governed by the root; a member must not carry its own dependency_overrides
# (pub rejects the duplicate). Version/constraint bumps still apply.
is_workspace_member() {
  local file="$1" repo_root="$2" rel dir ws
  rel="${file#"$repo_root"/}"
  dir=$(dirname "$rel")
  while IFS= read -r ws; do
    if python3 -c '
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r"^workspace:\s*\n((?:[ \t-][^\n]*\n|[ \t]*\n)+)", text, re.M)
if not m:
    raise SystemExit(1)
member = sys.argv[2]
entries = re.findall(r"^\s*-\s*(\S+)", m.group(1), re.M)
raise SystemExit(0 if member in entries else 1)
' "$ws" "$dir" 2>/dev/null; then
      return 0
    fi
  done < <(find "$repo_root" -maxdepth 2 -name pubspec.yaml -not -path '*/.dart_tool/*')
  return 1
}

# collect_pubspec SIBS_VAR FILE REPO — compute the --sibling args for FILE
# (direct fleet deps + everything reachable through `dep:` + `path:` pairs;
# overrides only apply from the root package, so an adapter resolving its app
# package via path needs the app's cross-repo deps overridden in ITS file).
collect_siblings() {
  local file="$1" repo="$2" consumer dep dep_repo rel
  consumer=$(pkg_name "$file")
  # Transitive closure over path deps: direct fleet deps + everything
  # reachable through `dep:` + `path:` pairs anywhere in the file
  # (overrides AND dependencies — examples and federated platform packages
  # reach the core through chains like adapter -> platform_interface -> app).
  local declared frontier next_target
  declared=$(fleet_deps_of "$file")
  frontier=$(path_override_targets "$file")
  local depth=0
  while [ -n "$frontier" ] && [ "$depth" -lt 6 ]; do
    depth=$((depth + 1))
    next_target=""
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      declared="$declared$(fleet_deps_of "$t")"$'\n'
      while IFS= read -r nt; do
        [ -n "$nt" ] || continue
        if [[ "$frontier" != *"$nt"* && "$next_target" != *"$nt"* ]]; then
          next_target="$next_target$nt"$'\n'
        fi
      done < <(path_override_targets "$t")
    done <<< "$frontier"
    frontier="$next_target"
  done
  declared=$(printf '%s\n' "$declared" | sort -u)
  SIBLINGS=()
  for dep in $declared; do
    dep_repo="${FLEET_PKG_REPO[$dep]:-}"
    [ -n "$dep_repo" ] || continue
    [ "$dep_repo" == "$repo" ] && continue          # same-repo family: own workflow
    [ "$dep" == "$consumer" ] && continue
    can_hosted_resolve "$dep" && continue
    [ -d "${FLEET_PKG_DIR[$dep]}" ] || continue
    rel=$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], os.path.dirname(os.path.abspath(sys.argv[2]))))' "${FLEET_PKG_DIR[$dep]}" "$file")
    SIBLINGS+=("--sibling" "$dep=$rel")
    echo -e "  ${YELLOW}dev override: $consumer -> $dep (path; ^$VERSION not on pub.dev yet)${NC}"
  done
}

for repo in "${FLEET_REPOS[@]}"; do
  repo_root="$DEV_ROOT/$repo"
  if [ ! -d "$repo_root/.git" ] && [ ! -f "$repo_root/pubspec.yaml" ]; then
    echo -e "${YELLOW}--- $repo: not found, skipping${NC}"
    continue
  fi
  echo -e "${BLUE}--- $repo${NC}"

  if [ "$DO_PULL" == "1" ] && [ -d "$repo_root/.git" ] && [ "$MODE" != "check" ]; then
    ( cd "$repo_root" && git pull --ff-only --rebase 2>&1 | tail -1 | sed 's/^/    pull: /' ) || true
  fi

  if [ "$MODE" == "check" ]; then
    while IFS= read -r rel; do
      file="$repo_root/$rel"
      check_pubspec "$file" "$repo_root" || FAILURES=$((FAILURES+1))
    done < <(find_pkg_pubspecs "$repo_root")
    check_readme "$repo_root" || FAILURES=$((FAILURES+1))
    continue
  fi

  while IFS= read -r rel; do
    file="$repo_root/$rel"
    name=$(pkg_name "$file")
    old=$(pkg_version "$file")
    OVERRIDE_ARGS=(--xml "$XML_OVERRIDE")
    if is_workspace_member "$file" "$repo_root"; then
      OVERRIDE_ARGS=()
    else
      collect_siblings "$file" "$repo" || true
      OVERRIDE_ARGS+=( ${SIBLINGS[@]+"${SIBLINGS[@]}"} )
    fi
    python3 "$SCRIPT_DIR/fleet_pubspec_tool.py" "$file" \
      --version "$VERSION" \
      ${OVERRIDE_ARGS[@]+"${OVERRIDE_ARGS[@]}"} \
      --constraint "${FLEET_PKG_NAMES[@]}" \
      || { echo -e "${RED}pubspec tool failed for $file${NC}"; FAILURES=$((FAILURES+1)); continue; }
    echo -e "  ${GREEN}$name: $old -> $VERSION${NC}"
    # README install guides at the same depth as the pubspec
    pkg_dir=$(dirname "$file")
    for readme in "$pkg_dir/README.md"; do
      [ -f "$readme" ] || continue
      update_readme "$readme"
      update_readme_pkg "$readme" "$name"
    done
    # example apps resolve together with their parent (dart >= 3.6 resolves
    # example/ in the parent's pub get) — same fleet treatment
    for ex in "$pkg_dir"/example/pubspec.yaml "$pkg_dir"/examples/*/pubspec.yaml; do
      [ -f "$ex" ] || continue
      collect_siblings "$ex" "$repo" || true
      python3 "$SCRIPT_DIR/fleet_pubspec_tool.py" "$ex" \
        --version "$VERSION" --xml "$XML_OVERRIDE" \
        ${SIBLINGS[@]+"${SIBLINGS[@]}"} \
        --constraint "${FLEET_PKG_NAMES[@]}" \
        || { echo -e "${RED}pubspec tool failed for $ex${NC}"; FAILURES=$((FAILURES+1)); }
    done
  done < <(find_pkg_pubspecs "$repo_root")

  # repo-level README install guides
  for readme in "$repo_root"/README.md "$repo_root"/packages/*/README.md; do
    [ -f "$readme" ] || continue
    update_readme "$readme"
  done

  ensure_changelog "$repo_root/CHANGELOG.md" "$CHANGELOG_MSG"
  ensure_publish_policy "$repo_root/PUBLISH.md"

  if [ "$DO_COMMIT" == "1" ] && [ -d "$repo_root/.git" ]; then
    ( cd "$repo_root"
      if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git status --porcelain | grep -v '^??')" ]; then
        git add -u
        git add CHANGELOG.md PUBLISH.md 2>/dev/null || true
        git commit -m "chore(fleet): mono-version alignment to $VERSION" \
                   -m "Versions, zuraffa constraint ^$VERSION, xml override $XML_OVERRIDE, README install guides and CHANGELOG refreshed by scripts/update_fleet.sh." \
                   >/dev/null && echo -e "  ${GREEN}committed${NC}"
      else
        echo -e "  ${YELLOW}nothing to commit${NC}"
      fi
    ) || FAILURES=$((FAILURES+1))
  fi
done

if [ "$MODE" == "check" ]; then
  if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}=== check failed: $FAILURES drift finding(s) ===${NC}"
    exit 1
  fi
  echo -e "${GREEN}=== check clean: whole fleet at $VERSION, xml $XML_OVERRIDE, READMEs aligned ===${NC}"
else
  echo -e "${GREEN}=== fleet updated to $VERSION ===${NC}"
  echo -e "Next: run tests, then push to master per repo. No PRs needed."
fi
