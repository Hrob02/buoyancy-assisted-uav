# Duty-Cycle Thrust Evaluation (MATLAB)

This repository now uses a MATLAB-first duty-cycle evaluation pipeline for buoyancy-assisted Crazyflie analysis.

## Pipeline Location

- `matlab/scripts/duty_cycle/run_duty_cycle_analysis.m`

## What It Compares

1. Continuous hover with buoyancy assistance.
2. Duty-cycled thrust with buoyancy assistance.

Both are evaluated over the same cycle period:

- `T_cycle = T_on + T_off`

The analysis reports whether duty-cycled thrust is beneficial and physically feasible.

## Default Sweep Focus

The default experiment now uses a near-neutral buoyancy sweep to target the intended design region where helium supports most of the vehicle weight:

- `buoyancy_ratios = 0.85:0.005:0.995`
- optional idealized reference case: `buoyancy_ratio = 1.00`
- `T_on_values_s = 0.05:0.05:1.00`
- `T_off_values_s = 0.10:0.10:5.00`

Supported sweep modes in configuration:

- `near_neutral` (default)
- `broad`
- `custom`

## Core Feasibility Checks

A duty-cycle case is only marked feasible when all checks pass:

- average total duty-cycle power is lower than continuous-hover total power,
- altitude drop remains within configured tolerance,
- burst power and burst current stay below battery limits,
- required on-thrust stays below Crazyflie-scale thrust capability estimate.

## Result Interpretation Language

Console output and generated markdown use conditional interpretation text:

- If feasible cases are found: duty cycling can reduce total average power, but gains are typically marginal and limited to a narrow buoyancy-ratio and timing region.
- If feasible cases are not found: under current assumptions, continuous low-thrust hover is more efficient than the tested motor-off/motor-on strategy.

Case labels are also conditional:

- `Best feasible case` is reported when at least one feasible case exists.
- `Closest infeasible case` is reported only when no feasible case exists.

Feasibility threshold wording is bounded by the tested sweep range:

- If feasibility starts at the lower tested buoyancy bound, output states that a lower-buoyancy sweep is required to identify the true lower threshold.
- Otherwise, output reports the first buoyancy ratio where feasibility appears.

## Input Baseline

The model uses Crazyflie-focused baseline values (mass, battery, nominal voltage, C-rating, rotor geometry, and environmental constants) from the duty-cycle configuration file:

- `matlab/scripts/duty_cycle/config_duty_cycle_parameters.m`

## Generated Outputs

CSV and markdown outputs:

- `matlab/results/duty_cycle/duty_cycle_parameter_table.csv`
- `matlab/results/duty_cycle/duty_cycle_summary_table.csv`
- `matlab/results/duty_cycle/duty_cycle_feasibility_table.csv`
- `matlab/results/duty_cycle/duty_cycle_best_cases.csv`
- `matlab/results/duty_cycle/duty_cycle_closest_cases.csv`
- `matlab/results/duty_cycle/duty_cycle_failed_cases.csv`
- `matlab/results/duty_cycle/feasibility_by_buoyancy_ratio.csv`
- `matlab/results/duty_cycle/near_neutral_feasibility_threshold.csv`
- `matlab/results/duty_cycle/duty_cycle_assumptions.md`
- `matlab/results/duty_cycle/continuous_hover_baseline_cases.csv`

Figure outputs:

- `matlab/figures/duty_cycle/power_vs_buoyancy_ratio.png`
- `matlab/figures/duty_cycle/endurance_vs_buoyancy_ratio.png`
- `matlab/figures/duty_cycle/endurance_vs_buoyancy_ratio_log.png`
- `matlab/figures/duty_cycle/duty_cycle_feasibility_map.png`
- `matlab/figures/duty_cycle/duty_cycle_feasibility_map_BR_0p900.png`
- `matlab/figures/duty_cycle/duty_cycle_feasibility_map_BR_0p950.png`
- `matlab/figures/duty_cycle/duty_cycle_feasibility_map_BR_0p980.png`
- `matlab/figures/duty_cycle/duty_cycle_feasibility_map_BR_0p990.png`
- `matlab/figures/duty_cycle/duty_cycle_feasibility_map_BR_0p995.png`
- `matlab/figures/duty_cycle/altitude_drop_vs_toff.png`
- `matlab/figures/duty_cycle/energy_per_cycle_comparison.png`
- `matlab/figures/duty_cycle/best_case_summary.png`
- `matlab/figures/duty_cycle/best_power_reduction_vs_buoyancy_ratio.png`
- `matlab/figures/duty_cycle/best_endurance_improvement_vs_buoyancy_ratio.png`
- `matlab/figures/duty_cycle/near_neutral_feasibility_boundary.png`

## Notes

- This is a simulation pipeline for feasibility screening.
- It does not replace experimental validation or a closed-loop flight controller.
- Assumptions and model limitations are documented in the generated assumptions file.
