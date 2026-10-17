#!/bin/bash

# Rebuild and reinstall ZFA MCP server
# Compiles executables to ~/.local/bin/
# Never touches ~/.pub-cache/ — native binaries there crash pub.

set -e

INSTALL_DIR="${ZURAFFA_BIN:-$HOME/.local/bin}"

echo "🔄 Rebuilding ZFA..."

# Clear ALL build caches so the installed binary always reflects current source.
# A partial cleanup (only .dart_tool/build_cache, hooks_runner, pub/bin) left a stale
# dart build cli artifact in place, causing zfa to run pre-fix code after a source
# change — see .specify/bugs/rebuild-stale-binary.
rm -rf build .dart_tool

# Get dependencies.
# --no-example skips the nested `example/` Flutter app so `dart pub get`
# doesn't fail with "the Flutter SDK is not available" when only the Dart
# SDK is on PATH. The example app is a sibling demo, not a build dep.
# stderr is captured and only printed on failure — the previous `> /dev/null
# 2>&1` swallowed the real error and made the script silently hang.
echo "📥 Getting dependencies..."
PUB_STDERR=$(mktemp)
if ! dart pub get --no-example > /dev/null 2> "$PUB_STDERR"; then
  echo "  ❌ dart pub get failed:" >&2
  cat "$PUB_STDERR" >&2
  rm -f "$PUB_STDERR"
  exit 1
fi
rm -f "$PUB_STDERR"
echo "  ✅ Dependencies resolved"
mkdir -p "$INSTALL_DIR"

# Install a freshly-built binary atomically and prove the bytes that land are
# the bytes we built (issue #1744). `cp` writes straight into the destination,
# so a reader/executor of the old path (or an interrupted copy) can observe a
# torn file — the issue showed an installed zfa that differed from its own just
# built bundle by a ~4 KB window, then SEGV'd with SEGV_MAPERR. Stage the copy
# in a sibling temp file, verify it byte-for-byte with `cmp -s`, then rename it
# into place: a rename is atomic on one filesystem, so no reader ever sees a
# partial binary.
install_binary_atomically() {
  local src="$1"
  local name="$2"
  local dest="$INSTALL_DIR/$name"
  # Create the sibling staging file with `mktemp` (a unique, unpredictable
  # name) instead of a guessable `$dest.rebuild.$$` in an `INSTALL_DIR` that an
  # explicit `ZURAFFA_BIN` may point at a directory writable by other users.
  # `cp` follows a destination symlink, so a predictable staging path is a
  # symlink-clobber hazard. A privileged install into a less-trusted directory
  # is unsupported.
  local tmp
  tmp=$(mktemp "$dest.XXXXXX")
  cp "$src" "$tmp"
  chmod +x "$tmp" 2>/dev/null || true
  if ! cmp -s "$src" "$tmp"; then
    echo "  ❌ $name: staged copy is not byte-identical to $src" >&2
    rm -f "$tmp"
    exit 1
  fi
  mv -f "$tmp" "$dest"
  echo "  ✅ $dest"
}

# Compile zfa CLI — use dart build cli for build hooks support. stderr is
# captured and only printed on failure so the success path stays terse.
echo "🔨 Compiling zfa..."
rm -rf build/zfa_bundle
ZFA_STDERR=$(mktemp)
if ! dart build cli --target=bin/zfa.dart -o build/zfa_bundle > /dev/null 2> "$ZFA_STDERR"; then
  echo "  ❌ zfa compile failed:" >&2
  cat "$ZFA_STDERR" >&2
  rm -f "$ZFA_STDERR"
  exit 1
fi
rm -f "$ZFA_STDERR"
install_binary_atomically build/zfa_bundle/bundle/bin/zfa zfa

# Smoke-check the freshly installed CLI (issue #1744). The old script only
# *suggested* `zfa --version` at the end and printed `✅ Rebuild complete`
# regardless of whether the binary it just installed could run. A binary that
# installs but cannot execute must fail the rebuild loudly. `timeout(1)` is not
# on stock macOS, so bound the child with an `alarm` via perl (always present);
# `ZFA_SMOKE_TIMEOUT` overrides the 30s budget on a slow/loaded machine.
ZFA_SMOKE_TIMEOUT="${ZFA_SMOKE_TIMEOUT:-30}"
# A non-numeric value silently un-bounds the check: perl numifies it, so
# `ZFA_SMOKE_TIMEOUT=abc` becomes `alarm 0`, which *cancels* the timer and lets
# the child run forever — the exact 8-minute hang this check exists to catch.
case "$ZFA_SMOKE_TIMEOUT" in
  '' | *[!0-9]*)
    echo "  ❌ ZFA_SMOKE_TIMEOUT must be a whole number of seconds (got '$ZFA_SMOKE_TIMEOUT')" >&2
    exit 1
    ;;
esac
if [ "$ZFA_SMOKE_TIMEOUT" -eq 0 ]; then
  echo "  ❌ ZFA_SMOKE_TIMEOUT must be greater than 0 s (0 would disable the bound)" >&2
  exit 1
fi
echo "🔎 Verifying installed zfa (zfa --version, ${ZFA_SMOKE_TIMEOUT}s budget)..."
# `exec` returns instead of replacing the process when the target cannot be
# executed (missing +x, bad interpreter); without an explicit failure path the
# one-line perl program then exits 0 and the check passes without running zfa.
if ! perl -e 'alarm shift; exec @ARGV or die "exec failed: $!"' "$ZFA_SMOKE_TIMEOUT" "$INSTALL_DIR/zfa" --version > /dev/null 2>&1; then
  echo "  ❌ $INSTALL_DIR/zfa --version failed or did not exit within ${ZFA_SMOKE_TIMEOUT}s — installed binary is broken; rerun scripts/rebuild.sh" >&2
  exit 1
fi
echo "  ✅ zfa --version ok"

# Record the source commit this binary was built from (issue #1184). The
# installed CLI reads $INSTALL_DIR/zfa.build_commit at startup and warns —
# "⚠️ installed zfa (<commit>) is older than this checkout (<commit>) — run
# scripts/rebuild.sh" — when run inside a zuraffa worktree whose HEAD
# differs from the recorded commit. No marker (pre-#1184 install) means the
# CLI stays silent: staleness is unprovable without it.
if BUILD_COMMIT=$(git rev-parse HEAD 2>/dev/null); then
  printf '%s\n' "$BUILD_COMMIT" > "$INSTALL_DIR/zfa.build_commit"
  printf '%s\n' "$BUILD_COMMIT" > build/zfa_bundle/bundle/bin/zfa.build_commit
  echo "  ✅ recorded build commit ${BUILD_COMMIT:0:12} (zfa.build_commit)"
else
  rm -f "$INSTALL_DIR/zfa.build_commit"
  echo "  ⚠️ not a git checkout — no build commit recorded (staleness warning disabled)"
fi

# Compile zuraffa_mcp_server — same error-surfacing pattern.
echo "🔨 Compiling zuraffa_mcp_server..."
rm -rf build/mcp_server_bundle
MCP_STDERR=$(mktemp)
if ! dart build cli --target=bin/zuraffa_mcp_server.dart -o build/mcp_server_bundle > /dev/null 2> "$MCP_STDERR"; then
  echo "  ❌ mcp compile failed:" >&2
  cat "$MCP_STDERR" >&2
  rm -f "$MCP_STDERR"
  exit 1
fi
rm -f "$MCP_STDERR"
install_binary_atomically build/mcp_server_bundle/bundle/bin/zuraffa_mcp_server zuraffa_mcp_server

echo ""
echo "✅ Rebuild complete — installed to $INSTALL_DIR"
echo "   (the dev-loop cache at .dart_tool/zfa_cli_bin is separate — it will adopt this binary when fresh)"
echo ""
echo "To verify:"
echo "  zfa --version"
