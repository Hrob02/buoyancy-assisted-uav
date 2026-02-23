#!/usr/bin/env bash
# lint.sh — Run ruff, black (check), and isort (check) over Python sources.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PYTHON_DIRS=(
    "$REPO_ROOT/ros_ws/src"
    "$REPO_ROOT/ui"
)

echo "[lint] Running ruff ..."
ruff check "${PYTHON_DIRS[@]}"

echo "[lint] Running black (check) ..."
black --check "${PYTHON_DIRS[@]}"

echo "[lint] Running isort (check) ..."
isort --check-only "${PYTHON_DIRS[@]}"

echo "[lint] All checks passed."
