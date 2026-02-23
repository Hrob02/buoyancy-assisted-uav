# build.ps1 — Build the ROS 2 workspace on Windows (WSL or native ROS).
# NOTE: ROS 2 on Windows requires WSL2 or a native ROS 2 Windows installation.

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$WsDir      = Split-Path -Parent $ScriptDir

Write-Host "[build.ps1] Building ROS 2 workspace at: $WsDir"
Write-Host "[build.ps1] If using WSL2, run ros_ws/scripts/build.sh inside WSL instead."

Push-Location $WsDir
try {
    colcon build --symlink-install
} finally {
    Pop-Location
}
