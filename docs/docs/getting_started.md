# Getting Started

## Prerequisites

- Python ≥ 3.10
- ROS 2 Humble
- MATLAB R2023b+

## Setup

```bash
git clone https://github.com/Hrob02/buoyancy-assisted-uav.git
cd buoyancy-assisted-uav
bash scripts/setup_dev_env.sh
```

## Build ROS 2 workspace

```bash
bash scripts/build_ros.sh
```

## Run workflows from VS Code tasks

Open the command palette and run Tasks: Run Task, then select one of:

- Run ROS Sim
- Run MATLAB Envelope Study
- Run MATLAB Duty-Cycle Analysis

Use Stop ROS Sim to cleanly stop Gazebo and related ROS processes.

## Run from command line (optional)

### ROS simulation

```bash
bash scripts/run_sim.sh
```

### MATLAB envelope geometry study

```bash
matlab -batch "cd('matlab'); run('scripts/setup_paths.m'); run('scripts/main.m');"
```

Envelope geometry outputs are written to:

- matlab/results/envelope_geometry
- matlab/figures/envelope_geometry

### MATLAB duty-cycle analysis

```bash
matlab -batch "cd('matlab/duty_cycle'); run_duty_cycle_analysis"
```

## Duty-cycle outputs

The duty-cycle analysis writes results to:

- matlab/results/duty_cycle
- matlab/figures/duty_cycle

Interpretation language in generated outputs is conditional:

- If feasible cases exist: results report a Best feasible case and describe gains as limited/marginal.
- If feasible cases do not exist: results report a Closest infeasible case and state that continuous low-thrust hover is more efficient under current assumptions.
