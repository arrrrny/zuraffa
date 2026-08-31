#!/usr/bin/env bash
#
# md-doctor engine
# -----------------
# Deterministic, dependency-light engine backing the `speckit.md-doctor.*`
# commands. It owns the parts an LLM should not: discovering .md files, pulling
# git creation/modification metadata, collecting ground truth (git HEAD + the
# commits since the last run, .memsearch daily records, and TDD verification
# verdicts), computing the week-over-week delta, emitting run manifests as JSON,
# and mechanically applying the safe suggestions.
#
# The agent (the command markdown) owns the judgment: extracting the claims a
# .md makes, fact-checking them against the ground truth, scoring truthfulness,
# and writing the per-file facts back into state. This script only hands it the
# raw material and, later, applies what the agent decided.
#
# Subcommands:
#   init     write config (if missing), snapshot ground truth, seed empty state
#   scan     enumerate .md files + metadata + ground truth -> manifest JSON
#   drift    git/.memsearch/tdd delta since last run -> delta JSON
#   report   aggregate state/facts.json into a health summary (JSON or text)
#   apply    mechanically apply suggestions (create stubs, stamp footers;
#            delete only with --delete)
#
# Dependencies: git, jq. (No yq/PyYAML — config is read by a tiny awk loader.)

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths & constants
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STATE_DIR="${MDD_STATE_DIR:-.specify/md-doctor}"
STATE_SUB="$STATE_DIR/state"
REPORTS_DIR="$STATE_DIR/reports"
CONFIG_PATH="${MDD_CONFIG:-.specify/extensions/md-doctor/md-doctor-config.yml}"
TEMPLATE_CONFIG="$EXT_ROOT/config-template.yml"

LAST_RUN="$STATE_SUB/last-run.json"
GROUND_TRUTHS="$STATE_SUB/ground-truths.json"
FACTS="$STATE_SUB/facts.json"

# Defaults (overridden by config where present)
DEF_SCAN_PATHS="."
DEF_EXCLUDE_GLOBS=".git/** .specify/md-doctor/** node_modules/** .venv/** vendor/**"
DEF_TDD_INTEGRATION="true"
DEF_MIN_SCORE="60"

SCAN_PATHS="$DEF_SCAN_PATHS"
EXCLUDE_GLOBS="$DEF_EXCLUDE_GLOBS"
TDD_INTEGRATION="$DEF_TDD_INTEGRATION"
MIN_SCORE="$DEF_MIN_SCORE"

# ---------------------------------------------------------------------------
# CLI parsing (subcommand + shared flags)
# ---------------------------------------------------------------------------
SUBCMD=""
ARG_PATH=""
ARG_JSON="false"
ARG_MIN_SCORE=""
ARG_RUN=""
ARG_ACTION=""
ARG_DELETE="false"
ARG_ALL="false"

while [ $# -gt 0 ]; do
  case "$1" in
    init|scan|drift|report|apply) SUBCMD="$1" ;;
    --path) ARG_PATH="${2:-}"; shift ;;
    --config) CONFIG_PATH="${2:-}"; shift ;;
    --state-dir) STATE_DIR="${2:-}"; shift ;;
    --json) ARG_JSON="true" ;;
    --min-score) ARG_MIN_SCORE="${2:-}"; shift ;;
    --run) ARG_RUN="${2:-}"; shift ;;
    --action) ARG_ACTION="${2:-}"; shift ;;
    --delete) ARG_DELETE="true" ;;
    --all) ARG_ALL="true" ;;
    -h|--help) sed -n '2,55p' "$0"; exit 0 ;;
    *) echo "md-doctor: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift || true
done

[ -z "$SUBCMD" ] && { echo "md-doctor: no subcommand (init|scan|drift|report|apply)" >&2; exit 2; }
[ -n "$ARG_MIN_SCORE" ] && MIN_SCORE="$ARG_MIN_SCORE"
[ -n "$ARG_JSON" ] && true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
require_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "md-doctor: 'git' not found" >&2; exit 1
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "md-doctor: not inside a git work tree" >&2; exit 1
  fi
}

require_jq() {
  command -v jq >/dev/null 2>&1 || { echo "md-doctor: 'jq' not found" >&2; exit 1; }
}

now_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
now_epoch() { date +%s; }

# ISO-8601 timestamp -> epoch seconds (portable-ish)
iso_to_epoch() {
  local iso="$1"
  # strip trailing Z, normalize to space
  iso="${iso%.Z}"; iso="${iso/Z/ }"
  date -j -f "%Y-%m-%d %H:%M:%S" "${iso%%.*}" +%s 2>/dev/null \
    || date -d "${iso%%.*}" +%s 2>/dev/null || echo 0
}

# mtime epoch of a file, portable
mtime_epoch() {
  local f="$1"
  if stat -f %m "$f" 2>/dev/null; then return; fi
  stat -c %Y "$f" 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# Config loading (minimal YAML reader via awk, mirrors gh-triage.sh)
# ---------------------------------------------------------------------------
resolve_config_path() {
  [ -f "$CONFIG_PATH" ] && { echo "$CONFIG_PATH"; return; }
  [ -f "$TEMPLATE_CONFIG" ] && { echo "$TEMPLATE_CONFIG"; return; }   # dev fallback
  echo ""
}

load_config() {
  local cfg_path
  cfg_path="$(resolve_config_path)"
  [ -z "$cfg_path" ] && return 0
  local parsed
  parsed="$(awk '
    {
      line=$0; sub(/\r$/,"",line); sub(/^ */,"",line)
      sub(/[ \t]#.*$/,"",line)
      if (line=="") next
      if (substr(line,1,1)=="#") next
      if (substr(line,1,2)=="- ") {
        val=substr(line,3)
        if (substr(val,1,1)=="\"" && substr(val,length(val),1)=="\"") val=substr(val,2,length(val)-2)
        if (cont=="scan_paths") SP=SP " " val
        else if (cont=="exclude_globs") EG=EG " " val
        next
      }
      c=index(line,":")
      if (c>0) {
        key=substr(line,1,c-1); val=substr(line,c+1)
        sub(/^[ \t]+/,"",val); sub(/[ \t]+$/,"",val)
        if (val ~ /^""$/) val=""
        else if (substr(val,1,1)=="\"" && substr(val,length(val),1)=="\"") val=substr(val,2,length(val)-2)
        gsub(/[^a-zA-Z0-9_]/,"_",key)
        if (val=="") { cont=key; next }
        cont=""
        print "CFG_" key "=\"" val "\""
        next
      }
    }
    END {
      # Names must match the lowercase YAML keys read by load_config below,
      # same convention as the scalar path ("CFG_" key).
      if (SP!="") print "CFG_scan_paths=\"" substr(SP,2) "\""
      if (EG!="") print "CFG_exclude_globs=\"" substr(EG,2) "\""
    }
  ' "$cfg_path")"
  [ -n "$parsed" ] && eval "$parsed"
  [ -n "${CFG_scan_paths:-}" ] && SCAN_PATHS="$CFG_scan_paths"
  [ -n "${CFG_exclude_globs:-}" ] && EXCLUDE_GLOBS="$CFG_exclude_globs"
  [ -n "${CFG_tdd_integration:-}" ] && TDD_INTEGRATION="$CFG_tdd_integration"
  [ -n "${CFG_min_score:-}" ] && MIN_SCORE="$CFG_min_score"
}

ensure_state_dirs() {
  mkdir -p "$STATE_SUB" "$REPORTS_DIR"
}

# ---------------------------------------------------------------------------
# .md discovery
# ---------------------------------------------------------------------------
# Emit newline-separated .md paths, tracked + untracked-but-not-ignored,
# filtered by scan_paths and exclude_globs.
enumerate_markdown() {
  local p globs tmp tracked untracked
  globs="$EXCLUDE_GLOBS"
  # tracked
  for p in $SCAN_PATHS; do
    git ls-files --deduplicate -- "$p" 2>/dev/null | grep -E '\.md$' || true
  done
  # untracked, not ignored (agents write docs that may never be committed)
  for p in $SCAN_PATHS; do
    git ls-files --others --exclude-standard -- "$p" 2>/dev/null | grep -E '\.md$' || true
  done | sort -u
}

# 1 if path matches any exclude glob (path-aware: ** crosses dirs, * stays in one)
is_excluded() {
  local f="$1" g re
  for g in $EXCLUDE_GLOBS; do
    re="$(printf '%s' "$g" \
      | sed -e 's/\./\\./g' -e 's/\*\*/.*/g' -e 's#\*#[^/]*#g' \
            -e 's#^#^#' -e 's#$#(/|$)#')"
    if printf '%s' "$f" | grep -Eq "$re"; then return 0; fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Git metadata for one file
# ---------------------------------------------------------------------------
file_created_iso() {
  local f="$1" out
  out="$(git log --diff-filter=A --follow --format=%aI -- "$f" 2>/dev/null | tail -1)"
  [ -n "$out" ] && { echo "$out"; return; }
  echo ""
}
file_modified_iso() {
  local f="$1" out
  out="$(git log -1 --format=%aI -- "$f" 2>/dev/null)"
  [ -n "$out" ] && { echo "$out"; return; }
  # untracked: fall back to mtime
  local e; e="$(mtime_epoch "$f")"
  [ "$e" -gt 0 ] 2>/dev/null && date -r "$e" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo ""
}
file_hash() { git hash-object "$f" 2>/dev/null || echo ""; }

# ---------------------------------------------------------------------------
# Ground truth collection
# ---------------------------------------------------------------------------
collect_head() {
  git rev-parse HEAD 2>/dev/null || echo "unknown"
}

# TDD verdicts: read each specs/*/tdd/verification.md and guess the verdict.
collect_tdd_verdicts() {
  [ "$TDD_INTEGRATION" = "true" ] || { echo "[]"; return; }
  local items="" first=1 v feat verdict_line verdict obj
  for v in specs/*/tdd/verification.md; do
    [ -f "$v" ] || continue
    feat="${v#specs/}"; feat="${feat%%/tdd/verification.md}"
    verdict_line="$(grep -iE 'verdict|status|pass|fail' "$v" 2>/dev/null | head -3 | tr '\n' ' ')"
    if grep -qiE '\b(fail|failing|red|not.?pass)\b' <<<"$verdict_line"; then verdict="fail"
    elif grep -qiE '\b(pass|passed|green|ok)\b' <<<"$verdict_line"; then verdict="pass"
    else verdict="unknown"; fi
    obj="$(jq -nc --arg f "$feat" --arg vr "$verdict" --arg s "$v" '{feature:$f,verdict:$vr,source:$s}')"
    [ "$first" -eq 1 ] && first=0 && items="$obj" || items="$items,$obj"
  done
  echo "[$items]"
}

# TDD verified behaviors: list specs/*/tdd/test-list.md existence as a fact-set.
collect_tdd_features() {
  [ "$TDD_INTEGRATION" = "true" ] || { echo "[]"; return; }
  local items="" first=1 d feat
  for d in specs/*/tdd; do
    [ -d "$d" ] || continue
    feat="${d#specs/}"; feat="${feat%%/tdd}"
    [ "$first" -eq 1 ] && first=0 && items="\"$feat\"" || items="$items,\"$feat\""
  done
  echo "[$items]"
}

# .memsearch daily records newer than a cutoff ISO timestamp.
collect_memsearch() {
  local cutoff_iso="${1:-}" cutoff_e=0 f d iso obj
  [ -n "$cutoff_iso" ] && cutoff_e="$(iso_to_epoch "$cutoff_iso")"
  local items="" first=1
  for f in .memsearch/memory/*.md; do
    [ -f "$f" ] || continue
    d="$(basename "$f" .md)"   # YYYY-MM-DD
    iso="${d}T23:59:59Z"
    if [ "$cutoff_e" -gt 0 ] 2>/dev/null; then
      [ "$(iso_to_epoch "$iso")" -le "$cutoff_e" ] && continue
    fi
    obj="$(jq -nc --arg dt "$d" --arg p "$f" '{date:$dt,path:$p}')"
    [ "$first" -eq 1 ] && first=0 && items="$obj" || items="$items,$obj"
  done
  echo "[$items]"
}

collect_ground_truths() {
  local head tdd_v tdd_f mem
  head="$(collect_head)"
  tdd_v="$(collect_tdd_verdicts)"
  tdd_f="$(collect_tdd_features)"
  mem="$(collect_memsearch)"
  jq -n \
    --arg ts "$(now_ts)" --arg head "$head" \
    --argjson tdd "$TDD_INTEGRATION" \
    --argjson verdicts "$tdd_v" --argjson features "$tdd_f" --argjson ms "$mem" \
    '{collected_at:$ts, head:$head, tdd_integration:$tdd, tdd_verdicts:$verdicts, tdd_features:$features, memsearch_files:$ms}' \
    > "$GROUND_TRUTHS"
}

# ---------------------------------------------------------------------------
# Subcommand: init
# ---------------------------------------------------------------------------
cmd_init() {
  require_git
  load_config
  ensure_state_dirs
  # Write config from template if it is missing at the resolved path and a
  # template exists. (Install normally copies it; this is a dev/bootstrap aid.)
  if [ ! -f "$CONFIG_PATH" ] && [ -f "$TEMPLATE_CONFIG" ]; then
    mkdir -p "$(dirname "$CONFIG_PATH")"
    cp "$TEMPLATE_CONFIG" "$CONFIG_PATH"
    echo "md-doctor: wrote config -> $CONFIG_PATH"
  fi
  collect_ground_truths
  # Seed empty facts + last-run baseline.
  if [ ! -f "$FACTS" ]; then
    echo '{"files":[]}' > "$FACTS"
  fi
  local head rid
  head="$(collect_head)"
  rid="init-$(now_ts)"
  jq -n --arg rid "$rid" --arg ts "$(now_ts)" --arg head "$head" \
    '{run_id:$rid, type:"init", timestamp:$ts, head:$head, files_scanned:0, summary:{avg_truthfulness:null,truthful:0,stale:0,false:0,obsolete:0}, actions_taken:[]}' \
    > "$LAST_RUN"
  echo "md-doctor: initialized. state at $STATE_DIR (head=$head)"
  echo "md-doctor: ground truths -> $GROUND_TRUTHS"
}

# ---------------------------------------------------------------------------
# Subcommand: scan  (emits a manifest the agent fact-checks)
# ---------------------------------------------------------------------------
cmd_scan() {
  require_git
  load_config
  ensure_state_dirs
  collect_ground_truths
  local scope="${ARG_PATH:-$SCAN_PATHS}"
  local f created modified hash e m
  local objs="" first=1
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ -n "$ARG_PATH" ]; then
      case "$f" in "$ARG_PATH"*) ;; *) continue ;; esac
    fi
    is_excluded "$f" && continue
    [ -f "$f" ] || continue
    created="$(file_created_iso "$f")"
    modified="$(file_modified_iso "$f")"
    hash="$(file_hash "$f")"
    obj="$(jq -nc --arg p "$f" --arg c "$created" --arg m "$modified" --arg h "$hash" '{path:$p,created:$c,modified:$m,hash:$h}')"
    [ "$first" -eq 1 ] && first=0 && objs="$obj" || objs="$objs,$obj"
  done < <(enumerate_markdown)
  # Manifest = files + ground truth, so the agent has everything in one read.
  local gt; gt="$(cat "$GROUND_TRUTHS")"
  local manifest
  manifest="$(jq -n --arg ts "$(now_ts)" --argjson gt "$gt" --argjson files "[$objs]" \
    '{generated_at:$ts, ground_truths:$gt, files:$files}')"
  if [ "$ARG_JSON" = "true" ]; then
    printf '%s' "$manifest"
  else
    printf '%s' "$manifest"
  fi
}

# ---------------------------------------------------------------------------
# Subcommand: drift  (delta since last run)
# ---------------------------------------------------------------------------
cmd_drift() {
  require_git
  load_config
  [ -f "$LAST_RUN" ] || { echo "md-doctor: no last run. Run 'md-doctor init' or 'scan' first." >&2; exit 1; }
  local prev_head prev_ts
  prev_head="$(jq -r '.head // "unknown"' "$LAST_RUN" 2>/dev/null)"
  prev_ts="$(jq -r '.timestamp // ""' "$LAST_RUN" 2>/dev/null)"
  # Commits since the previous run's HEAD (what was implemented since).
  local commits="[]"
  if [ "$prev_head" != "unknown" ] && git cat-file -e "$prev_head" 2>/dev/null; then
    commits="$(git log --format='%H'$'\t''%aI'$'\t''%s' "$prev_head..HEAD" 2>/dev/null \
      | jq -R -s 'split("\n") | map(select(length>0)) | map(split("\t") | {sha: .[0], date: .[1], subject: .[2]})' 2>/dev/null)"
    [ -z "$commits" ] && commits="[]"
  fi
  # Files changed since previous run.
  local changed="[]"
  if [ "$prev_head" != "unknown" ] && git cat-file -e "$prev_head" 2>/dev/null; then
    changed="$(git diff --name-only "$prev_head..HEAD" 2>/dev/null | grep -E '\.md$' \
      | jq -R -s 'split("\n") | map(select(length>0))' 2>/dev/null || true)"
    [ -z "$changed" ] && changed="[]"
  fi
  local mem; mem="$(collect_memsearch "$prev_ts")"
  local head; head="$(collect_head)"
  local delta
  delta="$(jq -n --arg ts "$(now_ts)" --arg ph "$prev_head" --arg pts "$prev_ts" --arg ch "$head" \
    --argjson commits "$commits" --argjson changed "$changed" --argjson ms "$mem" \
    '{generated_at:$ts, prev_run:{head:$ph, timestamp:$pts}, current_head:$ch, commits_since:$commits, md_changed_since:$changed, memsearch_files_since:$ms}')"
  if [ "$ARG_JSON" = "true" ]; then
    printf '%s' "$delta"
  else
    printf '%s' "$delta"
  fi
}

# ---------------------------------------------------------------------------
# Subcommand: report  (aggregate state)
# ---------------------------------------------------------------------------
cmd_report() {
  require_jq
  [ -f "$FACTS" ] || { echo "md-doctor: no facts yet. Run 'scan' first." >&2; exit 1; }
  local target="$FACTS"
  if [ -n "$ARG_RUN" ]; then
    local r="$REPORTS_DIR/$ARG_RUN.md"
    [ -f "$r" ] || { echo "md-doctor: no report for run $ARG_RUN" >&2; exit 1; }
  fi
  # Summarize from facts.json
  local summary
  summary="$(jq -r '
    .files as $f
    | ($f | length) as $n
    | ($f | map(.truthfulness // 0) | (if length>0 then add/length else 0 end)) as $avg
    | ($f | map(select(.verdict=="truthful")) | length) as $t
    | ($f | map(select(.verdict=="stale")) | length) as $s
    | ($f | map(select(.verdict=="false")) | length) as $fa
    | ($f | map(select(.verdict=="obsolete")) | length) as $o
    | ($f | map(select(.action=="delete")) | length) as $del
    | ($f | map(select(.action=="update")) | length) as $upd
    | ($f | map(select(.action=="create")) | length) as $cre
    | {scanned:$n, avg_truthfulness:($avg|round), truthful:$t, stale:$s, false:$fa, obsolete:$o, to_delete:$del, to_update:$upd, to_create:$cre}
  ' "$FACTS")"
  if [ "$ARG_JSON" = "true" ]; then
    printf '%s' "$summary"
  else
    echo "md-doctor health summary"
    echo "  files scanned : $(echo "$summary" | jq -r .scanned)"
    echo "  avg truthful. : $(echo "$summary" | jq -r .avg_truthfulness)/100"
    echo "  truthful      : $(echo "$summary" | jq -r .truthful)"
    echo "  stale         : $(echo "$summary" | jq -r .stale)"
    echo "  false         : $(echo "$summary" | jq -r .false)"
    echo "  obsolete      : $(echo "$summary" | jq -r .obsolete)"
    echo "  suggestions   : update=$(echo "$summary" | jq -r .to_update) delete=$(echo "$summary" | jq -r .to_delete) create=$(echo "$summary" | jq -r .to_create)"
  fi
}

# ---------------------------------------------------------------------------
# Subcommand: apply  (mechanical, safe by default)
# ---------------------------------------------------------------------------
cmd_apply() {
  require_jq
  [ -f "$FACTS" ] || { echo "md-doctor: no facts to apply. Run 'scan' first." >&2; exit 1; }
  local stamped=0 created=0 deleted=0
  local do_create=false do_stamp=false do_delete=false
  case "${ARG_ACTION:-}" in
    create) do_create=true ;;
    stamp)  do_stamp=true ;;
    delete) : ;;                                   # plan-only unless --delete
    "")     do_create=true; do_stamp=true ;;       # safe default: create + stamp
  esac
  [ "$ARG_ALL" = "true" ] && { do_create=true; do_stamp=true; do_delete=true; }
  [ "$ARG_DELETE" = "true" ] && do_delete=true
  local ts; ts="$(now_ts)"
  # create: stub missing docs (safe)
  if [ "$do_create" = "true" ]; then
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      local p; p="$(echo "$entry" | jq -r '.proposed_path // empty')"
      [ -z "$p" ] && continue
      [ -f "$p" ] && continue
      mkdir -p "$(dirname "$p")"
      cat > "$p" <<EOF
# $(basename "$p" .md)

> Stub created by md-doctor on $ts. Fill in or delete.
EOF
      created=$((created+1))
      echo "  + created stub: $p"
    done < <(jq -c '.files[]? | select(.action=="create")' "$FACTS" 2>/dev/null)
  fi
  # stamp: footer on keep/update files (safe, non-destructive)
  if [ "$do_stamp" = "true" ]; then
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      local p sc
      p="$(echo "$entry" | jq -r '.path // empty')"
      sc="$(echo "$entry" | jq -r '.truthfulness // "?"')"
      [ -z "$p" ] || [ ! -f "$p" ] && continue
      grep -q "md-doctor on ${ts:0:10}" "$p" 2>/dev/null && continue
      printf '\n---\n\n> Verified by md-doctor on %s — truthfulness %s/100.\n' "$ts" "$sc" >> "$p"
      stamped=$((stamped+1))
      echo "  ~ stamped: $p"
    done < <(jq -c '.files[]? | select(.action=="keep" or .action=="update")' "$FACTS" 2>/dev/null)
  fi
  # delete: only when explicitly requested (destructive)
  if [ "$do_delete" = "true" ]; then
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      local p; p="$(echo "$entry" | jq -r '.path // empty')"
      [ -z "$p" ] || [ ! -f "$p" ] && continue
      rm -f "$p"
      deleted=$((deleted+1))
      echo "  - deleted: $p"
    done < <(jq -c '.files[]? | select(.action=="delete")' "$FACTS" 2>/dev/null)
  elif [ "$ARG_ACTION" = "delete" ] && [ "$ARG_DELETE" != "true" ]; then
    echo "md-doctor: delete requires --delete (destructive). Showing plan only:"
    jq -r '.files[]? | select(.action=="delete") | "  would delete: " + .path' "$FACTS" 2>/dev/null
  fi
  echo "md-doctor apply: created=$created stamped=$stamped deleted=$deleted"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "$SUBCMD" in
  init)  cmd_init ;;
  scan)  cmd_scan ;;
  drift) cmd_drift ;;
  report) cmd_report ;;
  apply) cmd_apply ;;
  *) echo "md-doctor: unknown subcommand $SUBCMD" >&2; exit 2 ;;
esac
