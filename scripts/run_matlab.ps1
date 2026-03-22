# run_matlab.ps1 — Launch MATLAB pipeline on Windows.

$RepoRoot = Split-Path -Parent $PSScriptRoot

$matlabCmd = Get-Command matlab -ErrorAction SilentlyContinue
if ($matlabCmd) {
    $matlabExe = $matlabCmd.Path
}
else {
    $matlabRoot = Join-Path $env:ProgramFiles "MATLAB"
    if (-not (Test-Path $matlabRoot)) {
        throw "MATLAB not found. Install MATLAB or add matlab.exe to PATH."
    }

    $candidates = @(
        Get-ChildItem $matlabRoot -Directory |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName "bin\\matlab.exe" } |
            Where-Object { Test-Path $_ }
    )

    if (-not $candidates) {
        throw "matlab.exe not found under Program Files\MATLAB. Install MATLAB or add it to PATH."
    }

    $matlabExe = $candidates[0]
}

Write-Host "[run_matlab] Using MATLAB executable: $matlabExe"

Push-Location $RepoRoot
try {
    Write-Host "[run_matlab] Launching interactive MATLAB envelope trade study..."
    & $matlabExe -nosplash -r "try, cd('matlab/scripts'); envelope_trade_study; catch ME, disp(getReport(ME)); end"
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "MATLAB exited with code $exitCode."
    }
    Write-Host "[run_matlab] MATLAB command completed successfully."
}
finally {
    Pop-Location
}