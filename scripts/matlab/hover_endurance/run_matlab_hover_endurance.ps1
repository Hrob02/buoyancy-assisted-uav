# run_matlab_hover_endurance.ps1 - Launch MATLAB hover endurance analysis on Windows.

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

Write-Host "[run_matlab_hover_endurance] Using MATLAB executable: $matlabExe"

Push-Location $RepoRoot
try {
    Write-Host "[run_matlab_hover_endurance] Launching MATLAB hover endurance analysis..."
    & $matlabExe -nosplash -r "try, cd('matlab/scripts/hover_endurance'); run_hover_endurance_analysis; catch ME, disp(getReport(ME)); exit(1); end; exit(0);"
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "MATLAB exited with code $exitCode."
    }
    Write-Host "[run_matlab_hover_endurance] MATLAB command completed successfully."
}
finally {
    Pop-Location
}
