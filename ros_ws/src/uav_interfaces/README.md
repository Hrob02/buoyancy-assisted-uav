# uav_interfaces

Custom ROS 2 message and service type definitions for the buoyancy-assisted UAV project.

## Status

**Placeholder** — no custom interfaces are defined yet.

Add `.msg`, `.srv`, or `.action` files here when project-specific interfaces are needed,
then uncomment the `rosidl_generate_interfaces` block in `CMakeLists.txt`.

## Example messages to add

| Interface | File | Description |
|---|---|---|
| UavState | `msg/UavState.msg` | Full vehicle state (position, velocity, attitude) |
| SetAltitude | `srv/SetAltitude.srv` | Service to command a target altitude |
