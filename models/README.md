# Models

Language-agnostic model documentation and reference sheets.

## Purpose

This directory documents the mathematical models used across the project.
Implementations live in:
- `matlab/model/` — MATLAB implementations
- `ros_ws/src/uav_sim/` — Python implementations used in ROS 2 nodes

## Contents

| File/Folder | Description |
|---|---|
| `aerodynamics/` | Lift, drag, and moment model documentation |
| `energy/` | Battery and power consumption model notes |
| `buoyancy/` | Buoyancy force derivations |

## Conventions

- All physical quantities use SI units unless otherwise stated.
- Coordinate frame: NED (North-East-Down) for flight dynamics.
