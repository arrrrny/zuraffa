#!/usr/bin/env bash
# run_chunk_batch.sh — run a slice of the repo's chunked fast suite with the
# EXACT semantics of tools/run_tests_chunked.sh (dart test <dir>
# --exclude-tags flutter, stdin closed), bounded kernel-cache hygiene:
# kernel caches are cleared BETWEEN calls of the batch runner, not between
# individual chunks, to bound disk while keeping compile cost sane on a
# cloud agent whose background processes get reaped (so the real script
# cannot run to completion in one shot).
#
# Usage: run_chunk_batch.sh <start> <count>   (1-based, inclusive slice of
# /tmp/chunks_list.txt)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

START="$1"
COUNT="$2"
OUT="/tmp/chunk_results"
mkdir -p "$OUT"

total=$(wc -l < /tmp/chunks_list.txt)
end=$(( START + COUNT - 1 ))
[ "$end" -gt "$total" ] && end="$total"

i=0
while IFS= read -r d; do
  i=$(( i + 1 ))
  [ "$i" -lt "$START" ] && continue
  [ "$i" -gt "$end" ] && break
  safe=$(echo "$d" | tr '/' '_')
  res="$OUT/${safe}.txt"
  echo "=== [$i/$total] chunk: $d ==="
  if out="$(dart test "$d" --exclude-tags flutter < /dev/null 2>&1)"; then
    printf '%s\n' "$out" > "$res"
    echo "PASS: $d — $(printf '%s\n' "$out" | tail -1)"
  elif printf '%s\n' "$out" | grep -q "No tests ran"; then
    printf '%s\n' "$out" > "$res"
    echo "SKIP: no fast-tier tests in $d"
  else
    printf '%s\n' "$out" > "$res"
    echo "FAIL: $d — $(printf '%s\n' "$out" | tail -1)"
  fi
done < /tmp/chunks_list.txt

# Disk hygiene: clear the kernel caches the batch accumulated.
rm -rf .dart_tool/test/incremental_kernel.* 2>/dev/null || true
if [ -n "${TMPDIR:-}" ]; then rm -rf "$TMPDIR"/dart_test.kernel.* 2>/dev/null || true; fi
rm -rf /tmp/dart_test.kernel.* 2>/dev/null || true
echo "batch done: chunks $START-$end"
