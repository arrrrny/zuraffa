#!/usr/bin/env bash
# Master test runner for all 20 behaviors (A1-A10 + U1-U10)
#
# Drives both behavior harnesses and aggregates their totals, so a single run
# from this entry point is real evidence for the whole feature.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL_FOUND=0
TOTAL_PASSED=0
declare -a FAILED_HARNESSES=()

run_harness() {
    local label="$1"
    local script="$2"

    if [[ ! -f "$script" ]]; then
        echo -e "${RED}✗ $label: harness not found at $script${NC}"
        FAILED_HARNESSES+=("$label")
        return 1
    fi

    local log
    log="$(mktemp)"
    local rc=0
    bash "$script" > "$log" 2>&1 || rc=$?
    cat "$log"

    local summary passed total
    summary="$(grep -E 'Passed: [0-9]+/[0-9]+' "$log" | tail -n 1 | sed -E 's/.*Passed: ([0-9]+)\/([0-9]+).*/\1 \2/' || true)"
    rm -f "$log"

    if [[ -z "$summary" ]]; then
        echo -e "${RED}✗ $label produced no summary line${NC}"
        FAILED_HARNESSES+=("$label")
        return 1
    fi

    passed="${summary%% *}"
    total="${summary##* }"
    TOTAL_FOUND=$((TOTAL_FOUND + total))
    TOTAL_PASSED=$((TOTAL_PASSED + passed))

    if [[ $rc -ne 0 || "$passed" != "$total" ]]; then
        FAILED_HARNESSES+=("$label")
        return 1
    fi
    return 0
}

main() {
    echo "========================================"
    echo "  Spec-Kit Boundary Scripts Test Suite"
    echo "  Feature: 1444-spec-kit-boundary-scripts"
    echo "  Behaviors: A1-A10 (acceptance) + U1-U10 (unit)"
    echo "========================================"

    run_harness "Acceptance (A1-A10)" "$SCRIPT_DIR/acceptance_tests.sh" || true
    run_harness "Unit (U1-U10)" "$SCRIPT_DIR/unit_tests.sh" || true

    echo ""
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo -e "${GREEN}Passed: $TOTAL_PASSED/$TOTAL_FOUND${NC}"
    echo -e "${RED}Failed: $((TOTAL_FOUND - TOTAL_PASSED))/$TOTAL_FOUND${NC}"

    if [[ ${#FAILED_HARNESSES[@]} -gt 0 || $TOTAL_FOUND -eq 0 || $TOTAL_PASSED -ne $TOTAL_FOUND ]]; then
        echo ""
        echo "Failed harnesses: ${FAILED_HARNESSES[*]:-none}"
        exit 1
    fi

    exit 0
}

main "$@"
