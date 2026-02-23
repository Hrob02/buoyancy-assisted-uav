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

## Usage

All scripts should be run from the **repository root**:

```bash
bash scripts/setup_dev_env.sh
bash scripts/build_ros.sh
bash scripts/run_sim.sh
bash scripts/lint.sh
```
