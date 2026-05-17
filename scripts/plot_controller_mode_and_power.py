"""
Plot controller mode and power draw from the vertical control experiment timeseries.
"""
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# Path to the large timeseries CSV
timeseries_path = Path("results/duty_cycle_battery/vertical_control_timeseries.csv")

# Read only a subset of the data for a single controller, profile, and frequency
# (to avoid memory issues with the full file)
def load_filtered_timeseries(controller, profile, freq, nrows=10000):
    df = pd.read_csv(timeseries_path, nrows=nrows)  # Read a chunk for preview
    mask = (
        (df["controller"] == controller)
        & (df["disturbance_profile"] == profile)
        & (df["disturbance_frequency_hz"] == freq)
    )
    return df[mask]

# Example: plot for hybrid controller, sine, 2.0 Hz
df = load_filtered_timeseries(
    controller="buoyancy_assisted_hybrid",
    profile="sine",
    freq=2.0,
    nrows=50000,  # Increase if needed, but keep manageable
)

fig, ax1 = plt.subplots(figsize=(10, 5))

# Plot altitude error
ax1.plot(df["time_s"] / 60, df["altitude_m"], label="Altitude Error (m)", color="tab:blue")
ax1.set_xlabel("Time (min)")
ax1.set_ylabel("Altitude Error (m)", color="tab:blue")
ax1.tick_params(axis="y", labelcolor="tab:blue")

# Plot controller mode as a background color
for i in range(1, len(df)):
    if df["controller_mode"].iloc[i] != df["controller_mode"].iloc[i-1]:
        plt.axvline(df["time_s"].iloc[i] / 60, color="gray", linestyle=":", alpha=0.3)

# Plot power draw on a second axis
ax2 = ax1.twinx()
ax2.plot(df["time_s"] / 60, df["instant_power_fraction"], label="Power Fraction", color="tab:red", alpha=0.6)
ax2.set_ylabel("Instantaneous Power Fraction", color="tab:red")
ax2.tick_params(axis="y", labelcolor="tab:red")

fig.suptitle("Hybrid Controller: Altitude Error, Power Draw, and Mode Switching (Sine 2.0 Hz)")
fig.tight_layout()
plt.show()
