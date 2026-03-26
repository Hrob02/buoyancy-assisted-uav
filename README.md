# Buoyancy-Assisted UAV

> Honours project: aerodynamic + energy/performance modelling (MATLAB) and ROS 2 simulation (Python) for a buoyancy-assisted UAV in mixed agriculture.

[![CI](https://github.com/Hrob02/buoyancy-assisted-uav/actions/workflows/ci.yml/badge.svg)](https://github.com/Hrob02/buoyancy-assisted-uav/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Project Overview

This repository contains:

| Layer | Location | Purpose |
|---|---|---|
| Aerodynamic & energy models | `matlab/` | Physics-based modelling in MATLAB |
| Shared model reference | `models/` | Language-agnostic model documentation |
| ROS 2 workspace | `ros_ws/` | Python packages for Gazebo/RViz simulation |
| Desktop UI | `ui/` | Optional PyQt/PySide visualisation |
| Shared datasets | `data/` | Input data (tracked) and generated outputs (ignored) |
| Documentation | `docs/` | MkDocs site scaffold |

---

## Directory Tree

```
buoyancy-assisted-uav/
├── .github/
│   └── workflows/
│       └── ci.yml
├── data/                   # Shared datasets (see data/README.md)
├── docs/                   # MkDocs documentation scaffold
│   ├── docs/
│   │   └── index.md
│   └── mkdocs.yml
├── matlab/                 # MATLAB modelling workspace
│   ├── data/
│   ├── figures/
│   ├── model/
│   ├── results/
│   ├── scripts/
│   ├── tests/
│   └── README.md
├── models/                 # Language-agnostic model references
│   └── README.md
├── ros_ws/                 # ROS 2 colcon workspace
│   ├── scripts/
│   │   ├── build.sh
│   │   └── build.ps1
│   └── src/
│       ├── uav_interfaces/
│       └── uav_sim/
├── scripts/                # Root-level helper scripts
│   ├── build_ros.sh
│   ├── build_ros.ps1
│   ├── lint.sh
│   ├── run_sim.sh
│   ├── setup_dev_env.sh
│   └── setup_dev_env.ps1
├── ui/                     # Optional Python desktop UI
│   ├── widgets/
│   ├── app.py
│   └── README.md
├── .gitignore
├── .pre-commit-config.yaml
├── CITATION.cff
├── CONTRIBUTING.md
├── LICENSE
├── pyproject.toml
└── README.md
```

---

## Quickstart

### Prerequisites

- Python ≥ 3.10
- ROS 2 Humble (for simulation)
- MATLAB R2025b+ (for modelling)
- [pre-commit](https://pre-commit.com/)

## MATLAB Libraries
- Statistics and Machine Learning Toolbox

## WSL Setup (Tested Environment)

This project has been developed and tested using Windows Subsystem for Linux (WSL2) with Ubuntu 22.04.

---

### Install WSL and Ubuntu

In PowerShell (run as administrator):

```powershell
wsl --install -d Ubuntu-22.04
```

Restart your machine if prompted.

After installation, launch Ubuntu and complete the initial setup (username and password).

---

### Install ROS 2 Humble

Set locale:

```bash
sudo apt update
sudo apt install locales -y
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
```

Enable required repositories:

```bash
sudo apt install software-properties-common -y
sudo add-apt-repository universe
```

Add ROS 2 repository:

```bash
sudo apt update
sudo apt install curl -y
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
```

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
| sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
```

Install ROS 2:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install ros-humble-desktop -y
```

---

### Workspace Setup

Clone the repository into a ROS 2 workspace:

```bash
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src
git clone https://github.com/Hrob02/buoyancy-assisted-uav.git
```

Install dependencies:

```bash
cd ~/ros2_ws
sudo apt install python3-colcon-common-extensions python3-rosdep python3-vcstool -y
sudo rosdep init
rosdep update
rosdep install --from-paths src --ignore-src -r -y
```

Build the workspace:

```bash
colcon build --symlink-install
```

---

### Gazebo and RViz

Install simulation tools:

```bash
sudo apt install gazebo ros-humble-gazebo-ros-pkgs -y
sudo apt install ros-humble-rviz2 -y
```

Run:

```bash
gazebo
rviz2
```

---

### Optional: Automatic Environment Sourcing

Add the following to `~/.bashrc` to automatically source ROS 2 and the workspace in every new terminal:

```bash
[ -f /opt/ros/humble/setup.bash ] && source /opt/ros/humble/setup.bash
[ -f ~/ros2_ws/install/setup.bash ] && source ~/ros2_ws/install/setup.bash
```

Apply changes:

```bash
source ~/.bashrc
```

---

### Notes

* This setup uses Ubuntu 22.04 (Jammy) and ROS 2 Humble.
* RViz is launched using `rviz2` (not `rviz`).
* GUI applications (Gazebo and RViz) run via WSLg.


### 1 — Clone and set up the Python environment

```bash
git clone https://github.com/Hrob02/buoyancy-assisted-uav.git
cd buoyancy-assisted-uav
bash scripts/setup_dev_env.sh
source .venv/bin/activate
```

Or install from `requirements.txt` directly:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2 — Build the ROS 2 workspace

```bash
bash scripts/build_ros.sh
```

### 3 — Run the placeholder simulation

```bash
bash scripts/run_sim.sh
```

### 4 — Run linting

```bash
bash scripts/lint.sh
```

### 5 — MATLAB modelling

Open MATLAB, navigate to `matlab/`, and run:

```matlab
run('scripts/setup_paths.m')
run('scripts/main.m')
```

---

## VS Code Tasks & Extensions

This repo includes task shortcuts in `.vscode/tasks.json`:

- **Run ROS Sim (WSL)** — launches `scripts/run_sim.sh` in WSL
- **Run MATLAB Sim** — runs `matlab/scripts/main.m` via MATLAB batch mode

Run them with:

1. `Ctrl+Shift+P`
2. **Tasks: Run Task**
3. Select the task

Recommended VS Code extensions:

- **ms-python.python** (Python tooling)
- **ms-iot.vscode-ros** (ROS integration)
- **GitHub.copilot** (optional AI assistance)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Citation

See [CITATION.cff](CITATION.cff).

## License

MIT — see [LICENSE](LICENSE).
