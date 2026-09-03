#!/usr/bin/env bash
# run_chunks_range.sh — run a slice of the chunked fast suite (see
# tools/run_tests_chunked.sh). Usage:
#   tools/run_chunks_range.sh <start_line> <end_line>   # 1-based chunk list
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

START="${1:-1}"
END="${2:-999999}"

# Emit the same chunk list the main script uses.
chunks() {
  DRY_RUN=1 tools/run_tests_chunked.sh 2>/dev/null | grep -v '^Chunks' | grep -v '^$'
}

total_failed=0
i=0
while IFS= read -r chunk; do
  i=$((i + 1))
  if [ "$i" -lt "$START" ]; then continue; fi
  if [ "$i" -gt "$END" ]; then break; fi
  echo "=== chunk: $chunk ==="
  dart test "$chunk" --exclude-tags flutter < /dev/null > "/tmp/chunk_out.log" 2>&1
  status=$?
  if [ $status -eq 79 ]; then
    # Exit 79 = "no tests ran" (all tagged slow/flutter): the main
    # script's SKIP case, not a failure.
    echo "SKIP: no fast-tier tests in $chunk"
  elif [ $status -ne 0 ]; then
    total_failed=$((total_failed + 1))
    echo "FAILED ($status): $chunk"
    tail -25 /tmp/chunk_out.log
  else
    grep -E "All tests passed|No tests ran|Some tests failed" /tmp/chunk_out.log | tail -1
  fi
  # Bound disk: clear kernel caches like the main script.
  rm -rf .dart_tool/test/incremental_kernel.* 2>/dev/null || true
  rm -rf "${TMPDIR:-/tmp}"/dart_test.kernel.* 2>/dev/null || true
  rm -rf /tmp/dart_test.kernel.* 2>/dev/null || true
done < <(chunks)

echo "=== RANGE DONE (chunks $START-$END): failed_chunks=$total_failed ==="
exit $total_failed
