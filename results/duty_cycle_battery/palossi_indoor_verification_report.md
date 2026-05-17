# Palossi-Style Indoor Duty-Cycle Verification

## Controlled Framework
- Indoor disturbance force ratio fixed to 0.008 of vehicle weight.
- Disturbance profiles limited to sine and gust (step excluded from primary verification).
- Disturbance frequencies: 0.25, 0.5, 1.0, 2.0 Hz.
- Duty-cycle sweep: duty in {0.20, 0.30, 0.40}, frequency in {6, 10, 14} Hz.

## Best Reliable Duty Configuration
- duty_cycle: 0.20
- duty_frequency_hz: 6.0
- stable_case_fraction: 100.0%
- duty_to_continuous_endurance_ratio: 1.387x
- duty_to_no_buoyancy_endurance_ratio: 17.142x
- continuous_to_no_buoyancy_endurance_ratio: 12.358x

## Interpretation
This controlled indoor framework compares the same disturbance envelope across controllers and sweeps duty parameters before drawing conclusions.
It supports a methodologically stronger verification of duty-cycled thrust than single-setting comparisons and makes cross-study interpretation with Palossi-style baseline framing explicit.