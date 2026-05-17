# Duty-Cycle Vertical Control Experiment

This experiment evaluates whether duty-cycled thrust is useful under buoyancy-assisted flight by measuring both energy use and vertical regulation performance.

## Research Question

The central question is:

$$
\text{Can duty-cycled thrust reduce energy use while maintaining acceptable altitude regulation?}
$$

This is not a pure battery-life problem. A controller is only useful if it saves energy **and** stays within stability limits.

## Dynamic Model

The experiment uses a 1D vertical model:

$$
m\ddot z = T(t) + F_b + d(t) - mg
$$

where:

- $m$ is total mass
- $z$ is altitude error relative to the reference hover position
- $T(t)$ is rotor thrust
- $F_b$ is buoyant force
- $d(t)$ is a sinusoidal vertical disturbance force

Linear damping is also included in the simulation to keep the vertical dynamics realistic:

$$
\ddot z = \frac{T(t) + F_b + d(t) - mg}{m} - c\dot z
$$

## Battery and PWM Model

The battery model is anchored to a Crazyflie-style baseline hover duration of 7 minutes for no-buoyancy continuous hover.

Motor voltage and PWM follow:

$$
v_{motor} = v_{bat}\frac{pwm}{pwm_{max}}
$$

The required PWM increases as battery voltage decreases for the same thrust demand. When the required PWM exceeds the available maximum, the model records actuator saturation.

Battery drain is modeled relative to baseline hover power:

$$
\dot B = -\frac{100}{T_{hover,base}}\,P_{frac}(t)
$$

where $B$ is battery percentage and $P_{frac}(t)$ is the instantaneous power fraction relative to no-buoyancy hover.

## Controllers Compared

The experiment compares four control modes:

1. No buoyancy, continuous thrust
2. Buoyancy-assisted, continuous thrust
3. Buoyancy-assisted, duty-cycled thrust
4. Buoyancy-assisted, hybrid control

The hybrid controller uses duty-cycled thrust near equilibrium and switches back to continuous control when altitude or velocity errors exceed thresholds.

## Disturbance Input

The experiment now supports three disturbance profiles:

1. Sinusoidal forcing
2. Step disturbance
3. Windowed gust disturbance

The sinusoidal case is:

$$
d(t) = A_d\sin(2\pi f_d t)
$$

The step case is a constant offset applied after a start time, and the gust case is a finite-duration sinusoid multiplied by a decaying envelope. This gives a cleaner progression from frequency-domain testing to transient-response testing.

For this project, the primary assumption is low-disturbance indoor operation. The default run therefore uses a lower disturbance force ratio and lower frequency sweep for the main comparison. The step profile is retained as a stress-test profile to represent higher-disturbance conditions (for example, drafty or outdoor-like scenarios).

## Metrics

Each run records both energy and regulation metrics.

Energy metrics:

$$
E_{use} = 100 - B_{final}
$$

$$
\bar P = \frac{1}{T}\int_0^T P_{frac}(t)\,dt
$$

Stability metrics:

$$
e_{RMS} = \sqrt{\frac{1}{T}\int_0^T z(t)^2\,dt}
$$

$$
e_{max} = \max_t |z(t)|
$$

The simulation also records time spent outside an altitude tolerance band.

## Decision Rule

Duty-cycled thrust is only considered useful if it satisfies both:

$$
e_{max} \le e_{allow}
$$

and

$$
e_{RMS} \le e_{RMS,allow}
$$

while also reducing energy use relative to continuous buoyancy-assisted control.

## Interpreting Results

The relevant conclusion is not simply that continuous control is better. Continuous control will usually be the stability reference. The real scientific question is whether duty-cycled or hybrid control can achieve an acceptable energy-stability tradeoff.

Possible outcomes:

- Lower energy and acceptable error: duty cycling is a viable strategy.
- Lower energy but poor regulation: duty cycling is not practically useful on its own.
- Similar energy and worse regulation: duty cycling offers no advantage.
- Hybrid improves energy while preserving regulation: hybrid control is the better operating strategy.

If two plotted outputs overlap exactly, the plotting code suppresses the duplicate line so the figure only shows variables that actually change the output.

## Output Files

The Python experiment writes:

- `results/duty_cycle_battery/vertical_control_summary.csv`
- `results/duty_cycle_battery/vertical_control_timeseries.csv`
- `results/duty_cycle_battery/vertical_control_experiment.png`
- `results/duty_cycle_battery/vertical_control_summary_report.md`

These outputs are intended to support both engineering interpretation and report-ready figures.

## Reporting Utility

To generate a compact Markdown interpretation from the summary CSV, run:

```bash
python scripts/summarize_duty_cycle_experiment.py
```

This writes a short report that identifies the lowest-energy stable controller for each disturbance profile.

Because each run is simulated until depletion, battery-used percentage is near 100% by design. The report therefore ranks stable controllers by endurance (time to empty) and regulation error.