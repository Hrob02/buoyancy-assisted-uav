# run_matlab_duty_cycle.ps1 - Launch MATLAB duty-cycle analysis on Windows.

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path

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
            ForEach-Object { Join-Path $_.FullName "bin\matlab.exe" } |
            Where-Object { Test-Path $_ }
    )

    if (-not $candidates) {
        throw "matlab.exe not found under Program Files\MATLAB. Install MATLAB or add it to PATH."
    }

    $matlabExe = $candidates[0]
}

Write-Host "[run_matlab_duty_cycle] Using MATLAB executable: $matlabExe"

Push-Location $RepoRoot
try {
    Write-Host "[run_matlab_duty_cycle] Launching MATLAB duty-cycle analysis..."
    & $matlabExe -nosplash -r "try, cd('matlab/scripts/duty_cycle'); run_duty_cycle_analysis; catch ME, disp(getReport(ME)); end"
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "MATLAB exited with code $exitCode."
    }
    Write-Host "[run_matlab_duty_cycle] MATLAB command completed successfully."
}
finally {
    Pop-Location
}
