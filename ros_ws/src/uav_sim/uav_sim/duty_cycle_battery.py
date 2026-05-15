"""Duty-cycle battery analysis utilities.

This module keeps output formatting and plotting separate from the core
calculation so the simulation logic remains easy to unit test.
"""

from __future__ import annotations

import csv
from pathlib import Path
from typing import Iterable, Sequence

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

RESULT_COLUMNS = (
    "buoyancy_assist_ratio",
    "continuous_baseline",
    "buoyancy_reduced_continuous",
    "buoyancy_duty_cycled",
)


def repository_root_from_file() -> Path:
    """Resolve repository root from this file location."""
    return Path(__file__).resolve().parents[4]


def ensure_results_dir(repo_root: Path | None = None) -> Path:
    """Create and return shared duty-cycle results directory."""
    root = repo_root or repository_root_from_file()
    results_dir = root / "results" / "duty_cycle_battery"
    results_dir.mkdir(parents=True, exist_ok=True)
    return results_dir


def _estimate_flight_profiles(
    buoyancy_assist_ratio: float,
    baseline_flight_time_min: float,
) -> dict[str, float]:
    ratio = max(0.0, min(0.95, buoyancy_assist_ratio))
    continuous_baseline = baseline_flight_time_min

    reduced_thrust_fraction = max(1.0 - 0.75 * ratio, 0.10)
    buoyancy_reduced_continuous = baseline_flight_time_min * (1.0 / reduced_thrust_fraction) ** 1.20

    duty_thrust_fraction = max(1.0 - 0.85 * ratio, 0.08)
    duty_cycle = 0.75
    idle_draw_fraction = 0.05
    power_fraction = (
        duty_cycle * duty_thrust_fraction**1.5 + (1.0 - duty_cycle) * idle_draw_fraction
    )
    buoyancy_duty_cycled = baseline_flight_time_min / max(power_fraction, 0.05)

    return {
        "continuous_baseline": continuous_baseline,
        "buoyancy_reduced_continuous": buoyancy_reduced_continuous,
        "buoyancy_duty_cycled": buoyancy_duty_cycled,
    }


def generate_duty_cycle_dataset(
    buoyancy_assist_ratios: Sequence[float] | None = None,
    baseline_flight_time_min: float = 7.0,
) -> list[dict[str, float]]:
    """Generate estimated flight-time rows across buoyancy assist ratios."""
    ratios = buoyancy_assist_ratios or [index / 10.0 for index in range(0, 10)]
    rows: list[dict[str, float]] = []
    for ratio in ratios:
        profiles = _estimate_flight_profiles(ratio, baseline_flight_time_min)
        rows.append(
            {
                "buoyancy_assist_ratio": float(ratio),
                "continuous_baseline": profiles["continuous_baseline"],
                "buoyancy_reduced_continuous": profiles["buoyancy_reduced_continuous"],
                "buoyancy_duty_cycled": profiles["buoyancy_duty_cycled"],
            }
        )
    return rows


def save_results_csv(rows: Iterable[dict[str, float]], output_path: Path) -> Path:
    """Write duty-cycle battery estimates to CSV."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=list(RESULT_COLUMNS))
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    return output_path


def save_results_plot(rows: Sequence[dict[str, float]], output_path: Path) -> Path:
    """Render comparison plot for all duty-cycle scenarios."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    ratios = [row["buoyancy_assist_ratio"] for row in rows]
    continuous_baseline = [row["continuous_baseline"] for row in rows]
    reduced_continuous = [row["buoyancy_reduced_continuous"] for row in rows]
    duty_cycled = [row["buoyancy_duty_cycled"] for row in rows]

    figure, axis = plt.subplots(figsize=(8, 5))
    axis.plot(ratios, continuous_baseline, marker="o", label="continuous_baseline")
    axis.plot(ratios, reduced_continuous, marker="s", label="buoyancy_reduced_continuous")
    axis.plot(ratios, duty_cycled, marker="^", label="buoyancy_duty_cycled")

    axis.set_title("Estimated Flight Time vs Buoyancy Assist Ratio")
    axis.set_xlabel("buoyancy_assist_ratio")
    axis.set_ylabel("estimated_flight_time_min")
    axis.grid(True, alpha=0.35)
    axis.legend()
    figure.tight_layout()
    figure.savefig(output_path, dpi=180)
    plt.close(figure)

    return output_path


def run_duty_cycle_battery_test(
    repo_root: Path | None = None,
    buoyancy_assist_ratios: Sequence[float] | None = None,
    baseline_flight_time_min: float = 7.0,
) -> tuple[Path, Path, list[dict[str, float]]]:
    """Generate CSV and graph output for duty-cycle battery comparison."""
    results_dir = ensure_results_dir(repo_root)
    rows = generate_duty_cycle_dataset(
        buoyancy_assist_ratios=buoyancy_assist_ratios,
        baseline_flight_time_min=baseline_flight_time_min,
    )

    csv_path = save_results_csv(rows, results_dir / "duty_cycle_battery_test.csv")
    plot_path = save_results_plot(rows, results_dir / "duty_cycle_battery_comparison.png")
    return csv_path, plot_path, rows


if __name__ == "__main__":
    csv_output_path, png_file, _ = run_duty_cycle_battery_test()
    print(f"Saved CSV: {csv_output_path}")
    print(f"Saved plot: {png_file}")