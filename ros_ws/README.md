# ROS 2 Workspace (`ros_ws/`)

This directory is a standard colcon workspace for ROS 2 Humble.

## Layout

```
ros_ws/
├── scripts/        # Helper build scripts
├── src/
│   ├── uav_interfaces/   # Custom message/service placeholders
│   └── uav_sim/          # Main simulation Python package
├── build/          # colcon build output  (git-ignored)
├── install/        # colcon install tree  (git-ignored)
└── log/            # colcon build logs    (git-ignored)
```

## Build

```bash
source /opt/ros/humble/setup.bash
cd ros_ws
colcon build --symlink-install
source install/setup.bash
```

Or use the helper:

```bash
bash ros_ws/scripts/build.sh
```

## Launch

```bash
ros2 launch uav_sim sim.launch.py
```

## Test

```bash
cd ros_ws
colcon test --packages-select uav_sim
colcon test-result --verbose
```
