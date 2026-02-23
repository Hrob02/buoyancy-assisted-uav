# setup_dev_env.ps1 — Create a Python virtual environment on Windows.

$RepoRoot = Split-Path -Parent $PSScriptRoot
$VenvDir  = Join-Path $RepoRoot ".venv"

Write-Host "[setup_dev_env] Repository root: $RepoRoot"

if (-not (Test-Path $VenvDir)) {
    Write-Host "[setup_dev_env] Creating virtual environment at .venv ..."
    python -m venv $VenvDir
}

& "$VenvDir\Scripts\Activate.ps1"

Write-Host "[setup_dev_env] Upgrading pip ..."
pip install --upgrade pip

Write-Host "[setup_dev_env] Installing dev dependencies ..."
pip install ruff black isort pytest pre-commit

Write-Host ""
Write-Host "[setup_dev_env] Done. Activate with:"
Write-Host "  .venv\Scripts\Activate.ps1"
