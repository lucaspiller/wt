#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
failed=0

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    echo ""
    echo "--- $(basename "$test_file") ---"
    if ! bash "$test_file"; then
        failed=1
    fi
done

echo ""
if [ "$failed" -eq 1 ]; then
    echo "SOME TESTS FAILED"
    exit 1
else
    echo "ALL TESTS PASSED"
fi
