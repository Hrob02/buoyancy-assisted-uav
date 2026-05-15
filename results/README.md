# Shared Results Directory

This directory stores generated outputs from Python/ROS analysis utilities and MATLAB analysis scripts.

## Layout

- `duty_cycle_battery/`
  - `duty_cycle_battery_test.csv`
  - `duty_cycle_battery_comparison.png`
  - Produced by: `ros_ws/src/uav_sim/uav_sim/duty_cycle_battery.py`
- `matlab_analysis/`
  - `buoyancy_test_results.csv`
  - `shape_analysis_results.csv`
  - `battery_life_results.csv`
  - `relevant_graph_outputs.png`
  - Produced by: `matlab/scripts/envelope_trade_study.m` and `matlab/tests/test_buoyancy_model.m`

## Notes

- Generated results may be overwritten when tests or scripts are rerun.
- Paths are resolved relative to the repository root.
- Empirical constants used in models should be calibrated against physical testing.