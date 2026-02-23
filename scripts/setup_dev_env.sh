#!/usr/bin/env bash
# setup_dev_env.sh — Create a Python virtual environment and install dev dependencies.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv"

echo "[setup_dev_env] Repository root: $REPO_ROOT"

if [ ! -d "$VENV_DIR" ]; then
    echo "[setup_dev_env] Creating virtual environment at .venv ..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

echo "[setup_dev_env] Upgrading pip ..."
pip install --upgrade pip

echo "[setup_dev_env] Installing dev dependencies ..."
pip install ruff black isort pytest pre-commit

echo ""
echo "[setup_dev_env] Done. Activate the environment with:"
echo "  source .venv/bin/activate"
