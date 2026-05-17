# Duty-Cycle Experiment Summary

This summary reports the longest-endurance stable controller for each disturbance profile.
Disturbance force ratio in this dataset: 0.008 to 0.008 of vehicle weight (indoor-target runs should remain in the low-disturbance range).
Note: each trial runs until depletion, so battery used is near 100% by design; endurance and stability determine the ranking.

## Gust Disturbance
Best stable controller: **buoyancy_assisted_continuous** at 2.0 Hz.
Endurance (time to empty): 5190.3 s, RMS altitude error: 0.0000 m, max error: 0.0005 m, battery used: 100.00%.

## Sine Disturbance
Best stable controller: **buoyancy_assisted_continuous** at 2.0 Hz.
Endurance (time to empty): 5190.3 s, RMS altitude error: 0.0004 m, max error: 0.0039 m, battery used: 100.00%.

## Step Disturbance (Stress-Test / Outdoor-Like)
No controller satisfied the stability thresholds under this stress-test disturbance.

## Interpretation
These results do not reject duty cycling in general. They indicate that under the current gains, duty parameters, and strict stability thresholds, continuous buoyancy-assisted control is the most robust in this dataset.
This remains consistent with prior blimp literature: duty cycling can reduce average power in benign indoor conditions, while stronger disturbances require retuning or continuous support to preserve stability margins.

## Cross-Study Framing
Compared against the no-buoyancy baseline (the framing commonly used in prior blimp studies), duty-cycled buoyancy-assisted control still shows a large endurance gain.
Mean endurance ratio (duty vs no-buoyancy baseline, sine+gust): 12.25x.
Mean endurance ratio (continuous buoyancy-assisted vs no-buoyancy baseline, sine+gust): 12.36x.