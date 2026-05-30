# Root Scripts

Helper scripts for common development tasks.

| Script | Platform | Description |
|---|---|---|
| `setup_dev_env.sh` | Linux/macOS | Create `.venv` and install Python dev tools |
| `setup_dev_env.ps1` | Windows | Create `.venv` and install Python dev tools |
| `build_ros.sh` | Linux/macOS | Build the ROS 2 colcon workspace |
| `build_ros.ps1` | Windows | Placeholder — use WSL2 |
| `run_sim.sh` | Linux/macOS | Source workspace and launch simulation |
| `lint.sh` | Linux/macOS | Run ruff + black + isort checks |

## MATLAB Launchers (Windows)

MATLAB launchers are organized by workflow under `scripts/matlab/`:

| Script | Description |
|---|---|
| `scripts/matlab/envelope_geometry/run_matlab.ps1` | Envelope geometry study |
| `scripts/matlab/duty_cycle/run_matlab_duty_cycle.ps1` | Duty-cycle analysis |
| `scripts/matlab/buoyancy_measurement/run_matlab_buoyancy_measurement.ps1` | Buoyant lift measurement workflow |
| `scripts/matlab/hover_endurance/run_matlab_hover_endurance.ps1` | Hover endurance measurement workflow |

## Usage

All scripts should be run from the **repository root**:

```bash
bash scripts/setup_dev_env.sh
bash scripts/build_ros.sh
bash scripts/run_sim.sh
bash scripts/lint.sh
```
