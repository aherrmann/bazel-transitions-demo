#!/usr/bin/env bash
set -euo pipefail
set -x

ACTUAL="$($1 2>&1)"
EXPECTED="Using enterprise edition
Data file: ENTERPRISE"

if [[ $ACTUAL != $EXPECTED ]]; then
  echo "Mismatched output:" >&2
  echo "Expected:" >&2
  echo "$EXPECTED" >&2
  echo "Actual:" >&2
  echo "$ACTUAL" >&2
  exit 1
fi
