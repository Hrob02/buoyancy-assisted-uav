"""Run an indoor-controlled duty-cycle verification sweep inspired by Palossi et al.

This script keeps disturbances in a low indoor range, sweeps duty-cycle parameters,
and writes a compact report comparing stable duty-cycled performance against
both no-buoyancy and continuous buoyancy-assisted baselines.
"""

from __future__ import annotations

import csv
import importlib
import sys
from dataclasses import replace
from pathlib import Path


def _module():
    repo_root = Path(__file__).resolve().parents[1]
    package_root = repo_root / "ros_ws" / "src" / "uav_sim"
    sys.path.insert(0, str(package_root))
    return importlib.import_module("uav_sim.duty_cycle_battery")


def _rows_for_controller(rows: list[dict[str, float | str | bool]], controller: str) -> list[dict[str, float | str | bool]]:
    return [row for row in rows if row["controller"] == controller]


def _mean(values: list[float]) -> float:
    return sum(values) / max(len(values), 1)


def _stable_rows(rows: list[dict[str, float | str | bool]]) -> list[dict[str, float | str | bool]]:
    return [row for row in rows if bool(row["stable_within_thresholds"])]


def _aggregate_endurance(rows: list[dict[str, float | str | bool]]) -> float:
    return _mean([float(row["time_to_empty_s"]) for row in rows])


def run() -> tuple[Path, Path]:
    mod = _module()
    repo_root = Path(__file__).resolve().parents[1]
    results_dir = repo_root / "results" / "duty_cycle_battery"
    results_dir.mkdir(parents=True, exist_ok=True)

    duty_cycle_grid = [0.20, 0.30, 0.40]
    duty_freq_grid_hz = [6.0, 10.0, 14.0]

    indoor_profiles = ("sine", "gust")
    indoor_freqs_hz = (0.25, 0.5, 1.0, 2.0)

    sweep_rows: list[dict[str, float | str | bool]] = []

    for duty_cycle in duty_cycle_grid:
        for duty_freq_hz in duty_freq_grid_hz:
            config = replace(
                mod.crazyflie_indoor_config(),
                duty_cycle=duty_cycle,
                duty_cycle_frequency_hz=duty_freq_hz,
            )
            summary_rows, _ = mod.generate_vertical_experiment_dataset(
                disturbance_frequencies_hz=indoor_freqs_hz,
                disturbance_profiles=indoor_profiles,
                config=config,
            )

            duty_rows = _rows_for_controller(summary_rows, mod.BUOYANCY_ASSISTED_DUTY)
            duty_stable_rows = _stable_rows(duty_rows)
            continuous_rows = _rows_for_controller(summary_rows, mod.BUOYANCY_ASSISTED_CONTINUOUS)
            baseline_rows = _rows_for_controller(summary_rows, mod.NO_BUOYANCY_CONTINUOUS)

            mean_duty_endurance = _aggregate_endurance(duty_rows)
            mean_continuous_endurance = _aggregate_endurance(continuous_rows)
            mean_baseline_endurance = _aggregate_endurance(baseline_rows)
            stable_ratio = len(duty_stable_rows) / max(len(duty_rows), 1)

            sweep_rows.append(
                {
                    "duty_cycle": duty_cycle,
                    "duty_frequency_hz": duty_freq_hz,
                    "disturbance_force_fraction_of_weight": config.disturbance_force_fraction_of_weight,
                    "stable_case_fraction": stable_ratio,
                    "mean_endurance_s_duty": mean_duty_endurance,
                    "mean_endurance_s_continuous": mean_continuous_endurance,
                    "mean_endurance_s_no_buoyancy": mean_baseline_endurance,
                    "ratio_duty_to_continuous": mean_duty_endurance / max(mean_continuous_endurance, 1e-9),
                    "ratio_duty_to_no_buoyancy": mean_duty_endurance / max(mean_baseline_endurance, 1e-9),
                    "ratio_continuous_to_no_buoyancy": mean_continuous_endurance / max(mean_baseline_endurance, 1e-9),
                }
            )

    sweep_csv = results_dir / "palossi_indoor_verification_sweep.csv"
    with sweep_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "duty_cycle",
                "duty_frequency_hz",
                "disturbance_force_fraction_of_weight",
                "stable_case_fraction",
                "mean_endurance_s_duty",
                "mean_endurance_s_continuous",
                "mean_endurance_s_no_buoyancy",
                "ratio_duty_to_continuous",
                "ratio_duty_to_no_buoyancy",
                "ratio_continuous_to_no_buoyancy",
            ],
        )
        writer.writeheader()
        writer.writerows(sweep_rows)

    best_reliable = max(sweep_rows, key=lambda r: (float(r["stable_case_fraction"]), float(r["ratio_duty_to_continuous"])))

    report_md = results_dir / "palossi_indoor_verification_report.md"
    lines = [
        "# Palossi-Style Indoor Duty-Cycle Verification",
        "",
        "## Controlled Framework",
        "- Indoor disturbance force ratio fixed to 0.008 of vehicle weight.",
        "- Disturbance profiles limited to sine and gust (step excluded from primary verification).",
        "- Disturbance frequencies: 0.25, 0.5, 1.0, 2.0 Hz.",
        "- Duty-cycle sweep: duty in {0.20, 0.30, 0.40}, frequency in {6, 10, 14} Hz.",
        "",
        "## Best Reliable Duty Configuration",
        f"- duty_cycle: {float(best_reliable['duty_cycle']):.2f}",
        f"- duty_frequency_hz: {float(best_reliable['duty_frequency_hz']):.1f}",
        f"- stable_case_fraction: {100.0 * float(best_reliable['stable_case_fraction']):.1f}%",
        f"- duty_to_continuous_endurance_ratio: {float(best_reliable['ratio_duty_to_continuous']):.3f}x",
        f"- duty_to_no_buoyancy_endurance_ratio: {float(best_reliable['ratio_duty_to_no_buoyancy']):.3f}x",
        f"- continuous_to_no_buoyancy_endurance_ratio: {float(best_reliable['ratio_continuous_to_no_buoyancy']):.3f}x",
        "",
        "## Interpretation",
        "This controlled indoor framework compares the same disturbance envelope across controllers and sweeps duty parameters before drawing conclusions.",
        "It supports a methodologically stronger verification of duty-cycled thrust than single-setting comparisons and makes cross-study interpretation with Palossi-style baseline framing explicit.",
    ]
    report_md.write_text("\n".join(lines), encoding="utf-8")

    return sweep_csv, report_md


if __name__ == "__main__":
    csv_path, report_path = run()
    print(f"Saved sweep CSV: {csv_path}")
    print(f"Saved report: {report_path}")
