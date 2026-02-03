#!/bin/bash
# Update expected files from py2v output

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PY2V="$PROJECT_DIR/py2v"
CASES_DIR="$SCRIPT_DIR/cases"
EXPECTED_DIR="$SCRIPT_DIR/expected"

# Build py2v if needed
if [ ! -f "$PY2V" ]; then
    echo "Building py2v..."
    cd "$PROJECT_DIR"
    v . -o py2v
fi

echo "Updating expected files..."
echo ""

count=0
for case_file in "$CASES_DIR"/*.py; do
    test_name=$(basename "$case_file" .py)
    expected_file="$EXPECTED_DIR/${test_name}.v"

    # Run py2v
    if output=$("$PY2V" "$case_file" 2>&1); then
        echo "$output" > "$expected_file"
        echo "Updated: $test_name"
        ((count++))
    else
        echo "Skipped: $test_name (transpilation error)"
    fi
done

echo ""
echo "Updated $count expected files"
