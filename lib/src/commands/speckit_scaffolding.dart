/// `SpeckitScaffoldingWriter` — emits the current speckit helper scripts
/// into an existing repo (issue #1417).
///
/// Bug #1417: affected repos gitignore `.specify/*` (only
/// `constitution.md` force-added), so `.specify/scripts/bash/*` lived only
/// on the original machine and every speckit-* skill died at Step 1 with
/// `bash .specify/scripts/bash/setup-plan.sh: No such file or directory
/// (exit 127)` on a fresh clone. No zfa verb could regenerate the
/// scaffolding into an existing repo: `zfa setup` creates a new app,
/// `zfa initialize` only wires pubspec deps, and `zfa generate-commands`
/// regenerates command .md files, not bash helpers.
///
/// The fix: `zfa initialize --speckit` emits the four Step-1 helper scripts
/// (the exact set the speckit-plan/-tasks/-implement skills source) from the
/// embedded constants below — the same treaty as `kZuraffaSpecTemplate`
/// (`lib/src/cli/writers/tdd/spec_template_writer.dart`): content versioned
/// with the CLI package so the skills and the scripts they invoke cannot
/// drift, no repo checkout required. Constitution I (CLI-built only):
/// nothing is hand-scaffolded; the framework owns the emission.
///
/// The embedded constants MUST stay byte-identical to the framework repo's
/// canonical `.specify/scripts/bash/` copies — the drift-guard test
/// (U-1417-b9 in `test/commands/initialize_speckit_test.dart`) fails the
/// suite on divergence and points at the re-embed tool
/// (`scripts/embed_speckit_scripts.py`).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Result of one [SpeckitScaffoldingWriter.emit] run.
class SpeckitEmitResult {
  const SpeckitEmitResult({
    required this.created,
    required this.upToDate,
    required this.skipped,
    required this.overwritten,
    required this.gitignoreUpdated,
    this.gitignorePath,
  });

  /// Scripts written for the first time.
  final List<String> created;

  /// Existing scripts identical to the embedded content (nothing to do,
  /// even under --force).
  final List<String> upToDate;

  /// Existing scripts that differ and were left untouched (no --force).
  final List<String> skipped;

  /// Existing scripts overwritten via --force.
  final List<String> overwritten;

  /// Whether the `.gitignore` force-include block was appended.
  final bool gitignoreUpdated;

  final String? gitignorePath;
}

/// Emits the embedded speckit helper scripts into
/// `<projectRoot>/.specify/scripts/bash/`.
class SpeckitScaffoldingWriter {
  const SpeckitScaffoldingWriter();

  /// The scripts emitted for the skills' Step 1, in emission order.
  static const List<String> scriptNames = [
    'common.sh',
    'setup-plan.sh',
    'check-prerequisites.sh',
    'setup-tasks.sh',
  ];

  /// Content for each [scriptNames] entry (byte-identical to the canonical
  /// framework copies — see the drift guard, spec FR-002 / SC-003).
  static Map<String, String> embeddedScripts() => {
    'common.sh': kSpeckitCommonSh,
    'setup-plan.sh': kSpeckitSetupPlanSh,
    'check-prerequisites.sh': kSpeckitCheckPrerequisitesSh,
    'setup-tasks.sh': kSpeckitSetupTasksSh,
  };

  /// Marker comment keys the idempotent `.gitignore` force-include block.
  static const String gitignoreMarker =
      '# zfa initialize --speckit: keep the speckit helper scripts tracked';

  /// Rules that would ignore `.specify/scripts` (the emitted helpers),
  /// classified by gitignore semantics (each matched root-anchored or not —
  /// a leading `/` is normalized away before matching since this writer
  /// only manages the root `.gitignore`):
  ///
  /// - parent-excluding: the `.specify` directory itself. Git never
  ///   descends into an excluded directory, so plain negations underneath
  ///   are void — the force-include block must first restore the parent
  ///   (review finding on the `.specify/` shape: the plain block reported
  ///   success while the helpers stayed ignored).
  /// - child-excluding: a wildcard under an intact `.specify` parent; the
  ///   plain script negations re-include the helpers.
  /// - direct: `.specify/scripts` named explicitly; plain negations work.
  static const List<String> _parentExcludingRules = ['.specify/', '.specify'];
  static const List<String> _childExcludingRules = [
    '.specify/*',
    '.specify/**',
  ];
  static const List<String> _directExcludingRules = [
    '.specify/scripts',
    '.specify/scripts/',
    '.specify/scripts/*',
    '.specify/scripts/**',
  ];

  Future<SpeckitEmitResult> emit(
    String projectRoot, {
    bool force = false,
    bool dryRun = false,
    void Function(String message)? log,
  }) {
    final say = log ?? (_) {};
    final bashDir = Directory(
      p.join(projectRoot, '.specify', 'scripts', 'bash'),
    );

    final created = <String>[];
    final upToDate = <String>[];
    final skipped = <String>[];
    final overwritten = <String>[];
    final scripts = embeddedScripts();

    for (final name in scriptNames) {
      final file = File(p.join(bashDir.path, name));
      final content = scripts[name]!;
      if (file.existsSync()) {
        final existing = file.readAsStringSync();
        if (existing == content) {
          upToDate.add(name);
          continue;
        }
        if (!force) {
          skipped.add(name);
          continue;
        }
        if (!dryRun) {
          file.writeAsStringSync(content);
          _makeExecutable(file);
        }
        overwritten.add(name);
        continue;
      }
      if (!dryRun) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content);
        _makeExecutable(file);
      }
      created.add(name);
    }

    var gitignoreUpdated = false;
    String? gitignorePath;
    final gi = File(p.join(projectRoot, '.gitignore'));
    if (gi.existsSync()) {
      final scan = _needsForceInclude(gi.readAsStringSync());
      if (scan.needed) {
        gitignorePath = gi.path;
        if (!dryRun) {
          _writeForceInclude(gi, parentExcluded: scan.parentExcluded);
        }
        gitignoreUpdated = true;
      }
    }

    if (!dryRun) {
      _warnIfStillIgnored(projectRoot, say);
    }

    for (final name in created) {
      say('✓ Emitted .specify/scripts/bash/$name');
    }
    for (final name in overwritten) {
      say('✓ Overwritten .specify/scripts/bash/$name (--force)');
    }
    for (final name in upToDate) {
      say('• Up-to-date .specify/scripts/bash/$name (identical to embedded)');
    }
    for (final name in skipped) {
      say(
        '• Skipped .specify/scripts/bash/$name (differs; use --force to overwrite)',
      );
    }
    if (gitignoreUpdated) {
      say('✓ .gitignore: appended force-include block for .specify/scripts');
    }

    return Future.value(
      SpeckitEmitResult(
        created: created,
        upToDate: upToDate,
        skipped: skipped,
        overwritten: overwritten,
        gitignoreUpdated: gitignoreUpdated,
        gitignorePath: gitignorePath,
      ),
    );
  }

  /// Scans [content] for a rule that would ignore the emitted helpers
  /// (checked per line, honoring negations, comments, and root-anchored
  /// spellings). Returns the git verdict:
  ///
  /// - `needed`: the helpers end up ignored — a force-include block is
  ///   required.
  /// - `parentExcluded`: the last parent-shape rule excludes the `.specify`
  ///   directory itself, so the block must restore the parent before the
  ///   script negations (they are void under an excluded parent).
  ({bool needed, bool parentExcluded}) _needsForceInclude(String content) {
    var parentExcluded = false;
    var scriptsExcluded = false;
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      var rule = line;
      var negated = false;
      if (rule.startsWith('!')) {
        negated = true;
        rule = rule.substring(1);
      }
      // Root-anchored spellings (`/.specify/`) match the same paths in the
      // root .gitignore this writer manages.
      if (rule.startsWith('/')) rule = rule.substring(1);
      if (_parentExcludingRules.contains(rule)) {
        // Last parent-shape match decides whether git descends into
        // `.specify` at all.
        parentExcluded = !negated;
      } else if (_childExcludingRules.contains(rule) ||
          _directExcludingRules.contains(rule)) {
        scriptsExcluded = !negated;
      }
    }
    return (
      needed: parentExcluded || scriptsExcluded,
      parentExcluded: parentExcluded,
    );
  }

  /// Appends the force-include block (last match wins in gitignore
  /// semantics), or — when a rule added after our block re-excludes the
  /// helpers — moves the managed block to the end so it wins again. The
  /// file ends with exactly one marker block.
  void _writeForceInclude(File gitignore, {required bool parentExcluded}) {
    var existing = gitignore.readAsStringSync();
    if (existing.contains(gitignoreMarker)) {
      existing = _stripManagedBlocks(existing);
    }
    final sb = StringBuffer(existing);
    if (existing.isNotEmpty && !existing.endsWith('\n')) sb.writeln();
    sb.writeln(gitignoreMarker);
    if (parentExcluded) {
      // Restore the excluded parent, then re-exclude its other children
      // (user intent preserved) so only the helpers come back. A plain
      // `!.specify/scripts` cannot re-include anything while the parent
      // directory is excluded.
      sb
        ..writeln('!/.specify/')
        ..writeln('.specify/*');
    }
    sb
      ..writeln('!.specify/scripts')
      ..writeln('!.specify/scripts/**');
    gitignore.writeAsStringSync(sb.toString());
  }

  /// Every line this writer may emit inside a managed block (both shapes —
  /// used to strip an existing block regardless of which shape wrote it).
  static const Set<String> _managedBlockLines = {
    '!/.specify/',
    '!.specify/',
    '.specify/*',
    '!.specify/scripts',
    '!.specify/scripts/**',
  };

  /// Removes every marker-keyed managed block (marker line plus the rule
  /// lines that follow it), keeping all other content byte-identical.
  String _stripManagedBlocks(String content) {
    final kept = <String>[];
    var skipping = false;
    for (final line in content.split('\n')) {
      if (line.trim() == gitignoreMarker) {
        skipping = true;
        continue;
      }
      if (skipping) {
        if (line.isEmpty || _managedBlockLines.contains(line.trim())) {
          continue;
        }
        skipping = false;
      }
      kept.add(line);
    }
    return kept.join('\n');
  }

  /// Best-effort executable bit on the emitted shell scripts (the canonical
  /// framework copies are tracked 755, and their own --help prints
  /// `./check-prerequisites.sh`). dart:io has no chmod API, so shell out;
  /// platforms without chmod keep the default mode, where
  /// `bash <script>` still works.
  void _makeExecutable(File file) {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', <String>['755', file.path]);
    } on ProcessException {
      // chmod unavailable — content is what the drift guard pins.
    }
  }

  /// Fail-loud guard: when the emitted helpers are still git-ignored after
  /// the force-include update (an unclassified rule spelling won over the
  /// block), warn instead of silently reproducing the exit-127 bug this
  /// command exists to fix. A no-op outside a git repository.
  void _warnIfStillIgnored(String projectRoot, void Function(String) say) {
    try {
      final probe = Process.runSync('git', <String>[
        'check-ignore',
        '--',
        '.specify/scripts/bash/common.sh',
      ], workingDirectory: projectRoot);
      if (probe.exitCode == 0) {
        say(
          '⚠ .specify/scripts/bash/ is still ignored by git — the helpers '
          'will not be tracked on a fresh clone. Inspect .gitignore and '
          're-run zfa initialize --speckit.',
        );
      }
    } on ProcessException {
      // git unavailable — nothing to probe.
    }
  }
}

// BEGIN EMBEDDED SCRIPTS
/// Byte-identical embed of `.specify/scripts/bash/common.sh`
const String kSpeckitCommonSh = r'''#!/usr/bin/env bash
# Common functions and variables for all scripts

# Find repository root by searching upward for .specify directory
# This is the primary marker for spec-kit projects
find_specify_root() {
    local dir="${1:-$(pwd)}"
    # Normalize to absolute path to prevent infinite loop with relative paths
    # Use -- to handle paths starting with - (e.g., -P, -L)
    dir="$(cd -- "$dir" 2>/dev/null && pwd)" || return 1
    local prev_dir=""
    while true; do
        if [ -d "$dir/.specify" ]; then
            echo "$dir"
            return 0
        fi
        # Stop if we've reached filesystem root or dirname stops changing
        if [ "$dir" = "/" ] || [ "$dir" = "$prev_dir" ]; then
            break
        fi
        prev_dir="$dir"
        dir="$(dirname "$dir")"
    done
    return 1
}

# Resolve an explicit SPECIFY_INIT_DIR project override (the directory that
# *contains* .specify/), for non-interactive / CI use — e.g. running a Spec Kit
# command against a member project from a monorepo root without cd.
#
# Precondition: SPECIFY_INIT_DIR is non-empty. Echoes the validated absolute
# project root, or prints an error and returns 1. Strict by design: the path
# must exist and contain .specify/, with no silent fallback to cwd or the
# script-location default (which would silently write to the wrong project).
#
# This is the single resolver: bundled extensions inherit it by sourcing core
# (e.g. the git extension's create-new-feature-branch) rather than duplicating it.
resolve_specify_init_dir() {
    local init_root
    # Normalize: relative paths resolve against $(pwd); a trailing slash collapses.
    # CDPATH="" so a relative value cannot be resolved against the caller's CDPATH
    # (which would also echo to stdout and corrupt the captured path).
    if ! init_root="$(CDPATH="" cd -- "$SPECIFY_INIT_DIR" 2>/dev/null && pwd)"; then
        echo "ERROR: SPECIFY_INIT_DIR does not point to an existing directory: $SPECIFY_INIT_DIR" >&2
        return 1
    fi
    if [[ ! -d "$init_root/.specify" ]]; then
        echo "ERROR: SPECIFY_INIT_DIR is not a Spec Kit project (no .specify/ directory): $init_root" >&2
        return 1
    fi
    printf '%s\n' "$init_root"
}

# Get repository root, prioritizing .specify directory
# This prevents using a parent repository when spec-kit is initialized in a subdirectory
get_repo_root() {
    # Explicit project override wins (see resolve_specify_init_dir).
    if [[ -n "${SPECIFY_INIT_DIR:-}" ]]; then
        resolve_specify_init_dir
        return
    fi

    # First, look for .specify directory (spec-kit's own marker)
    local specify_root
    if specify_root=$(find_specify_root); then
        echo "$specify_root"
        return
    fi

    # Final fallback to script location
    local script_dir="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    (cd "$script_dir/../../.." && pwd)
}

# Get current feature name from explicit state only.
# Returns the feature identifier or empty string if none is set.
# Feature state is set by SPECIFY_FEATURE (from create-new-feature or
# the git extension) or implicitly via .specify/feature.json.
get_current_branch() {
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # No explicit feature set — caller must handle this via feature.json
    # in get_feature_paths(). Return empty to signal "unknown".
    echo ""
}

# Safely read .specify/feature.json's "feature_directory" value.
# Prints the raw value (possibly relative) to stdout, or empty string if the file
# is missing, unparseable, or does not contain the key. Always returns 0 so callers
# under `set -e` cannot be aborted by parser failure.
# Parser order mirrors the historical get_feature_paths behavior: jq -> python3 -> grep/sed.
read_feature_json_feature_directory() {
    local repo_root="$1"
    local fj="$repo_root/.specify/feature.json"
    [[ -f "$fj" ]] || { printf '%s' ''; return 0; }

    # Try parsers in order (jq -> python3 -> grep/sed), falling through on
    # failure. Selection is by *parse success*, not mere availability: on
    # Windows `python3` commonly resolves to the Microsoft Store App Execution
    # Alias stub, which passes `command -v` but fails at runtime (exit 49), so
    # an availability-gated `elif` would pick python3, swallow its failure, and
    # never reach the grep/sed fallback -- leaving feature.json unreadable even
    # though it is valid (issue #3304).
    local _fd=''
    if command -v jq >/dev/null 2>&1; then
        if ! _fd=$(jq -r '.feature_directory // empty' "$fj" 2>/dev/null); then
            _fd=''
        fi
    fi
    if [[ -z "$_fd" ]] && command -v python3 >/dev/null 2>&1; then
        # Use Python so pretty-printed/multi-line JSON still parses correctly.
        if ! _fd=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); v=d.get('feature_directory'); print(v if v else '')" "$fj" 2>/dev/null); then
            _fd=''
        fi
    fi
    if [[ -z "$_fd" ]]; then
        # Last-resort single-line grep/sed fallback. The `|| true` guards against
        # grep returning 1 (no match) aborting under `set -e` / `pipefail`.
        _fd=$( { grep -E '"feature_directory"[[:space:]]*:' "$fj" 2>/dev/null || true; } \
            | head -n 1 \
            | sed -E 's/^[^:]*:[[:space:]]*"([^"]*)".*$/\1/' )
    fi

    printf '%s' "$_fd"
    return 0
}

# Persist a feature_directory value to .specify/feature.json.
# Writes only when the file is missing or the value differs from what's stored.
# Accepts the raw (possibly relative) path — callers should pass the original
# user-supplied value, not the normalized absolute path.
_persist_feature_json() {
    local repo_root="$1"
    local feature_dir_value="$2"
    local fj="$repo_root/.specify/feature.json"

    # Strip repo_root prefix if the value is absolute and under repo_root
    if [[ "$feature_dir_value" == "$repo_root/"* ]]; then
        feature_dir_value="${feature_dir_value#"$repo_root/"}"
    fi

    # Read current value (if any) and skip write when unchanged
    local current_val
    current_val=$(read_feature_json_feature_directory "$repo_root")
    if [[ "$current_val" == "$feature_dir_value" ]]; then
        return 0
    fi

    # Ensure .specify/ directory exists
    mkdir -p "$repo_root/.specify"

    # Write feature.json — prefer jq for safe JSON, fall back to printf
    if command -v jq >/dev/null 2>&1; then
        jq -cn --arg fd "$feature_dir_value" '{feature_directory:$fd}' > "$fj"
    else
        printf '{"feature_directory":"%s"}\n' "$(json_escape "$feature_dir_value")" > "$fj"
    fi
}

get_feature_paths() {
    # Read-only callers (e.g. check-prerequisites.sh --paths-only) pass
    # --no-persist so pure path resolution never writes .specify/feature.json,
    # which would dirty the working tree or overwrite a pinned value (issue #3025).
    local no_persist=false
    if [[ "${1:-}" == "--no-persist" ]]; then
        no_persist=true
        shift
    fi

    # Split decl/assignment so a SPECIFY_INIT_DIR validation failure in
    # get_repo_root propagates as a hard error instead of being masked by `local`.
    local repo_root
    repo_root=$(get_repo_root) || return 1
    local current_branch
    current_branch=$(get_current_branch)

    # Resolve feature directory.  Priority:
    #   1. SPECIFY_FEATURE_DIRECTORY env var (explicit override)
    #   2. .specify/feature.json "feature_directory" key (persisted by specify command)
    #   3. Error — no feature context available
    local feature_dir
    if [[ -n "${SPECIFY_FEATURE_DIRECTORY:-}" ]]; then
        feature_dir="$SPECIFY_FEATURE_DIRECTORY"
        # Normalize relative paths to absolute under repo root
        [[ "$feature_dir" != /* ]] && feature_dir="$repo_root/$feature_dir"
        # Persist to feature.json so future sessions without the env var still
        # work — unless the caller opted out for read-only resolution (#3025).
        if [[ "$no_persist" != true ]]; then
            _persist_feature_json "$repo_root" "$SPECIFY_FEATURE_DIRECTORY"
        fi
    elif [[ -f "$repo_root/.specify/feature.json" ]]; then
        local _fd
        _fd=$(read_feature_json_feature_directory "$repo_root")
        if [[ -n "$_fd" ]]; then
            feature_dir="$_fd"
            # Normalize relative paths to absolute under repo root
            [[ "$feature_dir" != /* ]] && feature_dir="$repo_root/$feature_dir"
        else
            echo "ERROR: Feature directory not found. Set SPECIFY_FEATURE_DIRECTORY or ensure .specify/feature.json contains feature_directory." >&2
            return 1
        fi
    else
        echo "ERROR: Feature directory not found. Set SPECIFY_FEATURE_DIRECTORY or run the specify command to create .specify/feature.json." >&2
        return 1
    fi

    # When no branch context exists (no SPECIFY_FEATURE, feature resolved via
    # SPECIFY_FEATURE_DIRECTORY or feature.json), fall back to the feature
    # directory basename so CURRENT_BRANCH is a usable identifier rather than
    # an empty, misleading value (issue #3026).
    if [[ -z "$current_branch" ]]; then
        local feature_dir_trimmed="${feature_dir%/}"
        current_branch="${feature_dir_trimmed##*/}"
    fi

    # Use printf '%q' to safely quote values, preventing shell injection
    # via crafted branch names or paths containing special characters
    printf 'REPO_ROOT=%q\n' "$repo_root"
    printf 'CURRENT_BRANCH=%q\n' "$current_branch"
    printf 'FEATURE_DIR=%q\n' "$feature_dir"
    printf 'FEATURE_SPEC=%q\n' "$feature_dir/spec.md"
    printf 'IMPL_PLAN=%q\n' "$feature_dir/plan.md"
    printf 'TASKS=%q\n' "$feature_dir/tasks.md"
    printf 'RESEARCH=%q\n' "$feature_dir/research.md"
    printf 'DATA_MODEL=%q\n' "$feature_dir/data-model.md"
    printf 'QUICKSTART=%q\n' "$feature_dir/quickstart.md"
    printf 'CONTRACTS_DIR=%q\n' "$feature_dir/contracts"
}

# Check if jq is available for safe JSON construction
has_jq() {
    command -v jq >/dev/null 2>&1
}

get_invoke_separator() {
    local repo_root="${1:-$(get_repo_root)}"
    if [[ "${_SPECIFY_INVOKE_SEPARATOR_CACHE_REPO_ROOT:-}" == "$repo_root" && -n "${_SPECIFY_INVOKE_SEPARATOR_CACHE_VALUE:-}" ]]; then
        printf '%s\n' "$_SPECIFY_INVOKE_SEPARATOR_CACHE_VALUE"
        return 0
    fi

    local integration_json="$repo_root/.specify/integration.json"
    local separator="."
    local parsed=0

    if [[ -f "$integration_json" ]]; then
        # Try parsers in order (jq -> python3 -> awk), falling through on
        # failure. Selection is by *parse success*, not mere availability: on
        # Windows `python3` commonly resolves to the Microsoft Store App
        # Execution Alias stub, which passes `command -v` but fails at runtime
        # (exit 49). An availability-gated branch would pick python3, swallow
        # its failure, and — because this function historically had no text
        # fallback — silently return "." even for `-`-separator integrations
        # (e.g. forge, cline), yielding wrong command hints (issue #3304).
        if command -v jq >/dev/null 2>&1; then
            local jq_separator
            if jq_separator=$(jq -r '(.default_integration // .integration // "") as $k | if $k == "" then "." else (.integration_settings[$k].invoke_separator // ".") end' "$integration_json" 2>/dev/null); then
                case "$jq_separator" in
                    "."|"-") separator="$jq_separator"; parsed=1 ;;
                esac
            fi
        fi

        if [[ "$parsed" -eq 0 ]] && command -v python3 >/dev/null 2>&1; then
            local py_separator
            if py_separator=$(python3 - "$integration_json" <<'PY' 2>/dev/null
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        state = json.load(fh)
    key = state.get("default_integration") or state.get("integration") or ""
    settings = state.get("integration_settings")
    separator = "."
    if isinstance(key, str) and isinstance(settings, dict):
        entry = settings.get(key)
        if isinstance(entry, dict) and entry.get("invoke_separator") in {".", "-"}:
            separator = entry["invoke_separator"]
    print(separator)
except Exception:
    sys.exit(1)
PY
); then
                case "$py_separator" in
                    "."|"-") separator="$py_separator"; parsed=1 ;;
                esac
            fi
        fi

        if [[ "$parsed" -eq 0 ]]; then
            # Last-resort text fallback for environments with neither jq nor a
            # working python3 (e.g. stock Windows + Git Bash). Reads the active
            # integration key (default_integration, else integration) and its
            # invoke_separator from within the integration_settings object.
            # Handles both pretty-printed (the written form) and compact JSON.
            # Accumulate all lines into one buffer in END rather than using
            # gawk-only whole-file slurp (RS="^$"), so this stays portable to
            # the BSD awk on macOS.
            local awk_separator
            awk_separator=$(awk '
                function keyval(d, name,   v) {
                    if (match(d, "\"" name "\"[ \t\r\n]*:[ \t\r\n]*\"[^\"]*\"")) {
                        v=substr(d,RSTART,RLENGTH); sub(/^.*:[ \t\r\n]*"/,"",v); sub(/"$/,"",v); return v
                    }
                    return ""
                }
                { doc = doc $0 "\n" }
                END {
                    key=keyval(doc,"default_integration"); if (key=="") key=keyval(doc,"integration")
                    sep="."
                    if (key!="") {
                        settings=doc
                        if (match(doc, /"integration_settings"[ \t\r\n]*:[ \t\r\n]*[{]/)) {
                            settings=substr(doc, RSTART+RLENGTH-1)
                        }
                        if (match(settings, "\"" key "\"[ \t\r\n]*:[ \t\r\n]*[{]")) {
                            start=RSTART+RLENGTH-1
                            depth=0
                            obj=""
                            for (i=start; i<=length(settings); i++) {
                                c=substr(settings,i,1)
                                obj=obj c
                                if (c=="{") depth++
                                else if (c=="}") { depth--; if (depth==0) break }
                            }
                            if (match(obj, /"invoke_separator"[ \t\r\n]*:[ \t\r\n]*"[-.]"/)) {
                                tok=substr(obj,RSTART,RLENGTH); s=substr(tok,length(tok)-1,1)
                                if (s=="." || s=="-") sep=s
                            }
                        }
                    }
                    print sep
                }
            ' "$integration_json" 2>/dev/null)
            case "$awk_separator" in
                "."|"-") separator="$awk_separator" ;;
            esac
        fi
    fi

    _SPECIFY_INVOKE_SEPARATOR_CACHE_REPO_ROOT="$repo_root"
    _SPECIFY_INVOKE_SEPARATOR_CACHE_VALUE="$separator"
    printf '%s\n' "$separator"
}

format_speckit_command() {
    local command_name="$1"
    local repo_root="${2:-$(get_repo_root)}"
    local separator
    if [[ "${_SPECIFY_INVOKE_SEPARATOR_CACHE_REPO_ROOT:-}" == "$repo_root" && -n "${_SPECIFY_INVOKE_SEPARATOR_CACHE_VALUE:-}" ]]; then
        separator="$_SPECIFY_INVOKE_SEPARATOR_CACHE_VALUE"
    else
        separator=$(get_invoke_separator "$repo_root")
        _SPECIFY_INVOKE_SEPARATOR_CACHE_REPO_ROOT="$repo_root"
        _SPECIFY_INVOKE_SEPARATOR_CACHE_VALUE="$separator"
    fi

    command_name="${command_name#/}"
    command_name="${command_name#speckit.}"
    command_name="${command_name#speckit-}"
    command_name="${command_name//./$separator}"

    printf '/speckit%s%s\n' "$separator" "$command_name"
}

# Escape a string for safe embedding in a JSON value (fallback when jq is unavailable).
# Handles backslash, double-quote, and JSON-required control character escapes (RFC 8259).
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\b'/\\b}"
    s="${s//$'\f'/\\f}"
    # Escape any remaining U+0001-U+001F control characters as \uXXXX.
    # (U+0000/NUL cannot appear in bash strings and is excluded.)
    # LC_ALL=C ensures ${#s} counts bytes and ${s:$i:1} yields single bytes,
    # so multi-byte UTF-8 sequences (first byte >= 0xC0) pass through intact.
    local LC_ALL=C
    local i char code
    for (( i=0; i<${#s}; i++ )); do
        char="${s:$i:1}"
        printf -v code '%d' "'$char" 2>/dev/null || code=256
        if (( code >= 1 && code <= 31 )); then
            printf '\\u%04x' "$code"
        else
            printf '%s' "$char"
        fi
    done
}

check_file() { [[ -f "$1" ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  ✓ $2" || echo "  ✗ $2"; }

_python3_command() {
    if command -v python3 >/dev/null 2>&1 &&
        python3 -c 'import sys; raise SystemExit(sys.version_info.major != 3)' >/dev/null 2>&1; then
        printf '%s\n' "python3"
    elif command -v python >/dev/null 2>&1 &&
        python -c 'import sys; raise SystemExit(sys.version_info.major != 3)' >/dev/null 2>&1; then
        printf '%s\n' "python"
    elif command -v py >/dev/null 2>&1 &&
        py -3 -c 'import sys' >/dev/null 2>&1; then
        printf '%s\n' "py -3"
    else
        return 1
    fi
}

_sorted_extension_ids() {
    local ext_dir="$1"
    local python_spec
    if python_spec=$(_python3_command); then
        local -a python_cmd
        read -r -a python_cmd <<< "$python_spec"
        local py_stderr sorted_ids
        py_stderr=$(mktemp)
        if sorted_ids=$(SPECKIT_EXTENSIONS="$ext_dir" "${python_cmd[@]}" -c "
import json, os, re, sys
from pathlib import Path

root = Path(os.environ['SPECKIT_EXTENSIONS'])
registered = {}
registry = root / '.registry'
if os.path.lexists(registry):
    if not registry.is_file():
        print('registry_invalid: not a regular file', file=sys.stderr)
        sys.exit(1)
    try:
        data = json.loads(registry.read_text(encoding='utf-8'))
    except Exception as exc:
        print('registry_invalid: ' + str(exc), file=sys.stderr)
        sys.exit(1)
    if not isinstance(data, dict):
        print('registry_invalid: root must be a mapping', file=sys.stderr)
        sys.exit(1)
    raw_extensions = data.get('extensions', {})
    if not isinstance(raw_extensions, dict):
        print('registry_invalid: extensions must be a mapping', file=sys.stderr)
        sys.exit(1)
    registered = raw_extensions

def priority(value):
    if isinstance(value, bool):
        return 10
    try:
        parsed = int(value)
        return parsed if parsed >= 1 else 10
    except (TypeError, ValueError, OverflowError):
        return 10

ranked = []
for ext_id, meta in registered.items():
    if isinstance(ext_id, str) and re.fullmatch(r'[a-z0-9-]+', ext_id) and isinstance(meta, dict) and bool(meta.get('enabled', True)):
        ranked.append((priority(meta.get('priority')), ext_id))
for path in root.iterdir():
    if path.is_dir() and re.fullmatch(r'[a-z0-9-]+', path.name) and path.name not in registered:
        ranked.append((10, path.name))
for _, ext_id in sorted(ranked):
    print(ext_id)
" 2>"$py_stderr"); then
            rm -f "$py_stderr"
            printf '%s\n' "$sorted_ids"
            return 0
        else
            echo "Error: invalid extension registry $ext_dir/.registry" >&2
            rm -f "$py_stderr"
            return 1
        fi
    fi

    if [ -e "$ext_dir/.registry" ] || [ -L "$ext_dir/.registry" ]; then
        if [ ! -f "$ext_dir/.registry" ] || [ ! -r "$ext_dir/.registry" ]; then
            echo "Error: invalid extension registry $ext_dir/.registry" >&2
            return 1
        fi
        echo "Error: Python 3 is required to honor the extension registry" >&2
        return 2
    fi

    local ext extension_id
    for ext in "$ext_dir"/*/; do
        [ -d "$ext" ] || continue
        extension_id=$(basename "$ext")
        case "$extension_id" in *[!a-z0-9-]*) continue ;; esac
        printf '%s\n' "$extension_id"
    done
}

# Resolve a template name to a file path using the priority stack:
#   1. .specify/templates/overrides/
#   2. .specify/presets/<preset-id>/templates/ (sorted by priority from .registry)
#   3. .specify/extensions/<ext-id>/templates/
#   4. .specify/templates/ (core)
resolve_template() {
    local template_name="$1"
    local repo_root="$2"
    local base="$repo_root/.specify/templates"

    case "$template_name" in ""|*[!a-z0-9-]*) return 1 ;; esac

    # Priority 1: Project overrides
    local override="$base/overrides/${template_name}.md"
    [ -f "$override" ] && echo "$override" && return 0

    # Priority 2: Installed presets (sorted by priority from .registry)
    local presets_dir="$repo_root/.specify/presets"
    if [ -d "$presets_dir" ]; then
        local registry_file="$presets_dir/.registry"
        local python_spec=""
        local -a python_cmd=()
        if python_spec=$(_python3_command); then
            read -r -a python_cmd <<< "$python_spec"
        fi
        if [ -f "$registry_file" ] && [ "${#python_cmd[@]}" -gt 0 ]; then
            # Read preset IDs sorted by priority (lower number = higher precedence).
            # The python3 call is wrapped in an if-condition so that set -e does not
            # abort the function when python3 exits non-zero (e.g. invalid JSON).
            local sorted_presets=""
            if sorted_presets=$(SPECKIT_REGISTRY="$registry_file" "${python_cmd[@]}" -c "
import json, re, sys, os
try:
    with open(os.environ['SPECKIT_REGISTRY'], encoding='utf-8') as f:
        data = json.load(f)
    presets = data.get('presets', {})
    def priority(meta):
        if not isinstance(meta, dict) or isinstance(meta.get('priority'), bool):
            return 10
        try:
            value = int(meta.get('priority', 10))
            return value if value >= 1 else 10
        except (TypeError, ValueError, OverflowError):
            return 10
    for pid, meta in sorted(presets.items(), key=lambda x: (priority(x[1]), x[0])):
        if isinstance(meta, dict) and bool(meta.get('enabled', True)) and re.fullmatch(r'[a-z0-9-]+', pid):
            print(pid)
except Exception:
    sys.exit(1)
" 2>/dev/null); then
                if [ -n "$sorted_presets" ]; then
                    # python3 succeeded and returned preset IDs — search in priority order
                    while IFS= read -r preset_id; do
                        local candidate="$presets_dir/$preset_id/templates/${template_name}.md"
                        [ -f "$candidate" ] && echo "$candidate" && return 0
                        candidate="$presets_dir/$preset_id/${template_name}.md"
                        [ -f "$candidate" ] && echo "$candidate" && return 0
                    done <<< "$sorted_presets"
                fi
                # python3 succeeded but registry has no presets — nothing to search
            else
                # python3 failed (missing, or registry parse error) — fall back to unordered directory scan
                for preset in "$presets_dir"/*/; do
                    [ -d "$preset" ] || continue
                    local candidate="$preset/templates/${template_name}.md"
                    [ -f "$candidate" ] && echo "$candidate" && return 0
                    candidate="$preset/${template_name}.md"
                    [ -f "$candidate" ] && echo "$candidate" && return 0
                done
            fi
        else
            # Fallback: alphabetical directory order (no python3 available)
            for preset in "$presets_dir"/*/; do
                [ -d "$preset" ] || continue
                local candidate="$preset/templates/${template_name}.md"
                [ -f "$candidate" ] && echo "$candidate" && return 0
                candidate="$preset/${template_name}.md"
                [ -f "$candidate" ] && echo "$candidate" && return 0
            done
        fi
    fi

    # Priority 3: Extension-provided templates
    local ext_dir="$repo_root/.specify/extensions"
    if [ -d "$ext_dir" ]; then
        local sorted_extensions=""
        if ! sorted_extensions=$(_sorted_extension_ids "$ext_dir"); then
            return 2
        fi
        while IFS= read -r extension_id; do
            [ -n "$extension_id" ] || continue
            local ext="$ext_dir/$extension_id"
            local candidate="$ext/templates/${template_name}.md"
            [ -f "$candidate" ] || candidate="$ext/${template_name}.md"
            [ -f "$candidate" ] && echo "$candidate" && return 0
        done <<< "$sorted_extensions"
    fi

    # Priority 4: Core templates
    local core="$base/${template_name}.md"
    [ -f "$core" ] && echo "$core" && return 0

    # Template not found in any location.
    # Return 1 so callers can distinguish "not found" from "found".
    # Callers running under set -e should use: TEMPLATE=$(resolve_template ...) || true
    return 1
}

# Resolve a template name to composed content using composition strategies.
# Reads strategy metadata from preset manifests and composes content
# from multiple layers using prepend, append, or wrap strategies.
#
# Usage: CONTENT=$(resolve_template_content "template-name" "$REPO_ROOT")
# Returns composed content string on stdout; exit code 1 if not found.
resolve_template_content() {
    local template_name="$1"
    local repo_root="$2"
    local base="$repo_root/.specify/templates"

    case "$template_name" in ""|*[!a-z0-9-]*) return 1 ;; esac

    # Collect all layers (highest priority first)
    local -a layer_paths=()
    local -a layer_strategies=()

    # Priority 1: Project overrides (always "replace")
    local override="$base/overrides/${template_name}.md"
    if [ -f "$override" ]; then
        if ! cat "$override"; then
            echo "Error: failed to read template layer $override" >&2
            return 2
        fi
        return 0
    fi

    local effective_base_found=false

    # Priority 2: Installed presets (sorted by priority from .registry)
    local presets_dir="$repo_root/.specify/presets"
    if [ -d "$presets_dir" ]; then
        local registry_file="$presets_dir/.registry"
        local sorted_presets=""
        local registry_parsed=false
        local python_spec=""
        local -a python_cmd=()
        if python_spec=$(_python3_command); then
            read -r -a python_cmd <<< "$python_spec"
        fi
        if [ -f "$registry_file" ] && [ "${#python_cmd[@]}" -gt 0 ]; then
            if sorted_presets=$(SPECKIT_REGISTRY="$registry_file" "${python_cmd[@]}" -c "
import json, re, sys, os
try:
    with open(os.environ['SPECKIT_REGISTRY'], encoding='utf-8') as f:
        data = json.load(f)
    presets = data.get('presets', {})
    def priority(meta):
        if not isinstance(meta, dict) or isinstance(meta.get('priority'), bool):
            return 10
        try:
            value = int(meta.get('priority', 10))
            return value if value >= 1 else 10
        except (TypeError, ValueError, OverflowError):
            return 10
    for pid, meta in sorted(presets.items(), key=lambda x: (priority(x[1]), x[0])):
        if isinstance(meta, dict) and bool(meta.get('enabled', True)) and re.fullmatch(r'[a-z0-9-]+', pid):
            print(pid)
except Exception:
    sys.exit(1)
" 2>/dev/null); then
                registry_parsed=true
            fi
        fi
        if [ "$registry_parsed" = false ]; then
            for preset in "$presets_dir"/*/; do
                [ -d "$preset" ] || continue
                local fallback_id
                fallback_id=$(basename "$preset")
                case "$fallback_id" in *[!a-z0-9-]*) continue ;; esac
                sorted_presets+="${sorted_presets:+$'\n'}$fallback_id"
            done
        fi

        if [ -n "$sorted_presets" ]; then
            while IFS= read -r preset_id; do
                local strategy="replace"
                local manifest_file=""
                local manifest="$presets_dir/$preset_id/preset.yml"
                local manifest_declared=false
                if [ -f "$manifest" ]; then
                    if [ "${#python_cmd[@]}" -eq 0 ]; then
                        echo "Error: Python 3 and PyYAML are required to resolve preset template composition" >&2
                        return 2
                    fi
                    local result
                    local py_stderr
                    local parse_status
                    py_stderr=$(mktemp)
                    if result=$(SPECKIT_MANIFEST="$manifest" SPECKIT_TMPL="$template_name" "${python_cmd[@]}" -c "
import sys, os
try:
    import yaml
except ImportError:
    print('yaml_missing', file=sys.stderr)
    sys.exit(2)
try:
    with open(os.environ['SPECKIT_MANIFEST'], encoding='utf-8') as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise ValueError('manifest root must be a mapping')
    if 'provides' not in data:
        raise ValueError('manifest missing provides section')
    provides = data['provides']
    if not isinstance(provides, dict):
        raise ValueError('manifest provides must be a mapping')
    if 'templates' not in provides:
        raise ValueError('manifest provides missing templates')
    templates = provides['templates']
    if not isinstance(templates, list):
        raise ValueError('manifest templates must be a list')
    if not templates:
        raise ValueError('manifest must provide at least one template')
    valid_types = ('template', 'command', 'script')
    valid_strategies = ('replace', 'prepend', 'append', 'wrap')
    for t in templates:
        if not isinstance(t, dict):
            raise ValueError('manifest template entries must be mappings')
        if 'type' not in t or 'name' not in t or 'file' not in t:
            raise ValueError('manifest template entry missing type, name, or file')
        for field in ('type', 'name', 'file'):
            if not isinstance(t[field], str):
                raise ValueError('manifest template ' + field + ' must be a string')
        if t['type'] not in valid_types:
            raise ValueError('invalid manifest template type')
        strategy = t.get('strategy', 'replace')
        if not isinstance(strategy, str):
            raise ValueError('manifest template strategy must be a string')
        strategy = strategy.lower()
        if strategy not in valid_strategies:
            raise ValueError('invalid manifest template strategy')
        if t['type'] == 'script' and strategy not in ('replace', 'wrap'):
            raise ValueError('invalid manifest script strategy')
    for t in templates:
        if t.get('name') == os.environ['SPECKIT_TMPL'] and t.get('type', 'template') == 'template':
            file_value = t.get('file', '')
            strategy = t.get('strategy', 'replace')
            print('found\t' + strategy + '\t' + file_value)
            sys.exit(0)
    print('absent\treplace\t')
except Exception as exc:
    print(f'manifest_invalid: {exc}', file=sys.stderr)
    sys.exit(3)
" 2>"$py_stderr"); then
                        parse_status=0
                    else
                        parse_status=$?
                    fi
                    if [ "$parse_status" -ne 0 ]; then
                        if [ "$parse_status" -eq 2 ]; then
                            echo "Error: PyYAML is required to resolve preset template composition" >&2
                        else
                            echo "Error: invalid preset manifest $manifest" >&2
                        fi
                        rm -f "$py_stderr"
                        return 2
                    fi
                    if [ -n "$result" ]; then
                        local declaration
                        IFS=$'\t' read -r declaration strategy manifest_file <<< "$result"
                        [ "$declaration" = "found" ] && manifest_declared=true
                        strategy=$(printf '%s' "$strategy" | tr '[:upper:]' '[:lower:]')
                    fi
                    rm -f "$py_stderr"
                fi

                local candidate=""
                if [ -n "$manifest_file" ]; then
                    case "$manifest_file" in
                        /*|*../*|../*) manifest_file="" ;;
                    esac
                fi
                if [ -n "$manifest_file" ]; then
                    local mf="$presets_dir/$preset_id/$manifest_file"
                    [ -f "$mf" ] && candidate="$mf"
                fi
                if [ -z "$candidate" ] && [ "$manifest_declared" = false ]; then
                    local cf="$presets_dir/$preset_id/templates/${template_name}.md"
                    [ -f "$cf" ] && candidate="$cf"
                    if [ -z "$candidate" ]; then
                        cf="$presets_dir/$preset_id/${template_name}.md"
                        [ -f "$cf" ] && candidate="$cf"
                    fi
                fi
                if [ -n "$candidate" ]; then
                    layer_paths+=("$candidate")
                    layer_strategies+=("$strategy")
                    if [ "$strategy" = "replace" ]; then
                        effective_base_found=true
                        break
                    fi
                fi
            done <<< "$sorted_presets"
        fi
    fi

    # Priority 3: Extension-provided templates (always "replace")
    local ext_dir="$repo_root/.specify/extensions"
    if [ "$effective_base_found" = false ] && [ -d "$ext_dir" ]; then
        local sorted_extensions=""
        if ! sorted_extensions=$(_sorted_extension_ids "$ext_dir"); then
            return 2
        fi
        while IFS= read -r extension_id; do
            [ -n "$extension_id" ] || continue
            local ext="$ext_dir/$extension_id"
            local candidate="$ext/templates/${template_name}.md"
            [ -f "$candidate" ] || candidate="$ext/${template_name}.md"
            if [ -f "$candidate" ]; then
                layer_paths+=("$candidate")
                layer_strategies+=("replace")
                effective_base_found=true
                break
            fi
        done <<< "$sorted_extensions"
    fi

    # Priority 4: Core templates (always "replace")
    local core="$base/${template_name}.md"
    if [ "$effective_base_found" = false ] && [ -f "$core" ]; then
        layer_paths+=("$core")
        layer_strategies+=("replace")
    fi

    local count=${#layer_paths[@]}
    [ "$count" -eq 0 ] && return 1

    # Check if any layer uses a non-replace strategy
    local has_composition=false
    for s in "${layer_strategies[@]}"; do
        [ "$s" != "replace" ] && has_composition=true && break
    done

    # If the top (highest-priority) layer is replace, it wins entirely —
    # lower layers are irrelevant regardless of their strategies.
    if [ "${layer_strategies[0]}" = "replace" ]; then
        if ! cat "${layer_paths[0]}"; then
            echo "Error: failed to read template layer ${layer_paths[0]}" >&2
            return 2
        fi
        return 0
    fi

    if [ "$has_composition" = false ]; then
        if ! cat "${layer_paths[0]}"; then
            echo "Error: failed to read template layer ${layer_paths[0]}" >&2
            return 2
        fi
        return 0
    fi

    # Find the effective base: scan from highest priority (index 0) downward
    # to find the nearest replace layer. Only compose layers above that base.
    local base_idx=-1
    local i
    for (( i=0; i<count; i++ )); do
        if [ "${layer_strategies[$i]}" = "replace" ]; then
            base_idx=$i
            break
        fi
    done

    if [ $base_idx -lt 0 ]; then
        echo "Error: template '$template_name' has composing layers but no replace base" >&2
        return 2
    fi

    # Read the base content; compose layers above the base (higher priority)
    local content
    if ! content=$(cat "${layer_paths[$base_idx]}"; status=$?; printf x; exit "$status"); then
        echo "Error: failed to read template layer ${layer_paths[$base_idx]}" >&2
        return 2
    fi
    content="${content%x}"

    for (( i=base_idx-1; i>=0; i-- )); do
        local path="${layer_paths[$i]}"
        local strat="${layer_strategies[$i]}"
        local layer_content
        # Preserve trailing newlines
        if ! layer_content=$(cat "$path"; status=$?; printf x; exit "$status"); then
            echo "Error: failed to read template layer $path" >&2
            return 2
        fi
        layer_content="${layer_content%x}"

        case "$strat" in
            replace) content="$layer_content" ;;
            prepend)
                content=$(printf '%s\n\n%s' "$layer_content" "$content"; printf x)
                content="${content%x}"
                ;;
            append)
                content=$(printf '%s\n\n%s' "$content" "$layer_content"; printf x)
                content="${content%x}"
                ;;
            wrap)
                case "$layer_content" in
                    *'{CORE_TEMPLATE}'*) ;;
                    *) echo "Error: wrap strategy missing {CORE_TEMPLATE} placeholder" >&2; return 2 ;;
                esac
                # Consume the wrapper left to right instead of rewriting it in
                # place. Rewriting re-scanned the string just modified, so base
                # content holding a literal {CORE_TEMPLATE} reintroduced the
                # token every pass and the loop never terminated. Advancing over
                # ``rest`` bounds the work by the tokens in the original wrapper
                # and leaves inserted content untouched, matching the single-pass
                # semantics of .Replace()/.replace() in the PowerShell and Python
                # ports.
                local wrapped="" rest="$layer_content"
                while [[ "$rest" == *'{CORE_TEMPLATE}'* ]]; do
                    wrapped="${wrapped}${rest%%\{CORE_TEMPLATE\}*}${content}"
                    rest="${rest#*\{CORE_TEMPLATE\}}"
                done
                content="${wrapped}${rest}"
                ;;
            *) echo "Error: unknown strategy '$strat'" >&2; return 2 ;;
        esac
    done

    printf '%s' "$content"
    return 0
}
''';

/// Byte-identical embed of `.specify/scripts/bash/setup-plan.sh`
const String kSpeckitSetupPlanSh = r'''#!/usr/bin/env bash

set -e

# Parse command line arguments
JSON_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--json]"
            echo "  --json    Output results in JSON format"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$arg'" >&2
            exit 1
            ;;
    esac
done

# Get script directory and load common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get all paths and variables from common functions
_paths_output=$(get_feature_paths) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
eval "$_paths_output"
unset _paths_output

# Ensure the feature directory exists
mkdir -p "$FEATURE_DIR"

# Copy plan template if plan doesn't already exist
if [[ -f "$IMPL_PLAN" ]]; then
    if $JSON_MODE; then
        echo "Plan already exists at $IMPL_PLAN, skipping template copy" >&2
    else
        echo "Plan already exists at $IMPL_PLAN, skipping template copy"
    fi
else
    if resolve_template_content "plan-template" "$REPO_ROOT" > "$IMPL_PLAN"; then
        if $JSON_MODE; then
            echo "Copied plan template to $IMPL_PLAN" >&2
        else
            echo "Copied plan template to $IMPL_PLAN"
        fi
    else
        resolve_status=$?
        rm -f "$IMPL_PLAN"
        if [ "$resolve_status" -ne 1 ]; then
            exit "$resolve_status"
        fi
        if $JSON_MODE; then
            echo "Warning: Plan template not found" >&2
        else
            echo "Warning: Plan template not found"
        fi
        touch "$IMPL_PLAN"
    fi
fi

# Output results
if $JSON_MODE; then
    if has_jq; then
        jq -cn \
            --arg feature_spec "$FEATURE_SPEC" \
            --arg impl_plan "$IMPL_PLAN" \
            --arg feature_dir "$FEATURE_DIR" \
            --arg branch "$CURRENT_BRANCH" \
            '{FEATURE_SPEC:$feature_spec,IMPL_PLAN:$impl_plan,FEATURE_DIR:$feature_dir,BRANCH:$branch}'
    else
        printf '{"FEATURE_SPEC":"%s","IMPL_PLAN":"%s","FEATURE_DIR":"%s","BRANCH":"%s"}\n' \
            "$(json_escape "$FEATURE_SPEC")" "$(json_escape "$IMPL_PLAN")" "$(json_escape "$FEATURE_DIR")" "$(json_escape "$CURRENT_BRANCH")"
    fi
else
    echo "FEATURE_SPEC: $FEATURE_SPEC"
    echo "IMPL_PLAN: $IMPL_PLAN"
    echo "FEATURE_DIR: $FEATURE_DIR"
    echo "BRANCH: $CURRENT_BRANCH"
fi
''';

/// Byte-identical embed of `.specify/scripts/bash/check-prerequisites.sh`
const String kSpeckitCheckPrerequisitesSh = r'''#!/usr/bin/env bash

# Consolidated prerequisite checking script
#
# This script provides unified prerequisite checking for Spec-Driven Development workflow.
# It replaces the functionality previously spread across multiple scripts.
#
# Usage: ./check-prerequisites.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output in JSON format
#   --require-spec      Require spec.md to exist (for analysis phase)
#   --require-tasks     Require tasks.md to exist (for implementation phase)
#   --include-tasks     Include tasks.md in AVAILABLE_DOCS list
#   --paths-only        Only output path variables (no validation)
#   --template NAME     Include composed template content in JSON output
#   --help, -h          Show help message
#
# OUTPUTS:
#   JSON mode: {"FEATURE_DIR":"...", "AVAILABLE_DOCS":["..."]}
#   Text mode: FEATURE_DIR:... \n AVAILABLE_DOCS: \n ✓/✗ file.md
#   Paths only: REPO_ROOT: ... \n BRANCH: ... \n FEATURE_DIR: ... etc.

set -e

# Parse command line arguments
JSON_MODE=false
REQUIRE_SPEC=false
REQUIRE_TASKS=false
INCLUDE_TASKS=false
PATHS_ONLY=false
TEMPLATE_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            ;;
        --require-spec)
            REQUIRE_SPEC=true
            ;;
        --require-tasks)
            REQUIRE_TASKS=true
            ;;
        --include-tasks)
            INCLUDE_TASKS=true
            ;;
        --paths-only)
            PATHS_ONLY=true
            ;;
        --template)
            shift
            if [[ $# -eq 0 ]]; then
                echo "ERROR: --template requires a template name" >&2
                exit 1
            fi
            TEMPLATE_NAME="$1"
            ;;
        --help|-h)
            cat << 'EOF'
Usage: check-prerequisites.sh [OPTIONS]

Consolidated prerequisite checking for Spec-Driven Development workflow.

OPTIONS:
  --json              Output in JSON format
  --require-spec      Require spec.md to exist (for analysis phase)
  --require-tasks     Require tasks.md to exist (for implementation phase)
  --include-tasks     Include tasks.md in AVAILABLE_DOCS list
  --paths-only        Only output path variables (no prerequisite validation)
  --template NAME     Include composed template content in JSON output
  --help, -h          Show this help message

EXAMPLES:
  # Check task prerequisites (plan.md required)
  ./check-prerequisites.sh --json

  # Check implementation prerequisites (plan.md + tasks.md required)
  ./check-prerequisites.sh --json --require-tasks --include-tasks

  # Get feature paths only (no validation)
  ./check-prerequisites.sh --paths-only

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$1'. Use --help for usage information." >&2
            exit 1
            ;;
    esac
    shift
done

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get feature paths.
# In --paths-only mode this is pure resolution, so pass --no-persist to opt out
# of the feature.json write side effect (issue #3025).
if $PATHS_ONLY; then
    _paths_output=$(get_feature_paths --no-persist) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
else
    _paths_output=$(get_feature_paths) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
fi
eval "$_paths_output"
unset _paths_output

# If paths-only mode, output paths and exit (no validation)
if $PATHS_ONLY; then
    if $JSON_MODE; then
        # Minimal JSON paths payload (no validation performed)
        if has_jq; then
            jq -cn \
                --arg repo_root "$REPO_ROOT" \
                --arg branch "$CURRENT_BRANCH" \
                --arg feature_dir "$FEATURE_DIR" \
                --arg feature_spec "$FEATURE_SPEC" \
                --arg impl_plan "$IMPL_PLAN" \
                --arg tasks "$TASKS" \
                '{REPO_ROOT:$repo_root,BRANCH:$branch,FEATURE_DIR:$feature_dir,FEATURE_SPEC:$feature_spec,IMPL_PLAN:$impl_plan,TASKS:$tasks}'
        else
            printf '{"REPO_ROOT":"%s","BRANCH":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s"}\n' \
                "$(json_escape "$REPO_ROOT")" "$(json_escape "$CURRENT_BRANCH")" "$(json_escape "$FEATURE_DIR")" "$(json_escape "$FEATURE_SPEC")" "$(json_escape "$IMPL_PLAN")" "$(json_escape "$TASKS")"
        fi
    else
        echo "REPO_ROOT: $REPO_ROOT"
        echo "BRANCH: $CURRENT_BRANCH"
        echo "FEATURE_DIR: $FEATURE_DIR"
        echo "FEATURE_SPEC: $FEATURE_SPEC"
        echo "IMPL_PLAN: $IMPL_PLAN"
        echo "TASKS: $TASKS"
    fi
    exit 0
fi

# Validate required directories and files
if [[ ! -d "$FEATURE_DIR" ]]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    echo "Run /speckit-specify first to create the feature structure." >&2
    exit 1
fi

if [[ ! -f "$IMPL_PLAN" ]]; then
    echo "ERROR: plan.md not found in $FEATURE_DIR" >&2
    echo "Run /speckit-plan first to create the implementation plan." >&2
    exit 1
fi

# Check for spec.md if required
if $REQUIRE_SPEC && [[ ! -f "$FEATURE_SPEC" ]]; then
    echo "ERROR: spec.md not found in $FEATURE_DIR" >&2
    echo "Run /speckit-specify first to create the feature specification." >&2
    exit 1
fi

# Check for tasks.md if required
if $REQUIRE_TASKS && [[ ! -f "$TASKS" ]]; then
    echo "ERROR: tasks.md not found in $FEATURE_DIR" >&2
    echo "Run /speckit-tasks first to create the task list." >&2
    exit 1
fi

# Build list of available documents
docs=()

# Always check these optional docs
[[ -f "$RESEARCH" ]] && docs+=("research.md")
[[ -f "$DATA_MODEL" ]] && docs+=("data-model.md")

# Check contracts directory (only if it exists and has files)
if [[ -d "$CONTRACTS_DIR" ]] && [[ -n "$(ls -A "$CONTRACTS_DIR" 2>/dev/null)" ]]; then
    docs+=("contracts/")
fi

[[ -f "$QUICKSTART" ]] && docs+=("quickstart.md")

# Include tasks.md if requested and it exists
if $INCLUDE_TASKS && [[ -f "$TASKS" ]]; then
    docs+=("tasks.md")
fi

TEMPLATE_CONTENT=""
if [[ -n "$TEMPLATE_NAME" ]]; then
    if TEMPLATE_CONTENT=$(resolve_template_content "$TEMPLATE_NAME" "$REPO_ROOT"; status=$?; printf x; exit "$status"); then
        TEMPLATE_CONTENT="${TEMPLATE_CONTENT%x}"
    else
        echo "ERROR: Could not resolve required $TEMPLATE_NAME from the template override stack for $REPO_ROOT" >&2
        exit 1
    fi
fi

# Output results
if $JSON_MODE; then
    # Build JSON array of documents
    if has_jq; then
        if [[ ${#docs[@]} -eq 0 ]]; then
            json_docs="[]"
        else
            json_docs=$(printf '%s\n' "${docs[@]}" | jq -R . | jq -s .)
        fi
        if [[ -n "$TEMPLATE_NAME" ]]; then
            jq -cn \
                --arg feature_dir "$FEATURE_DIR" \
                --argjson docs "$json_docs" \
                --arg template_content "$TEMPLATE_CONTENT" \
                '{FEATURE_DIR:$feature_dir,AVAILABLE_DOCS:$docs,TEMPLATE_CONTENT:$template_content}'
        else
            jq -cn \
                --arg feature_dir "$FEATURE_DIR" \
                --argjson docs "$json_docs" \
                '{FEATURE_DIR:$feature_dir,AVAILABLE_DOCS:$docs}'
        fi
    else
        if [[ ${#docs[@]} -eq 0 ]]; then
            json_docs="[]"
        else
            json_docs=$(for d in "${docs[@]}"; do printf '"%s",' "$(json_escape "$d")"; done)
            json_docs="[${json_docs%,}]"
        fi
        if [[ -n "$TEMPLATE_NAME" ]]; then
            printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s,"TEMPLATE_CONTENT":"%s"}\n' \
                "$(json_escape "$FEATURE_DIR")" "$json_docs" "$(json_escape "$TEMPLATE_CONTENT")"
        else
            printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s}\n' "$(json_escape "$FEATURE_DIR")" "$json_docs"
        fi
    fi
else
    # Text output
    echo "FEATURE_DIR:$FEATURE_DIR"
    echo "AVAILABLE_DOCS:"

    # Show status of each potential document
    check_file "$RESEARCH" "research.md"
    check_file "$DATA_MODEL" "data-model.md"
    check_dir "$CONTRACTS_DIR" "contracts/"
    check_file "$QUICKSTART" "quickstart.md"

    if $INCLUDE_TASKS; then
        check_file "$TASKS" "tasks.md"
    fi
fi
''';

/// Byte-identical embed of `.specify/scripts/bash/setup-tasks.sh`
const String kSpeckitSetupTasksSh = r'''#!/usr/bin/env bash

set -e

# Parse command line arguments
JSON_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [--json]"
            echo "  --json    Output results in JSON format"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *) echo "ERROR: Unknown option '$arg'" >&2; exit 1 ;;
    esac
done

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get feature paths
_paths_output=$(get_feature_paths) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
eval "$_paths_output"
unset _paths_output

# Validate required files
if [[ ! -f "$IMPL_PLAN" ]]; then
    echo "ERROR: plan.md not found in $FEATURE_DIR" >&2
    echo "Run /speckit-plan first to create the implementation plan." >&2
    exit 1
fi

if [[ ! -f "$FEATURE_SPEC" ]]; then
    echo "ERROR: spec.md not found in $FEATURE_DIR" >&2
    echo "Run /speckit-specify first to create the feature structure." >&2
    exit 1
fi

# Build available docs list
docs=()
[[ -f "$RESEARCH" ]] && docs+=("research.md")
[[ -f "$DATA_MODEL" ]] && docs+=("data-model.md")
if [[ -d "$CONTRACTS_DIR" ]] && [[ -n "$(ls -A "$CONTRACTS_DIR" 2>/dev/null)" ]]; then
    docs+=("contracts/")
fi
[[ -f "$QUICKSTART" ]] && docs+=("quickstart.md")

# Resolve tasks template through override stack
TASKS_TEMPLATE=$(resolve_template "tasks-template" "$REPO_ROOT") || true
if TASKS_TEMPLATE_CONTENT=$(resolve_template_content "tasks-template" "$REPO_ROOT"; status=$?; printf x; exit "$status"); then
    TASKS_TEMPLATE_CONTENT="${TASKS_TEMPLATE_CONTENT%x}"
else
    echo "ERROR: Could not resolve required tasks-template from the template override stack for $REPO_ROOT" >&2
    echo "Template 'tasks-template' was not found in any supported location (overrides, presets, extensions, or shared core). Add an override at .specify/templates/overrides/tasks-template.md, or run 'specify init' / reinstall shared infra to restore the core .specify/templates/tasks-template.md template." >&2
    exit 1
fi

# Output results
if $JSON_MODE; then
    if has_jq; then
        if [[ ${#docs[@]} -eq 0 ]]; then
            json_docs="[]"
        else
            json_docs=$(printf '%s\n' "${docs[@]}" | jq -R . | jq -s .)
        fi
        jq -cn \
            --arg feature_dir "$FEATURE_DIR" \
            --argjson docs "$json_docs" \
            --arg tasks_template "${TASKS_TEMPLATE:-}" \
            --arg tasks_template_content "$TASKS_TEMPLATE_CONTENT" \
            '{FEATURE_DIR:$feature_dir,AVAILABLE_DOCS:$docs,TASKS_TEMPLATE:$tasks_template,TASKS_TEMPLATE_CONTENT:$tasks_template_content}'
    else
        if [[ ${#docs[@]} -eq 0 ]]; then
            json_docs="[]"
        else
            json_docs=$(for d in "${docs[@]}"; do printf '"%s",' "$(json_escape "$d")"; done)
            json_docs="[${json_docs%,}]"
        fi
        printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s,"TASKS_TEMPLATE":"%s","TASKS_TEMPLATE_CONTENT":"%s"}\n' \
            "$(json_escape "$FEATURE_DIR")" "$json_docs" "$(json_escape "${TASKS_TEMPLATE:-}")" "$(json_escape "$TASKS_TEMPLATE_CONTENT")"
    fi
else
    echo "FEATURE_DIR: $FEATURE_DIR"
    echo "TASKS_TEMPLATE: ${TASKS_TEMPLATE:-not found}"
    echo "AVAILABLE_DOCS:"
    check_file "$RESEARCH" "research.md"
    check_file "$DATA_MODEL" "data-model.md"
    check_dir "$CONTRACTS_DIR" "contracts/"
    check_file "$QUICKSTART" "quickstart.md"
fi
''';
// END EMBEDDED SCRIPTS
