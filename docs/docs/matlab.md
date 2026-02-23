# MATLAB Modelling

All MATLAB source lives under `matlab/`.

## Directory layout

| Directory | Purpose |
|---|---|
| `model/` | Core physics/aerodynamic model functions |
| `scripts/` | Entry-point scripts (run these) |
| `data/` | Input datasets (tracked) |
| `results/` | Generated numerical results (git-ignored) |
| `figures/` | Generated plots (git-ignored) |
| `tests/` | MATLAB unit tests |

## Running

1. Open MATLAB and `cd` to `matlab/`.
2. Run `scripts/setup_paths.m` to add all subdirectories to the path.
3. Run `scripts/main.m` to execute the main modelling pipeline.
