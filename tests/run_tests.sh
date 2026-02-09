#!/bin/bash
# Test runner for py2v

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PY2V="$PROJECT_DIR/py2v"
CASES_DIR="$SCRIPT_DIR/cases"
EXPECTED_DIR="$SCRIPT_DIR/expected"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Build py2v if needed
if [ ! -f "$PY2V" ]; then
    echo "Building py2v..."
    cd "$PROJECT_DIR"
    v . -o py2v
fi

echo "Running tests..."
echo ""

# Find all test cases
for case_file in "$CASES_DIR"/*.py; do
    test_name=$(basename "$case_file" .py)
    expected_file="$EXPECTED_DIR/${test_name}.v"

    # Skip if no expected file
    if [ ! -f "$expected_file" ]; then
        echo -e "${YELLOW}SKIP${NC} $test_name (no expected file)"
        ((SKIPPED++)) || true
        continue
    fi

    # Run py2v
    generated=$("$PY2V" "$case_file" 2>&1) || {
        echo -e "${RED}FAIL${NC} $test_name (transpilation error)"
        ((FAILED++)) || true
        continue
    }

    # Compare output (normalize line endings for cross-platform compatibility)
    expected=$(cat "$expected_file" | tr -d '\r')
    generated=$(echo "$generated" | tr -d '\r')

    if [ "$generated" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $test_name"
        ((PASSED++)) || true
    else
        echo -e "${RED}FAIL${NC} $test_name (output mismatch)"
        ((FAILED++)) || true

        # Show diff if VERBOSE is set
        if [ -n "$VERBOSE" ]; then
            echo "--- Expected ---"
            echo "$expected" | head -20
            echo "--- Generated ---"
            echo "$generated" | head -20
            echo "----------------"
        fi
    fi
done

echo ""
echo "────────────────────────────────────────────────────────────"
echo -e "Summary: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$SKIPPED skipped${NC}"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
