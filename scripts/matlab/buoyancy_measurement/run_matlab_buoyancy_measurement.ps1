# run_matlab_buoyancy_measurement.ps1 - Launch MATLAB buoyancy measurement analysis on Windows.

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

Write-Host "[run_matlab_buoyancy_measurement] Using MATLAB executable: $matlabExe"

Push-Location $RepoRoot
try {
    $logDir = Join-Path $RepoRoot "matlab\results\buoyancy_measurement"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    $logPath = Join-Path $logDir "matlab_buoyancy_launch.log"

    Write-Host "[run_matlab_buoyancy_measurement] Launching MATLAB buoyancy measurement analysis..."
    & $matlabExe -wait -nosplash -softwareopengl -logfile $logPath -r "try, cd('matlab/scripts/buoyancy_measurement'); run_buoyancy_measurement_analysis; catch ME, disp(getReport(ME)); exit(1); end; exit(0);"
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "MATLAB exited with code $exitCode."
    }
    Write-Host "[run_matlab_buoyancy_measurement] MATLAB command completed successfully."
    Write-Host "[run_matlab_buoyancy_measurement] MATLAB log: $logPath"
}
finally {
    Pop-Location
}
