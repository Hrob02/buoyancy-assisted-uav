# run_matlab_shape_showcase.ps1 - Stitch shape rotation clips into one showcase video.

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
        throw "matlab.exe not found under Program Files\\MATLAB. Install MATLAB or add it to PATH."
    }

    $matlabExe = $candidates[0]
}

Write-Host "[run_matlab_shape_showcase] Using MATLAB executable: $matlabExe"

Push-Location $RepoRoot
try {
    Write-Host "[run_matlab_shape_showcase] Launching showcase stitch workflow..."
    & $matlabExe -batch "cd('matlab/scripts'); run_envelope_shape_showcase_video"
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "MATLAB exited with code $exitCode."
    }
    Write-Host "[run_matlab_shape_showcase] MATLAB command completed successfully."
}
finally {
    Pop-Location
}