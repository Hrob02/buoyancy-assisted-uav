#!/usr/bin/env bash
# run_sim.sh — Source the workspace and launch the UAV simulation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="$REPO_ROOT/ros_ws"
INSTALL_SETUP="$WS_DIR/install/setup.bash"

if [ ! -f "$INSTALL_SETUP" ]; then
    echo "[run_sim] Workspace not built. Run: bash scripts/build_ros.sh"
    exit 1
fi

source /opt/ros/humble/setup.bash
source "$INSTALL_SETUP"

echo "[run_sim] Launching UAV simulation ..."
ros2 launch uav_sim sim.launch.py "$@"
