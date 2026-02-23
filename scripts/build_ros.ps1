# build_ros.ps1 — Build the ROS 2 workspace (Windows / WSL2).
# NOTE: ROS 2 Humble is primarily supported on Ubuntu 22.04.
#       On Windows, use WSL2 and run scripts/build_ros.sh inside WSL.

$RepoRoot = Split-Path -Parent $PSScriptRoot
$WsDir    = Join-Path $RepoRoot "ros_ws"

Write-Host "[build_ros] This script is a placeholder for Windows."
Write-Host "[build_ros] Please use WSL2 and run: bash scripts/build_ros.sh"
Write-Host "[build_ros] Or build manually inside WSL:"
Write-Host "  cd $WsDir && colcon build --symlink-install"
