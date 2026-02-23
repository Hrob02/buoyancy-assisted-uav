#!/usr/bin/env bash
# build.sh — Build the ROS 2 workspace (run from ros_ws/ or repo root).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"

echo "[build.sh] Building ROS 2 workspace at: $WS_DIR"

source /opt/ros/humble/setup.bash
cd "$WS_DIR"
colcon build --symlink-install

echo "[build.sh] Build complete. Source with:"
echo "  source $WS_DIR/install/setup.bash"
