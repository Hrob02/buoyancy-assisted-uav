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

### Buoyancy Measurement Workflow

For interactive foil-balloon lift experiment processing:

1. Run `scripts/setup_paths.m`.
2. Run `scripts/buoyancy_measurement/run_buoyancy_measurement_analysis.m`.

Outputs are written to:
- `matlab/results/buoyancy_measurement/`
- `matlab/figures/buoyancy_measurement/`

### Envelope Shape Rotation Animation Workflow

For rotating animations of candidate envelope shapes (sphere, cuboid, prolate ellipsoid, flattened ellipsoid):

1. Run `scripts/setup_paths.m`.
2. Run `scripts/envelope_geometry/run_envelope_shape_rotation_animation.m`.

Outputs are written to:
- `matlab/figures/envelope_geometry/shape_rotation/`

Each shape exports:
- `*_rotation.gif`
- `*_rotation.mp4` (when MPEG-4 export is supported by your MATLAB installation)

## Conventions

- Functions are in `model/` with one function per file, named after the function.
- Entry-point scripts are in `scripts/` and should be self-contained after `setup_paths.m`.
- All physical quantities use SI units unless stated in inline comments.
- Use `fprintf` for progress messages, not `disp`.
