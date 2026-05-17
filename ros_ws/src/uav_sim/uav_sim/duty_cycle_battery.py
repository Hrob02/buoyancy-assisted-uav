"""Closed-loop vertical control experiment for buoyancy-assisted duty cycling.

The experiment compares four operating modes under the same vertical
disturbance input:
1) no buoyancy, continuous thrust,
2) buoyancy-assisted, continuous thrust,
3) buoyancy-assisted, duty-cycled thrust,
4) buoyancy-assisted, hybrid control.

The battery model is anchored to a 7 minute Crazyflie hover baseline at
no-buoyancy continuous hover and applies voltage-aware PWM compensation:

    v_motor = v_bat * pwm / pwm_max

The purpose is to evaluate the energy-stability tradeoff, not just mean
power draw.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
def crazyflie_fitted_config() -> ExperimentConfig:
    """Return ExperimentConfig with parameters fit to measured Crazyflie data."""
    # Sourced from SDFs, YAMLs, and MATLAB script
    return ExperimentConfig(
        mass_kg=0.028,  # 28g baseline (see MATLAB, SDF)
        buoyancy_assist_ratio=0.99,  # typical for experiment
        baseline_hover_time_min=7.0,  # measured hover time
        battery_voltage_full=4.2,
        battery_voltage_empty=3.3,
        hover_pwm_fraction_at_full_battery=0.46,  # matches base_hover_throttle in sim_params_crazyflie.yaml
        base_load_fraction=0.08,  # as before
        duty_motor_off_power_fraction=0.05,
        disturbance_force_fraction_of_weight=0.03,  # can be tuned from logs
        duty_cycle=0.35,  # as before
        duty_cycle_frequency_hz=10.0,
        hybrid_error_threshold_m=0.004,
        hybrid_velocity_threshold_m_s=0.012,
        controller_kp=0.22,  # matches sim_params_crazyflie.yaml
        controller_kd=0.12,  # matches sim_params_crazyflie.yaml
        linear_damping_per_s=1.4,  # as before
        altitude_tolerance_m=0.25,  # matches sim_params_crazyflie.yaml
        rms_tolerance_m=0.02,
        max_thrust_fraction_of_weight=1.3,
        simulation_dt_s=0.02,
        output_sample_period_s=0.25,
        max_duration_s=7200.0,
    )


def crazyflie_indoor_config() -> ExperimentConfig:
    """Return a fitted config for low-disturbance indoor operation."""
    fitted = crazyflie_fitted_config()
    return ExperimentConfig(
        mass_kg=fitted.mass_kg,
        buoyancy_assist_ratio=fitted.buoyancy_assist_ratio,
        baseline_hover_time_min=fitted.baseline_hover_time_min,
        battery_voltage_full=fitted.battery_voltage_full,
        battery_voltage_empty=fitted.battery_voltage_empty,
        hover_pwm_fraction_at_full_battery=fitted.hover_pwm_fraction_at_full_battery,
        base_load_fraction=fitted.base_load_fraction,
        duty_motor_off_power_fraction=fitted.duty_motor_off_power_fraction,
        disturbance_force_fraction_of_weight=0.008,
        duty_cycle=fitted.duty_cycle,
        duty_cycle_frequency_hz=fitted.duty_cycle_frequency_hz,
        hybrid_error_threshold_m=fitted.hybrid_error_threshold_m,
        hybrid_velocity_threshold_m_s=fitted.hybrid_velocity_threshold_m_s,
        controller_kp=fitted.controller_kp,
        controller_kd=fitted.controller_kd,
        linear_damping_per_s=fitted.linear_damping_per_s,
        altitude_tolerance_m=fitted.altitude_tolerance_m,
        rms_tolerance_m=fitted.rms_tolerance_m,
        max_thrust_fraction_of_weight=fitted.max_thrust_fraction_of_weight,
        simulation_dt_s=fitted.simulation_dt_s,
        output_sample_period_s=fitted.output_sample_period_s,
        max_duration_s=fitted.max_duration_s,
    )


DEFAULT_INDOOR_DISTURBANCE_FREQUENCIES_HZ = (0.25, 0.5, 1.0, 2.0)
import math
from pathlib import Path
from typing import Iterable, Sequence

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

SUMMARY_COLUMNS = (
    "controller",
    "disturbance_profile",
    "disturbance_frequency_hz",
    "disturbance_force_fraction_of_weight",
    "mass_g",
    "buoyancy_assist_ratio",
    "trial_duration_s",
    "time_to_empty_s",
    "battery_used_pct",
    "final_battery_pct",
    "rms_altitude_error_m",
    "max_altitude_error_m",
    "time_outside_tolerance_s",
    "mean_power_fraction",
    "mean_pwm_pct",
    "mean_thrust_n",
    "saturation_fraction",
    "stable_within_thresholds",
)

TIMESERIES_COLUMNS = (
    "controller",
    "disturbance_profile",
    "disturbance_frequency_hz",
    "time_s",
    "altitude_m",
    "vertical_velocity_m_s",
    "thrust_n",
    "battery_pct",
    "battery_voltage_v",
    "pwm_pct",
    "cumulative_energy_pct",
    "controller_mode",
    "instant_power_fraction",
)

NO_BUOYANCY_CONTINUOUS = "no_buoyancy_continuous"
BUOYANCY_ASSISTED_CONTINUOUS = "buoyancy_assisted_continuous"
BUOYANCY_ASSISTED_DUTY = "buoyancy_assisted_duty_cycled"
BUOYANCY_ASSISTED_HYBRID = "buoyancy_assisted_hybrid"


@dataclass(frozen=True)
class ExperimentConfig:
    mass_kg: float = 0.035
    buoyancy_assist_ratio: float = 0.99
    baseline_hover_time_min: float = 7.0
    battery_voltage_full: float = 4.2
    battery_voltage_empty: float = 3.3
    hover_pwm_fraction_at_full_battery: float = 0.55
    base_load_fraction: float = 0.08
    duty_motor_off_power_fraction: float = 0.05
    disturbance_force_fraction_of_weight: float = 0.03
    duty_cycle: float = 0.35
    duty_cycle_frequency_hz: float = 4.0
    hybrid_error_threshold_m: float = 0.004
    hybrid_velocity_threshold_m_s: float = 0.012
    controller_kp: float = 6.0
    controller_kd: float = 3.0
    linear_damping_per_s: float = 1.4
    altitude_tolerance_m: float = 0.05
    rms_tolerance_m: float = 0.02
    max_thrust_fraction_of_weight: float = 1.3
    simulation_dt_s: float = 0.02
    output_sample_period_s: float = 0.25
    max_duration_s: float = 7200.0


def repository_root_from_file() -> Path:
    """Resolve repository root from this file location."""
    return Path(__file__).resolve().parents[4]


def ensure_results_dir(repo_root: Path | None = None) -> Path:
    """Create and return shared duty-cycle results directory."""
    root = repo_root or repository_root_from_file()
    results_dir = root / "results" / "duty_cycle_battery"
    results_dir.mkdir(parents=True, exist_ok=True)
    return results_dir


def _clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def _battery_voltage(config: ExperimentConfig, battery_pct: float) -> float:
    span = config.battery_voltage_full - config.battery_voltage_empty
    return config.battery_voltage_empty + span * _clamp(battery_pct / 100.0, 0.0, 1.0)


def _power_fraction(
    thrust_fraction_of_weight: float,
    controller_mode: str,
    requested_thrust_n: float,
    config: ExperimentConfig,
) -> float:
    # Duty-cycle off windows reduce draw below continuous idle motor behavior.
    if controller_mode == "duty" and requested_thrust_n <= 0.0:
        return _clamp(config.duty_motor_off_power_fraction, 0.0, 1.0)
    propulsion_fraction = max(thrust_fraction_of_weight, 0.0) ** 1.5
    return config.base_load_fraction + (1.0 - config.base_load_fraction) * propulsion_fraction


def _disturbance_force(
    disturbance_profile: str,
    disturbance_frequency_hz: float,
    disturbance_amplitude_n: float,
    time_s: float,
) -> float:
    angular_term = 2.0 * math.pi * disturbance_frequency_hz * time_s
    if disturbance_profile == "sine":
        return disturbance_amplitude_n * math.sin(angular_term)
    if disturbance_profile == "step":
        return disturbance_amplitude_n if time_s >= 5.0 else 0.0
    if disturbance_profile == "gust":
        envelope = math.exp(-((time_s - 8.0) / 2.0) ** 2)
        return disturbance_amplitude_n * envelope * math.sin(angular_term)
    raise ValueError(f"Unsupported disturbance profile: {disturbance_profile}")


def _solve_actuator_response(
    requested_thrust_n: float,
    battery_voltage_v: float,
    weight_newton: float,
    config: ExperimentConfig,
) -> tuple[float, float, bool]:
    requested_fraction = _clamp(
        requested_thrust_n / max(weight_newton, 1e-9),
        0.0,
        config.max_thrust_fraction_of_weight,
    )
    if battery_voltage_v <= 0.0:
        return 0.0, 0.0, True

    pwm_required = (
        config.hover_pwm_fraction_at_full_battery
        * math.sqrt(max(requested_fraction, 0.0))
        * (config.battery_voltage_full / battery_voltage_v)
    )
    pwm_fraction = _clamp(pwm_required, 0.0, 1.0)
    actual_fraction = (
        (pwm_fraction * battery_voltage_v)
        / max(config.hover_pwm_fraction_at_full_battery * config.battery_voltage_full, 1e-9)
    ) ** 2
    actual_fraction = _clamp(actual_fraction, 0.0, config.max_thrust_fraction_of_weight)
    return actual_fraction * weight_newton, pwm_fraction, pwm_required > 1.0



def _controller_request_thrust(
    controller: str,
    time_s: float,
    altitude_m: float,
    vertical_velocity_m_s: float,
    hover_thrust_n: float,
    weight_newton: float,
    config: ExperimentConfig,
) -> tuple[float, str]:
    """Return (thrust, mode) where mode is 'continuous' or 'duty'."""
    desired_accel = config.controller_kp * (-altitude_m) - config.controller_kd * vertical_velocity_m_s
    desired_thrust_n = hover_thrust_n + config.mass_kg * desired_accel
    desired_thrust_n = _clamp(
        desired_thrust_n,
        0.0,
        config.max_thrust_fraction_of_weight * weight_newton,
    )

    if controller in (NO_BUOYANCY_CONTINUOUS, BUOYANCY_ASSISTED_CONTINUOUS):
        return desired_thrust_n, "continuous"

    if controller == BUOYANCY_ASSISTED_HYBRID and (
        abs(altitude_m) > config.hybrid_error_threshold_m
        or abs(vertical_velocity_m_s) > config.hybrid_velocity_threshold_m_s
    ):
        return desired_thrust_n, "continuous"

    pulse_phase = (time_s * config.duty_cycle_frequency_hz) % 1.0
    if pulse_phase < config.duty_cycle:
        return desired_thrust_n / max(config.duty_cycle, 1e-6), "duty"
    return 0.0, "duty"


def _simulate_controller(
    controller: str,
    disturbance_profile: str,
    disturbance_frequency_hz: float,
    config: ExperimentConfig,
) -> tuple[dict[str, float | str | bool], list[dict[str, float | str]]]:
    gravity = 9.81
    mass_kg = max(config.mass_kg, 1e-9)
    weight_newton = mass_kg * gravity
    buoyancy_ratio = 0.0 if controller == NO_BUOYANCY_CONTINUOUS else config.buoyancy_assist_ratio
    buoyancy_force_n = buoyancy_ratio * weight_newton
    hover_thrust_n = max(weight_newton - buoyancy_force_n, 0.0)
    disturbance_amplitude_n = config.disturbance_force_fraction_of_weight * weight_newton
    battery_pct = 100.0
    altitude_m = 0.0
    vertical_velocity_m_s = 0.0
    elapsed_s = 0.0
    cumulative_energy_pct = 0.0
    sample_timer_s = 0.0

    altitude_sq_sum = 0.0
    max_altitude_error_m = 0.0
    time_outside_tolerance_s = 0.0
    pwm_sum = 0.0
    thrust_sum = 0.0
    power_fraction_sum = 0.0
    saturated_steps = 0
    step_count = 0
    timeseries_rows: list[dict[str, float | str]] = []

    drain_scale_pct_per_s = 100.0 / max(config.baseline_hover_time_min * 60.0, 1e-6)

    while elapsed_s <= config.max_duration_s and battery_pct > 0.0:
        battery_voltage_v = _battery_voltage(config, battery_pct)
        requested_thrust_n, controller_mode = _controller_request_thrust(
            controller,
            elapsed_s,
            altitude_m,
            vertical_velocity_m_s,
            hover_thrust_n,
            weight_newton,
            config,
        )
        actual_thrust_n, pwm_fraction, saturated = _solve_actuator_response(
            requested_thrust_n,
            battery_voltage_v,
            weight_newton,
            config,
        )

        disturbance_force_n = _disturbance_force(
            disturbance_profile,
            disturbance_frequency_hz,
            disturbance_amplitude_n,
            elapsed_s,
        )
        thrust_fraction_of_weight = actual_thrust_n / max(weight_newton, 1e-9)
        power_fraction = _power_fraction(
            thrust_fraction_of_weight,
            controller_mode,
            requested_thrust_n,
            config,
        )
        drain_rate_pct_per_s = drain_scale_pct_per_s * power_fraction

        acceleration_m_s2 = (
            (actual_thrust_n + buoyancy_force_n + disturbance_force_n - weight_newton) / mass_kg
            - config.linear_damping_per_s * vertical_velocity_m_s
        )
        vertical_velocity_m_s += acceleration_m_s2 * config.simulation_dt_s
        altitude_m += vertical_velocity_m_s * config.simulation_dt_s

        battery_pct = max(0.0, battery_pct - drain_rate_pct_per_s * config.simulation_dt_s)
        cumulative_energy_pct = 100.0 - battery_pct

        altitude_sq_sum += altitude_m**2
        max_altitude_error_m = max(max_altitude_error_m, abs(altitude_m))
        if abs(altitude_m) > config.altitude_tolerance_m:
            time_outside_tolerance_s += config.simulation_dt_s
        pwm_sum += 100.0 * pwm_fraction
        thrust_sum += actual_thrust_n
        power_fraction_sum += power_fraction
        saturated_steps += int(saturated)
        step_count += 1

        if sample_timer_s <= 0.0 or battery_pct <= 0.0:
            timeseries_rows.append(
                {
                    "controller": controller,
                    "disturbance_profile": disturbance_profile,
                    "disturbance_frequency_hz": disturbance_frequency_hz,
                    "time_s": elapsed_s,
                    "altitude_m": altitude_m,
                    "vertical_velocity_m_s": vertical_velocity_m_s,
                    "thrust_n": actual_thrust_n,
                    "battery_pct": battery_pct,
                    "battery_voltage_v": battery_voltage_v,
                    "pwm_pct": 100.0 * pwm_fraction,
                    "cumulative_energy_pct": cumulative_energy_pct,
                    "controller_mode": controller_mode,
                    "instant_power_fraction": power_fraction,
                }
            )
            sample_timer_s = config.output_sample_period_s

        elapsed_s += config.simulation_dt_s
        sample_timer_s -= config.simulation_dt_s

    rms_altitude_error_m = math.sqrt(altitude_sq_sum / max(step_count, 1))
    summary_row: dict[str, float | str | bool] = {
        "controller": controller,
        "disturbance_profile": disturbance_profile,
        "disturbance_frequency_hz": disturbance_frequency_hz,
        "disturbance_force_fraction_of_weight": config.disturbance_force_fraction_of_weight,
        "mass_g": 1000.0 * config.mass_kg,
        "buoyancy_assist_ratio": buoyancy_ratio,
        "trial_duration_s": elapsed_s,
        "time_to_empty_s": elapsed_s,
        "battery_used_pct": 100.0 - battery_pct,
        "final_battery_pct": battery_pct,
        "rms_altitude_error_m": rms_altitude_error_m,
        "max_altitude_error_m": max_altitude_error_m,
        "time_outside_tolerance_s": time_outside_tolerance_s,
        "mean_power_fraction": power_fraction_sum / max(step_count, 1),
        "mean_pwm_pct": pwm_sum / max(step_count, 1),
        "mean_thrust_n": thrust_sum / max(step_count, 1),
        "saturation_fraction": saturated_steps / max(step_count, 1),
        "stable_within_thresholds": (
            max_altitude_error_m <= config.altitude_tolerance_m
            and rms_altitude_error_m <= config.rms_tolerance_m
        ),
    }
    return summary_row, timeseries_rows


def generate_vertical_experiment_dataset(
    disturbance_frequencies_hz: Sequence[float] | None = None,
    disturbance_profiles: Sequence[str] | None = None,
    config: ExperimentConfig | None = None,
) -> tuple[list[dict[str, float | str | bool]], list[dict[str, float | str]]]:
    frequencies = disturbance_frequencies_hz or DEFAULT_INDOOR_DISTURBANCE_FREQUENCIES_HZ
    profiles = disturbance_profiles or ("sine", "step", "gust")
    experiment_config = config or ExperimentConfig()
    summary_rows: list[dict[str, float | str | bool]] = []
    timeseries_rows: list[dict[str, float | str]] = []
    controllers = (
        NO_BUOYANCY_CONTINUOUS,
        BUOYANCY_ASSISTED_CONTINUOUS,
        BUOYANCY_ASSISTED_DUTY,
        BUOYANCY_ASSISTED_HYBRID,
    )
    for disturbance_profile in profiles:
        for frequency_hz in frequencies:
            for controller in controllers:
                summary_row, controller_timeseries = _simulate_controller(
                    controller,
                    disturbance_profile,
                    float(frequency_hz),
                    experiment_config,
                )
                summary_rows.append(summary_row)
                timeseries_rows.extend(controller_timeseries)
    return summary_rows, timeseries_rows


def save_results_csv(rows: Iterable[dict[str, float | str | bool]], output_path: Path) -> Path:
    """Write summary metrics to CSV."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=list(SUMMARY_COLUMNS))
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    return output_path


def save_timeseries_csv(rows: Iterable[dict[str, float | str]], output_path: Path) -> Path:
    """Write time-series traces to CSV."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=list(TIMESERIES_COLUMNS))
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    return output_path


def _series_for(
    rows: Sequence[dict[str, float | str]],
    controller: str,
    disturbance_profile: str,
    disturbance_frequency_hz: float,
) -> tuple[list[float], list[float], list[float]]:
    matching_rows = [
        row
        for row in rows
        if row["controller"] == controller
        and row["disturbance_profile"] == disturbance_profile
        and abs(float(row["disturbance_frequency_hz"]) - disturbance_frequency_hz) < 1e-9
    ]
    return (
        [float(row["time_s"]) / 60.0 for row in matching_rows],
        [float(row["battery_pct"]) for row in matching_rows],
        [float(row["altitude_m"]) for row in matching_rows],
    )


def _plot_unique_series(
    axis,
    x_values: Sequence[float],
    y_values: Sequence[float],
    label: str,
    seen_signatures: set[tuple[float, ...]],
    **plot_kwargs,
) -> bool:
    signature = tuple(round(value, 8) for value in y_values)
    if signature in seen_signatures:
        return False
    seen_signatures.add(signature)
    axis.plot(x_values, y_values, label=label, **plot_kwargs)
    return True


def save_results_plot(
    summary_rows: Sequence[dict[str, float | str | bool]],
    timeseries_rows: Sequence[dict[str, float | str]],
    output_path: Path,
    plot_disturbance_frequencies_hz: Sequence[float] | None = None,
    reference_profile: str = "sine",
    reference_frequency_hz: float = 2.0,
) -> Path:
    """Render experiment figure with controller and frequency comparisons."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if not summary_rows or not timeseries_rows:
        raise ValueError("summary_rows and timeseries_rows must not be empty")

    filtered_summary_rows = [row for row in summary_rows if row["disturbance_profile"] == reference_profile]
    if not filtered_summary_rows:
        raise ValueError(f"No summary rows found for disturbance profile {reference_profile}")

    available_frequencies = sorted({float(row["disturbance_frequency_hz"]) for row in filtered_summary_rows})
    if plot_disturbance_frequencies_hz is None:
        plot_frequencies = available_frequencies[: min(4, len(available_frequencies))]
    else:
        plot_frequencies = []
        for requested_frequency in plot_disturbance_frequencies_hz:
            nearest = min(
                available_frequencies,
                key=lambda value, requested=requested_frequency: abs(value - requested),
            )
            if nearest not in plot_frequencies:
                plot_frequencies.append(nearest)
    reference_frequency = min(available_frequencies, key=lambda value: abs(value - reference_frequency_hz))

    figure, axes = plt.subplots(2, 2, figsize=(13, 9))
    altitude_axis, battery_axis, duty_axis, pareto_axis = axes.flat
    altitude_seen: set[tuple[float, ...]] = set()
    battery_seen: set[tuple[float, ...]] = set()
    duty_seen: set[tuple[float, ...]] = set()

    for controller in (
        NO_BUOYANCY_CONTINUOUS,
        BUOYANCY_ASSISTED_CONTINUOUS,
        BUOYANCY_ASSISTED_DUTY,
        BUOYANCY_ASSISTED_HYBRID,
    ):
        time_values_min, battery_values_pct, altitude_values_m = _series_for(
            timeseries_rows,
            controller,
            reference_profile,
            reference_frequency,
        )
        label = controller.replace("_", " ")
        _plot_unique_series(
            altitude_axis,
            time_values_min,
            altitude_values_m,
            label,
            altitude_seen,
        )
        _plot_unique_series(
            battery_axis,
            time_values_min,
            battery_values_pct,
            label,
            battery_seen,
        )

    for frequency_hz in plot_frequencies:
        time_values_min, battery_values_pct, _ = _series_for(
            timeseries_rows,
            BUOYANCY_ASSISTED_DUTY,
            reference_profile,
            frequency_hz,
        )
        _plot_unique_series(
            duty_axis,
            time_values_min,
            battery_values_pct,
            f"{frequency_hz:.1f} Hz",
            duty_seen,
        )

    controller_styles = {
        NO_BUOYANCY_CONTINUOUS: ("o", "tab:red"),
        BUOYANCY_ASSISTED_CONTINUOUS: ("s", "tab:green"),
        BUOYANCY_ASSISTED_DUTY: ("^", "tab:blue"),
        BUOYANCY_ASSISTED_HYBRID: ("D", "tab:orange"),
    }
    for controller, (marker, color) in controller_styles.items():
        controller_rows = [
            row for row in filtered_summary_rows if row["controller"] == controller
        ]
        pareto_axis.scatter(
            [float(row["battery_used_pct"]) for row in controller_rows],
            [float(row["rms_altitude_error_m"]) for row in controller_rows],
            marker=marker,
            color=color,
            label=controller.replace("_", " "),
        )
        for row in controller_rows:
            pareto_axis.annotate(
                f"{float(row['disturbance_frequency_hz']):.1f}Hz",
                (float(row["battery_used_pct"]), float(row["rms_altitude_error_m"])),
                fontsize=7,
                xytext=(3, 3),
                textcoords="offset points",
            )

    altitude_axis.set_title(f"Altitude Error at {reference_frequency:.1f} Hz ({reference_profile})")
    altitude_axis.set_xlabel("time_min")
    altitude_axis.set_ylabel("altitude_error_m")
    altitude_axis.grid(True, alpha=0.3)
    altitude_axis.legend(fontsize=8)

    battery_axis.set_title(f"Battery Percentage at {reference_frequency:.1f} Hz ({reference_profile})")
    battery_axis.set_xlabel("time_min")
    battery_axis.set_ylabel("battery_percent_remaining")
    battery_axis.set_ylim(0.0, 100.0)
    battery_axis.grid(True, alpha=0.3)
    battery_axis.legend(fontsize=8)

    duty_axis.set_title(f"Duty-Cycled Battery Curves by Frequency ({reference_profile})")
    duty_axis.set_xlabel("time_min")
    duty_axis.set_ylabel("battery_percent_remaining")
    duty_axis.set_ylim(0.0, 100.0)
    duty_axis.grid(True, alpha=0.3)
    duty_axis.legend(fontsize=8)

    pareto_axis.set_title("Energy-Stability Tradeoff")
    pareto_axis.set_xlabel("battery_used_pct")
    pareto_axis.set_ylabel("rms_altitude_error_m")
    pareto_axis.grid(True, alpha=0.3)
    pareto_axis.legend(fontsize=8)

    figure.suptitle(
        "Buoyancy-Assisted Duty-Cycle Vertical Control Experiment",
        fontsize=14,
    )
    figure.tight_layout(rect=(0.0, 0.0, 1.0, 0.97))
    figure.savefig(output_path, dpi=180)
    plt.close(figure)

    return output_path


def run_vertical_control_experiment(
    repo_root: Path | None = None,
    disturbance_frequencies_hz: Sequence[float] | None = None,
    disturbance_profiles: Sequence[str] | None = None,
    config: ExperimentConfig | None = None,
    plot_disturbance_frequencies_hz: Sequence[float] | None = None,
    reference_profile: str = "sine",
    reference_frequency_hz: float = 2.0,
) -> tuple[Path, Path, Path, list[dict[str, float | str | bool]]]:
    """Generate summary CSV, time-series CSV, and report-style plot."""
    results_dir = ensure_results_dir(repo_root)
    experiment_config = config or ExperimentConfig()
    summary_rows, timeseries_rows = generate_vertical_experiment_dataset(
        disturbance_frequencies_hz=disturbance_frequencies_hz,
        disturbance_profiles=disturbance_profiles,
        config=experiment_config,
    )

    csv_path = save_results_csv(summary_rows, results_dir / "vertical_control_summary.csv")
    timeseries_path = save_timeseries_csv(timeseries_rows, results_dir / "vertical_control_timeseries.csv")
    plot_path = save_results_plot(
        summary_rows,
        timeseries_rows,
        results_dir / "vertical_control_experiment.png",
        plot_disturbance_frequencies_hz=plot_disturbance_frequencies_hz,
        reference_profile=reference_profile,
        reference_frequency_hz=reference_frequency_hz,
    )
    return csv_path, timeseries_path, plot_path, summary_rows


def run_duty_cycle_battery_test(
    repo_root: Path | None = None,
    disturbance_frequencies_hz: Sequence[float] | None = None,
    disturbance_profiles: Sequence[str] | None = None,
    config: ExperimentConfig | None = None,
    plot_disturbance_frequencies_hz: Sequence[float] | None = None,
    reference_profile: str = "sine",
    reference_frequency_hz: float = 2.0,
) -> tuple[Path, Path, list[dict[str, float | str | bool]]]:
    """Compatibility wrapper returning summary CSV and plot."""
    csv_path, _, plot_path, summary_rows = run_vertical_control_experiment(
        repo_root=repo_root,
        disturbance_frequencies_hz=disturbance_frequencies_hz,
        disturbance_profiles=disturbance_profiles,
        config=config,
        plot_disturbance_frequencies_hz=plot_disturbance_frequencies_hz,
        reference_profile=reference_profile,
        reference_frequency_hz=reference_frequency_hz,
    )
    return csv_path, plot_path, summary_rows


if __name__ == "__main__":
    # Default run targets indoor low-disturbance conditions and keeps step as a stress test.
    default_config = crazyflie_indoor_config()
    summary_csv_path, timeseries_csv_path, png_file, _ = run_vertical_control_experiment(
        config=default_config,
        disturbance_frequencies_hz=DEFAULT_INDOOR_DISTURBANCE_FREQUENCIES_HZ,
        disturbance_profiles=("sine", "gust", "step"),
    )
    print(f"Saved summary CSV: {summary_csv_path}")
    print(f"Saved timeseries CSV: {timeseries_csv_path}")
    print(f"Saved plot: {png_file}")
