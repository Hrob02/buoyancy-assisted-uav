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
- MATLAB R2023b+ (for modelling)
- [pre-commit](https://pre-commit.com/)

### 1 — Clone and set up the Python environment

```bash
git clone https://github.com/Hrob02/buoyancy-assisted-uav.git
cd buoyancy-assisted-uav
bash scripts/setup_dev_env.sh
source .venv/bin/activate
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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Citation

See [CITATION.cff](CITATION.cff).

## License

MIT — see [LICENSE](LICENSE).
