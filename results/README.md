# Shared Results Directory

This directory stores generated outputs from Python/ROS analysis utilities and MATLAB analysis scripts.

## Layout

- `duty_cycle_battery/`
  - `duty_cycle_battery_test.csv`
  - `duty_cycle_battery_comparison.png`
  - Produced by: `ros_ws/src/uav_sim/uav_sim/duty_cycle_battery.py`
- `../matlab/results/envelope_geometry/`
  - `envelope_decision_matrix.csv`
  - `envelope_engineering_significance_summary.csv`
  - `envelope_sensitivity_results.csv`
  - `envelope_ranking_robustness.csv`
  - `envelope_pareto_analysis.csv`
  - `envelope_shape_recommendation.md`
  - `envelope_geometry_assumptions.md`
  - Produced by: `matlab/scripts/run_envelope_geometry_analysis.m`
- `../matlab/figures/envelope_geometry/`
  - `envelope_metric_comparison.png`
  - `envelope_decision_score.png`
  - `envelope_sensitivity_ranking.png`
  - `envelope_pareto_plot.png`
  - `envelope_geometry_dimensions.png`
  - Produced by: `matlab/scripts/run_envelope_geometry_analysis.m`

## Notes

- Generated results may be overwritten when tests or scripts are rerun.
- Paths are resolved relative to the repository root.
- Empirical constants used in models should be calibrated against physical testing.