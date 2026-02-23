# ROS 2 Workspace

The ROS 2 workspace lives under `ros_ws/` and follows the standard colcon layout.

## Packages

| Package | Description |
|---|---|
| `uav_sim` | Simulation nodes — flight controller stub, sensor publisher |
| `uav_interfaces` | Custom message/service type placeholders |

## Build

```bash
source /opt/ros/humble/setup.bash
cd ros_ws
colcon build --symlink-install
source install/setup.bash
```

## Launch

```bash
ros2 launch uav_sim sim.launch.py
```
