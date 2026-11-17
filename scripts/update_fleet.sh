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
#   5. prepends a CHANGELOG.md entry for the target version,
#   6. strips `dependency_overrides:` path entries that resolve OUTSIDE the
#      member repo (sibling checkouts are a dev-only surface — #2097).
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

# find_example_pubspecs REPO_ROOT — the `example/` and `examples/*/` manifests
# of every fleet package. dart >= 3.6 resolves an example as its OWN root, so
# `fleet_pubspec_tool.py` writes the same fleet overrides into them; they are
# deliberately absent from `find_pkg_pubspecs` (private dev surfaces, not
# published members) but they are still committed, so anything written into
# them has to be stripped too (issue #2097).
find_example_pubspecs() {
  local repo_root="$1" rel pkg_dir ex
  while IFS= read -r rel; do
    pkg_dir=$(dirname "$repo_root/$rel")
    for ex in "$pkg_dir"/example/pubspec.yaml "$pkg_dir"/examples/*/pubspec.yaml; do
      [ -f "$ex" ] || continue
      printf '%s\n' "${ex#"$repo_root"/}"
    done
  done < <(find_pkg_pubspecs "$repo_root")
}

# find_fleet_pubspecs REPO_ROOT — every manifest the apply loop WRITES: the
# fleet packages plus their example manifests. One walk, used by both the
# strip and its before-commit verification, so the check cannot disagree with
# the writes.
find_fleet_pubspecs() {
  find_pkg_pubspecs "$1"
  find_example_pubspecs "$1"
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

# The core package publishes a second version source: `lib/src/version.dart`
# (`const version = '...'`), exported as `package:zuraffa` `version` and used
# by `ZuraffaEngine.registerPackage` as the RUNNING version every consumer's
# generated-against constraint is compared to (issue #2095). A bump that
# moves pubspec.yaml and not this constant makes every consumer on the new
# release read the OLD version — 7.3.0/7.3.6/7.4.2/7.5.0 all shipped
# `const version = '7.2.0'`, so `PackageCompatibility` warned falsely in
# every consumer ("generated against zuraffa 7.3.0 which is newer than the
# running 7.2.0"). `scripts/publish.sh` already stamps it; this is the path
# PUBLISH.md documents for a fleet bump, so it must stamp it too.
#
# Both quote styles are read and written. The first version of these helpers
# keyed on the single-quoted form alone, so a double-quoted constant was
# neither stamped nor reported and #2095 could return with no signal at all
# (review of #2096) — the new Dart test still passed there, because it
# compares the constant's VALUE, not its shape.
version_const_decl() { # any line declaring the constant, whatever its shape
  grep -qE "^const (version|String version) *=" "$1"
}

# outside_overrides FILE REPO_ROOT strip|check — the one implementation of the
# `dependency_overrides:` path pass (issue #2097), in two modes.
#
# `collect_siblings()` writes sibling checkouts in as `path:` overrides so a
# not-yet-published fleet constraint resolves in dev mode, but those paths
# exist only on a machine that HAS the sibling checkout — committed, they red
# the member's first `flutter pub get` (`could not find package zuraffa at
# "../zuraffa"`) and block every later PR.
#
#   strip — drop every `path:` override whose target resolves OUTSIDE
#           REPO_ROOT. The fleet `xml:` policy line, other entries and in-repo
#           path deps (a dev surface like `path: ./local/foo`) stay.
#           Idempotent, and written through a temp file + rename so a crash
#           mid-write cannot truncate the manifest.
#   check — exit 1 and name every survivor (the `--check` drift gate).
#
# REPO_ROOT is the MEMBER REPO ROOT, not the manifest's own directory: a
# relative path resolves against the manifest's directory, but the
# containment boundary is the repo — otherwise a legitimate in-repo sibling
# (`packages/adapter` -> `path: ../core`, an example's `path: ..`) is judged
# outside and stripped.
outside_overrides() {
  local file="$1" repo_root="$2" mode="${3:-strip}"
  [ -f "$file" ] || return 0
  # This guard and the python HEADER regex below are the SAME pattern — they
  # drifted once, and `dependency_overrides:  # note` then passed the grep
  # while python no-oped on it in silence. `[[:space:]]` (not `[[:blank:]]`)
  # keeps a CRLF manifest matching here too: python normalizes CRLF before it
  # matches, so the guard must not be the one that rejects the line.
  grep -qE '^dependency_overrides:[[:space:]]*(#.*)?$' "$file" || return 0
  python3 - "$file" "$repo_root" "$mode" <<'PY'
import os, re, sys, tempfile

path, mode = sys.argv[1], sys.argv[3]
root = os.path.abspath(sys.argv[2])

text = open(path, 'rb').read().decode('utf-8')
# Remember the line endings: a bare read/write round-trip rewrote a CRLF
# manifest as LF.
crlf = '\r\n' in text and text.count('\r\n') == text.count('\n')
text = text.replace('\r\n', '\n')
lines = text.split('\n')
if lines and lines[-1] == '':
    lines.pop()

HEADER = re.compile(r'^dependency_overrides:\s*(?:#.*)?$')
start = next((i for i, l in enumerate(lines) if HEADER.match(l)), None)
if start is None:
    raise SystemExit(0)
end = len(lines)
for i in range(start + 1, len(lines)):
    if lines[i] and not lines[i].startswith((' ', '\t', '#')):
        end = i
        break

def indent(line):
    return len(line) - len(line.lstrip(' '))

def scalar(value):
    """A YAML scalar's value — surrounding quotes decoded, comment dropped."""
    value = value.strip()
    if not value:
        return None
    if value[0] in '"\'':
        quote, out, i = value[0], [], 1
        while i < len(value):
            c = value[i]
            if c == '\\' and quote == '"' and i + 1 < len(value):
                out.append(value[i + 1]); i += 2; continue
            if c == quote:
                if quote == "'" and value[i + 1:i + 2] == "'":
                    out.append("'"); i += 2; continue
                break
            out.append(c); i += 1
        return ''.join(out)
    return value.split(' #')[0].strip()

KEY = re.compile(r'^([ \t]+)([\w][\w-]*):(.*)$')
PATH = re.compile(r'^[ \t]+path:[ \t]*(.+?)[ \t]*$')

# The section's child indent — the indent of its first real content. Only
# lines at THIS indent are override keys, so a nested `git:` block's own
# `path:` is never read as the override's target.
content = [l for l in lines[start + 1:end]
           if l.strip() and not l.lstrip().startswith('#')]
child = min((indent(l) for l in content), default=None)

drop = []      # [first, last) line ranges to delete
outside = []   # (key, value) whose target escapes the repo
i = start + 1
while child is not None and i < end:
    km = KEY.match(lines[i])
    if not km or indent(lines[i]) != child:
        i += 1
        continue
    j = i + 1
    while j < end and (not lines[j].strip() or indent(lines[j]) > child):
        j += 1
    body = lines[i + 1:j]
    direct = [l for l in body if l.strip() and not l.lstrip().startswith('#')]
    nested = min((indent(l) for l in direct), default=None)
    target = None
    if nested is not None:
        for l in body:
            pm = PATH.match(l)
            if pm and indent(l) == nested:
                target = scalar(pm.group(1))
                break
    if target:
        base = os.path.dirname(os.path.abspath(path))
        resolved = os.path.normpath(os.path.join(base, target))
        if resolved != root and not resolved.startswith(root + os.sep):
            outside.append((km.group(2), target))
            drop.append((i, j))
    i = j

def rel(p):
    try:
        return os.path.relpath(p, root)
    except ValueError:
        return p

if mode == 'check':
    for key, value in outside:
        print('%s: dependency_overrides %s -> path: %s (resolves outside %s)'
              % (rel(path), key, value, root))
    raise SystemExit(1 if outside else 0)

if not outside:
    raise SystemExit(0)

kept = [n for n, l in enumerate(lines[start + 1:end], start + 1)
        if l.strip() and not l.lstrip().startswith('#')
        and not any(a <= n < b for a, b in drop)]
out = lines[:]
if kept:
    for a, b in reversed(drop):
        del out[a:b]
else:
    # Nothing but the dropped entries was left — the header and the blank
    # lines around it go with them.
    del out[start:end]
text = '\n'.join(out)
if text:
    text += '\n'
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or '.',
                           prefix='.pubspec-', suffix='.tmp')
try:
    with os.fdopen(fd, 'w', newline='') as f:
        f.write(text.replace('\n', '\r\n' if crlf else '\n'))
    os.replace(tmp, path)
except BaseException:
    os.unlink(tmp)
    raise
for key, value in outside:
    print('  stripped path override %s -> %s' % (key, value))
PY
}

strip_outside_overrides() { # FILE [REPO_ROOT] — REPO_ROOT is the containment
  # boundary; it defaults to the manifest's own directory, so a caller that
  # has only a file still gets the old behaviour. The apply loop always
  # passes the member repo root, which is what issue #2097 needs.
  outside_overrides "$1" "${2:-$(dirname "$1")}" strip
}

check_outside_overrides() { # FILE REPO_ROOT — a member still carrying an
  # out-of-repo path override is drift: it resolves only where the sibling
  # checkout exists, so `--check` must report it (it used to be blind).
  local out
  if out=$(outside_overrides "$1" "$2" check); then
    return 0
  fi
  [ -n "$out" ] && printf '%s\n' "$out"
  return 1
}

version_const_value() { # the declared value, either quote style
  sed -n "s/^const version = [\"']\([^\"']*\)[\"'].*/\1/p" "$1" | head -1 || true
}

update_version_const() {
  local repo_root="$1"
  local file="$repo_root/lib/src/version.dart"
  local tmp="$file.tmp"
  [ -f "$file" ] || return 0
  version_const_decl "$file" || return 0
  # A declaration this script cannot read is not silently left alone: check
  # mode reports it as drift (below), and apply mode says so out loud.
  if [ -z "$(version_const_value "$file")" ]; then
    echo -e "  ${YELLOW}left $file alone: it declares the version in a shape this script cannot read${NC}"
    return 0
  fi
  # tmp file + mv rather than `sed -i`: the BSD and GNU forms of `-i` are
  # incompatible, and this is the same shape `ensure_changelog` above uses.
  # A failed write must not abort the whole fleet bump mid-run (earlier repos
  # are already committed by then) and must not leave the temp file behind.
  if ! sed -E "s/^const version = ('[^']*'|\"[^\"]*\")/const version = '$VERSION'/" \
      "$file" > "$tmp"; then
    rm -f "$tmp"
    echo -e "  ${RED}could not write $tmp${NC}" >&2
    return 1
  fi
  if ! mv "$tmp" "$file"; then
    rm -f "$tmp"
    echo -e "  ${RED}could not replace $file${NC}" >&2
    return 1
  fi
  return 0
}

check_version_const() {
  local repo_root="$1"
  local file="$repo_root/lib/src/version.dart"
  local ver
  [ -f "$file" ] || return 0
  version_const_decl "$file" || return 0
  ver=$(version_const_value "$file")
  if [ -z "$ver" ]; then
    echo -e "  ${RED}version drift: $file declares the version in a shape this script cannot read${NC}"
    return 1
  fi
  [ "$ver" == "$VERSION" ] || {
    echo -e "  ${RED}version drift: lib/src/version.dart $ver != $VERSION${NC}"
    return 1
  }
  return 0
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
  # An out-of-repo path override resolves only where the sibling checkout
  # exists — committed, the member's first `flutter pub get` reds (#2097).
  # This is checked BEFORE the workspace-member return: a member must not
  # carry its own overrides at all, but if one does, a sibling path in it is
  # still drift. Check mode used to be blind here — it `continue`d before
  # the strip and `check_pubspec` only asserted the `xml:` line.
  check_outside_overrides "$file" "$repo_root" || ok=1
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
    # example/ and examples/*/ manifests are written by the same tool run
    # (dart >= 3.6 resolves them as their own root) but `find_pkg_pubspecs`
    # excludes them, so the member loop above never reports their drift.
    while IFS= read -r rel; do
      check_outside_overrides "$repo_root/$rel" "$repo_root" || FAILURES=$((FAILURES+1))
    done < <(find_example_pubspecs "$repo_root")
    check_readme "$repo_root" || FAILURES=$((FAILURES+1))
    check_version_const "$repo_root" || FAILURES=$((FAILURES+1))
    continue
  fi

  # Did every package manifest of THIS repo actually move? A failed pubspec
  # update leaves `version:` at the old release; stamping the constant and
  # committing anyway would ship a core that declares a version its pubspec
  # does not (review of #2096). One repo failing must not stop the others.
  repo_failed=0

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
      || { echo -e "${RED}pubspec tool failed for $file${NC}"; FAILURES=$((FAILURES+1)); repo_failed=1; continue; }
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
        || { echo -e "${RED}pubspec tool failed for $ex${NC}"; FAILURES=$((FAILURES+1)); repo_failed=1; }
    done
  done < <(find_pkg_pubspecs "$repo_root")

  # Sibling `path:` overrides resolve only where the sibling checkout exists
  # — strip them from every manifest this pass wrote (fleet packages AND
  # their example/examples apps) before anything is committed, or the
  # member's first `flutter pub get` reds and blocks every later PR
  # (issue #2097). The xml policy override and in-repo path deps stay.
  while IFS= read -r rel; do
    strip_outside_overrides "$repo_root/$rel" "$repo_root" || {
      echo -e "${RED}  could not strip out-of-repo overrides from $rel${NC}" >&2
      FAILURES=$((FAILURES+1)); repo_failed=1; continue
    }
    # Verify, do not trust: a survivor IS the bug the strip exists to
    # prevent, so it fails the repo instead of riding into the commit. The
    # old single call could not do this — it handed a DIRECTORY to a
    # file-only helper, whose grep/python failure it never checked.
    check_outside_overrides "$repo_root/$rel" "$repo_root" || repo_failed=1
  done < <(find_fleet_pubspecs "$repo_root")

  if [ "$repo_failed" == "1" ]; then
    # Leave this repo exactly as the failure left it: no version stamp, no
    # changelog, no commit. The alternative is a release whose core constant
    # says the new version while the manifest still declares the old one —
    # the drift #2095 was about, pointed the other way. An override that
    # survived the strip is the same class of failure: the manifest would
    # carry the sibling path into the commit (issue #2097).
    echo -e "${RED}  manifest update failed — skipping version stamp and commit for $repo${NC}"
    continue
  fi

  # repo-level README install guides
  for readme in "$repo_root"/README.md "$repo_root"/packages/*/README.md; do
    [ -f "$readme" ] || continue
    update_readme "$readme"
  done

  ensure_changelog "$repo_root/CHANGELOG.md" "$CHANGELOG_MSG"
  ensure_publish_policy "$repo_root/PUBLISH.md"
  # `lib/src/version.dart` is the running version every consumer's
  # compatibility check reads (issue #2095) — stamp it with the pubspec so a
  # fleet bump cannot ship the previous release's constant. A failed write
  # counts as a failure and does not abort the run (the repo stays stamped-
  # less and the operator sees it in the tally).
  update_version_const "$repo_root" || FAILURES=$((FAILURES+1))

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
