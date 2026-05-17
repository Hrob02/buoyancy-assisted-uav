"""Tests for the 1D vertical duty-cycle experiment."""

from __future__ import annotations

import csv
import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def _module():
    return importlib.import_module("uav_sim.duty_cycle_battery")


def _summary_row(rows, controller: str, disturbance_frequency_hz: float):
    for row in rows:
        if row["controller"] == controller and abs(row["disturbance_frequency_hz"] - disturbance_frequency_hz) < 1e-9:
            return row
    raise AssertionError(f"Missing summary row for {controller} at {disturbance_frequency_hz} Hz")


def test_vertical_experiment_outputs_and_metrics(tmp_path) -> None:
    mod = _module()
    config = mod.ExperimentConfig(
        baseline_hover_time_min=1.0,
        max_duration_s=120.0,
        output_sample_period_s=0.5,
        disturbance_force_fraction_of_weight=0.008,
    )
    summary_csv_path, timeseries_csv_path, plot_path, summary_rows = mod.run_vertical_control_experiment(
        repo_root=tmp_path,
        disturbance_frequencies_hz=[0.5, 2.0],
        disturbance_profiles=["sine"],
        config=config,
        plot_disturbance_frequencies_hz=[0.5, 2.0],
        reference_profile="sine",
        reference_frequency_hz=2.0,
    )

    assert summary_csv_path.exists()
    assert timeseries_csv_path.exists()
    assert plot_path.exists()
    assert plot_path.stat().st_size > 0
    assert len(summary_rows) == 8

    no_buoyancy = _summary_row(summary_rows, mod.NO_BUOYANCY_CONTINUOUS, 2.0)
    assisted_continuous = _summary_row(summary_rows, mod.BUOYANCY_ASSISTED_CONTINUOUS, 2.0)
    assisted_duty = _summary_row(summary_rows, mod.BUOYANCY_ASSISTED_DUTY, 2.0)

    assert assisted_continuous["battery_used_pct"] < no_buoyancy["battery_used_pct"]
    assert assisted_duty["rms_altitude_error_m"] >= assisted_continuous["rms_altitude_error_m"]
    assert assisted_duty["battery_used_pct"] <= no_buoyancy["battery_used_pct"]

    with summary_csv_path.open("r", newline="", encoding="utf-8") as csv_file:
        reader = csv.DictReader(csv_file)
        columns = set(reader.fieldnames or [])
        required_columns = {
            "controller",
            "disturbance_frequency_hz",
            "battery_used_pct",
            "rms_altitude_error_m",
            "max_altitude_error_m",
            "stable_within_thresholds",
        }
        assert required_columns.issubset(columns)


def test_results_folder_and_timeseries_are_created(tmp_path) -> None:
    mod = _module()
    config = mod.ExperimentConfig(baseline_hover_time_min=1.0, max_duration_s=60.0)
    summary_csv_path, timeseries_csv_path, plot_path, _ = mod.run_vertical_control_experiment(
        repo_root=tmp_path,
        disturbance_frequencies_hz=[1.0],
        disturbance_profiles=["sine", "step", "gust"],
        config=config,
        reference_profile="sine",
    )

    assert (tmp_path / "results" / "duty_cycle_battery").exists()
    assert summary_csv_path.exists()
    assert timeseries_csv_path.exists()
    assert plot_path.exists()

    with timeseries_csv_path.open("r", newline="", encoding="utf-8") as csv_file:
        reader = csv.DictReader(csv_file)
        first_row = next(reader)
        assert first_row["controller"]
        assert "battery_pct" in first_row