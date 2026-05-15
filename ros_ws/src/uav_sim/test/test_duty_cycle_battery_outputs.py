"""Tests for duty-cycle battery analysis output generation."""

from __future__ import annotations

import csv

from uav_sim.duty_cycle_battery import run_duty_cycle_battery_test


def test_duty_cycle_outputs_created_with_required_columns(tmp_path) -> None:
    csv_path, png_path, rows = run_duty_cycle_battery_test(
        repo_root=tmp_path,
        buoyancy_assist_ratios=[0.0, 0.2, 0.4, 0.6],
        baseline_flight_time_min=7.0,
    )

    assert csv_path.exists()
    assert png_path.exists()
    assert png_path.stat().st_size > 0
    assert len(rows) == 4

    with csv_path.open("r", newline="", encoding="utf-8") as csv_file:
        reader = csv.DictReader(csv_file)
        columns = set(reader.fieldnames or [])
        required_columns = {
            "buoyancy_assist_ratio",
            "continuous_baseline",
            "buoyancy_reduced_continuous",
            "buoyancy_duty_cycled",
        }
        assert required_columns.issubset(columns)


def test_results_folder_is_created_automatically(tmp_path) -> None:
    results_root = tmp_path / "results"
    assert not results_root.exists()

    csv_path, png_path, _ = run_duty_cycle_battery_test(
        repo_root=tmp_path,
        buoyancy_assist_ratios=[0.1, 0.3],
    )

    assert (tmp_path / "results" / "duty_cycle_battery").exists()
    assert csv_path.exists()
    assert png_path.exists()