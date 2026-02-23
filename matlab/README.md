# MATLAB Workspace

This directory contains all MATLAB modelling code.

## Directory Layout

| Directory | Purpose |
|---|---|
| `model/` | Core physics/aerodynamic model functions |
| `scripts/` | Entry-point scripts — run these to reproduce results |
| `data/` | Input datasets for the models |
| `results/` | Generated numerical outputs (git-ignored) |
| `figures/` | Generated plots (git-ignored) |
| `tests/` | MATLAB unit tests (mlunit or built-in) |

## Getting Started

1. Open MATLAB and `cd` to this directory.
2. Run `scripts/setup_paths.m` to configure the MATLAB path.
3. Run `scripts/main.m` to execute the full modelling pipeline.

## Conventions

- Functions are in `model/` with one function per file, named after the function.
- Entry-point scripts are in `scripts/` and should be self-contained after `setup_paths.m`.
- All physical quantities use SI units unless stated in inline comments.
- Use `fprintf` for progress messages, not `disp`.
