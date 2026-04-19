#!/bin/bash
# Update expected files from py2v output.
#
# Modes:
#   default           Regenerate fixtures from transpiler output (semantic update)
#   --format-only     Reformat existing fixtures only (no transpilation)
#
# Targeting:
#   --case <name>     Limit update/formatting to a single test case

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PY2V="$PROJECT_DIR/py2v"
CASES_DIR="$SCRIPT_DIR/cases"
EXPECTED_DIR="$SCRIPT_DIR/expected"

format_only=false
case_name=""

usage() {
    cat <<'EOF'
Usage: sh tests/update_expected.sh [--format-only] [--case <name>]

Options:
  --format-only   Only run v fmt on expected fixtures; do not regenerate output.
  --case <name>   Limit to a single case/fixture name (without extension).
  -h, --help      Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --format-only)
            format_only=true
            shift
            ;;
        --case)
            if [ "$#" -lt 2 ]; then
                echo "Error: --case requires a value"
                usage
                exit 1
            fi
            case_name="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option '$1'"
            usage
            exit 1
            ;;
    esac
done

if [ "$format_only" = false ]; then
    # Build py2v if needed
    if [ ! -f "$PY2V" ]; then
        echo "Building py2v..."
        cd "$PROJECT_DIR"
        v . -o py2v
    fi
fi

echo "Updating expected files..."
echo ""

count=0

if [ -n "$case_name" ]; then
    case_files=("$CASES_DIR/${case_name}.py")
else
    case_files=("$CASES_DIR"/*.py)
fi

for case_file in "${case_files[@]}"; do
    if [ ! -f "$case_file" ]; then
        continue
    fi
    test_name=$(basename "$case_file" .py)
    expected_file="$EXPECTED_DIR/${test_name}.v"

    if [ "$format_only" = true ]; then
        if [ -f "$expected_file" ]; then
            v fmt -w "$expected_file" >/dev/null 2>&1 || true
            echo "Formatted: $test_name"
            ((count++)) || true
        else
            echo "Skipped: $test_name (missing expected fixture)"
        fi
        continue
    fi

    # Semantic update: regenerate from py2v output
    if output=$("$PY2V" "$case_file" 2>&1); then
        echo "$output" > "$expected_file"
        echo "Updated: $test_name"
        ((count++)) || true
    else
        echo "Skipped: $test_name (transpilation error)"
    fi
done

echo ""
if [ "$format_only" = true ]; then
    echo "Formatted $count expected files"
else
    echo "Updated $count expected files"
fi
