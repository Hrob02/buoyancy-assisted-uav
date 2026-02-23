#!/usr/bin/env bash
# build_ros.sh — Source ROS 2 and build the colcon workspace.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="$REPO_ROOT/ros_ws"

echo "[build_ros] Sourcing ROS 2 Humble ..."
source /opt/ros/humble/setup.bash

echo "[build_ros] Building workspace at $WS_DIR ..."
cd "$WS_DIR"
colcon build --symlink-install

echo ""
echo "[build_ros] Build complete. Source the workspace with:"
echo "  source $WS_DIR/install/setup.bash"
