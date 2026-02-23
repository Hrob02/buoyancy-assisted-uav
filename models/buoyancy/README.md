# Buoyancy Models

Documents the buoyancy force contributions from the lifting gas envelope.

## Key Parameters

| Symbol | Description | Units |
|---|---|---|
| V_envelope | Envelope volume | m³ |
| ρ_air | Ambient air density | kg/m³ |
| ρ_gas | Lifting gas density | kg/m³ |
| F_b | Buoyancy force | N |

## Model

F_b = (ρ_air − ρ_gas) × V_envelope × g

## References

- Buoyancy model: see `matlab/model/buoyancy_model.m`
