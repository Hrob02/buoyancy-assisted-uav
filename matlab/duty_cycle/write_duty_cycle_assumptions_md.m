function write_duty_cycle_assumptions_md(cfg, battery, summaryTable)
%WRITE_DUTY_CYCLE_ASSUMPTIONS_MD Write model assumptions and limitations markdown.

assumptionsPath = fullfile(cfg.paths.results_dir, 'duty_cycle_assumptions.md');

numFeasible = sum(summaryTable.feasible);
numTotal = height(summaryTable);

lines = {};
lines{end+1} = '# Duty-Cycle Thrust Assumptions and Methodology';
lines{end+1} = '';
lines{end+1} = '## Purpose of the simulation';
lines{end+1} = 'Evaluate whether duty-cycled thrust can reduce average electrical power and improve endurance versus continuous hover for a Crazyflie-scale buoyancy-assisted UAV.';
lines{end+1} = '';
lines{end+1} = '## Summary of the methodology';
lines{end+1} = '- Compare continuous hover and duty-cycled thrust over equal cycle periods.';
lines{end+1} = '- Sweep buoyancy ratio, T_on, T_off, startup energy, and motor-electrical efficiency.';
lines{end+1} = '- Compute cycle energy, average power, endurance, altitude drop, and burst thrust demand.';
lines{end+1} = '- Apply feasibility checks for altitude tolerance, battery power/current, and thrust capability.';
lines{end+1} = sprintf('- Active sweep mode for this run: %s.', cfg.sweep.active_mode_label);
lines{end+1} = '';
lines{end+1} = sprintf('The initial broad buoyancy sweep was useful for identifying that duty-cycled thrust is not feasible when the rotors remain responsible for a large fraction of the vehicle weight. The active %s sweep focuses on the intended design region where the helium envelope supports most of the vehicle weight and the rotors provide intermittent correction rather than primary lift. This better reflects the duty-cycled thrust mechanism demonstrated in buoyancy-dominant systems.', cfg.sweep.active_mode_label);
lines{end+1} = '';
lines{end+1} = '## Evidence-supported parameters';
lines{end+1} = sprintf('- Crazyflie airframe mass: %.3f kg', cfg.vehicle.mass_airframe_kg);
lines{end+1} = sprintf('- Maximum recommended payload: %.3f kg', cfg.vehicle.max_payload_kg);
lines{end+1} = sprintf('- Battery: %.3f Ah, %.1f V nominal, %.1f C', cfg.battery.capacity_Ah, cfg.battery.nominal_voltage_V, cfg.battery.max_discharge_C);
lines{end+1} = sprintf('- Battery mass: %.4f kg', cfg.vehicle.battery_mass_kg);
lines{end+1} = sprintf('- Baseline flight time reference: %.1f minutes', cfg.vehicle.baseline_flight_time_min);
lines{end+1} = sprintf('- Gravity: %.2f m/s^2, air density: %.3f kg/m^3, helium density: %.4f kg/m^3', ...
    cfg.environment.gravity_m_s2, cfg.environment.rho_air_kg_m3, cfg.environment.rho_helium_kg_m3);
lines{end+1} = '';
lines{end+1} = '## Derived parameters';
lines{end+1} = sprintf('- E_bat_Wh = %.3f Wh', battery.E_bat_Wh);
lines{end+1} = sprintf('- E_bat_J = %.1f J', battery.E_bat_J);
lines{end+1} = sprintf('- I_max = %.3f A', battery.I_max_A);
lines{end+1} = sprintf('- P_bat_max = %.3f W', battery.P_bat_max_W);
lines{end+1} = '';
lines{end+1} = '## Equations used';
lines{end+1} = '- W = m_total * g';
lines{end+1} = '- F_b = (rho_air - rho_helium) * V_envelope * g';
lines{end+1} = '- buoyancy_ratio = F_b / W';
lines{end+1} = '- F_required = max(W - F_b, 0)';
lines{end+1} = '- A_total = number_of_rotors * pi * (prop_diameter / 2)^2';
lines{end+1} = '- P_hover_ideal = F_required^(3/2) / sqrt(2 * rho_air * A_total)';
lines{end+1} = '- P_hover_electrical = P_hover_ideal / eta_total';
lines{end+1} = '- P_cont_total = P_cont_propulsion + P_electronics';
lines{end+1} = '- P_duty_total = P_duty_propulsion_avg + P_electronics';
lines{end+1} = '- E_cont_cycle = P_cont_total * (T_on + T_off)';
lines{end+1} = '- E_duty_cycle = (P_on*T_on + P_off*T_off + E_startup) + P_electronics*(T_on + T_off)';
lines{end+1} = '- a_off = (F_b + F_off - W) / m_total';
lines{end+1} = '- drop_off = 0.5 * abs(a_off) * T_off^2';
lines{end+1} = '- a_recovery_required = 2 * drop_off / T_on^2';
lines{end+1} = '- F_on_required = W - F_b + m_total * a_recovery_required';
lines{end+1} = '';
lines{end+1} = '## Power as the primary assessment metric';
lines{end+1} = 'Endurance is calculated directly from usable battery energy and average power. Because of this direct relationship, endurance improvement is not treated as an independent assessment metric in this analysis. The main comparison is total average power reduction between continuous hover and duty-cycled thrust. Derived endurance values are retained in the result tables to show the practical consequence of power reduction.';
lines{end+1} = '';
lines{end+1} = '## Diagnostic buoyancy sweep';
lines{end+1} = 'The previous high-buoyancy sweep found the best feasible duty-cycle case at the lower boundary of the tested range. The diagnostic sweep extends the buoyancy ratio range lower to determine whether the result is a true optimum or an artefact of the selected sweep bounds.';
lines{end+1} = 'The diagnostic sweep uses a coarser buoyancy and timing resolution to reduce runtime while still identifying the overall trend. Finer sweeps can be rerun around the identified optimum region.';
lines{end+1} = '';
lines{end+1} = '## Duty-cycle strength';
lines{end+1} = 'Because some feasible cases may keep the motors on for most of the cycle, the analysis reports on-fraction and off-fraction. Cases with very short off-periods are classified as short-break pulsing rather than strong duty cycling.';
lines{end+1} = '';
lines{end+1} = '## Feasibility validation';
lines{end+1} = 'Feasible cases must pass altitude, battery current, battery power, thrust, voltage, and total power reduction checks. Validation assertions are used to confirm that no case is marked feasible while failing any required criterion.';
lines{end+1} = '';
lines{end+1} = '## Assumptions';
lines{end+1} = '- Duty-cycle off-thrust is set by a configurable off-thrust fraction (default zero).';
lines{end+1} = '- Startup energy is swept with low/medium/high assumed values.';
lines{end+1} = '- Total efficiency is swept using conservative/nominal/optimistic assumed cases.';
lines{end+1} = '- A third-order thrust-vs-voltage polynomial is used as a placeholder fit pending measured thrust-stand data.';
lines{end+1} = '- Usable battery energy applies a reserve fraction (not full nominal energy).';
lines{end+1} = '- Buoyancy ratio BR=1.00 is treated as an idealized neutral-buoyancy reference and excluded from threshold calculations by default.';
lines{end+1} = '';
if numFeasible == 0
    lines{end+1} = '## Interpretation of zero feasible cases';
    lines{end+1} = '- The primary metric is total average power reduction. Endurance improvement is derived from this power reduction and is therefore reported only as a consequence of the power result.';
    lines{end+1} = sprintf('- The %s sweep tested whether the balloon could support most of the weight while rotors take intermittent breaks.', cfg.sweep.active_mode_label);
    lines{end+1} = '- No feasible cases were found under the current assumptions.';
    lines{end+1} = '- This does not necessarily disprove buoyancy-assisted endurance improvement.';
    lines{end+1} = '- It suggests that, with the current open-loop duty-cycle model, continuous low-thrust correction is more efficient than motor-off/motor-on cycling.';
    lines{end+1} = '- The result is sensitive to startup energy, motor thrust-power modelling, electronics power treatment, altitude tolerance, and the absence of closed-loop control.';
    lines{end+1} = '- The result should be interpreted as a boundary-finding simulation, not a final flight validation.';
    lines{end+1} = '';
else
    lines{end+1} = '## Interpretation of feasible cases';
    lines{end+1} = '- The primary metric is total average power reduction. Endurance improvement is derived from this power reduction and is therefore reported only as a consequence of the power result.';
    lines{end+1} = sprintf('- The %s sweep identified a limited number of feasible duty-cycle cases.', cfg.sweep.active_mode_label);
    lines{end+1} = '- Feasible cases were found only over a narrow buoyancy-ratio range.';
    lines{end+1} = '- The best cases produced small power and endurance improvements, around a few percent.';
    lines{end+1} = '- The best timing used short off-periods, suggesting that aggressive long motor-off intervals are not suitable for this Crazyflie-scale model.';
    lines{end+1} = '- At higher buoyancy ratios, continuous low-thrust hover becomes difficult to outperform because the remaining required thrust is already very small.';
    lines{end+1} = '- Therefore, the main endurance benefit is still buoyancy assistance itself, while duty cycling provides only marginal additional benefit under the current assumptions.';
    lines{end+1} = '';
end
lines{end+1} = '## Excluded or negligible variables';
lines{end+1} = '- Yaw/roll/pitch coupling and full attitude dynamics are excluded.';
lines{end+1} = '- Envelope aerodynamic drag is excluded from this vertical model.';
lines{end+1} = '- Motor thermal limits are excluded.';
lines{end+1} = '- Turbulence and indoor airflow transients are excluded.';
lines{end+1} = '';
lines{end+1} = '## Limitations';
lines{end+1} = '- This is a simulation, not a validated flight controller.';
lines{end+1} = '- Results indicate theoretical feasibility only.';
lines{end+1} = '- The model does not yet include closed-loop attitude control.';
lines{end+1} = '- The model does not yet include full battery voltage sag across the discharge curve.';
lines{end+1} = '- The model does not yet include aerodynamic drag from the helium envelope.';
lines{end+1} = '- The model does not yet include turbulence or indoor airflow.';
lines{end+1} = '- The model does not yet include motor thermal limits.';
lines{end+1} = '- The model does not yet include experimentally measured Crazyflie thrust curves unless such data is later added.';
lines{end+1} = '- The model assumes vertical motion only.';
lines{end+1} = '- The model assumes helium envelope lift is approximately constant over the simulated period.';
lines{end+1} = '- Placeholder values are explicitly labeled as assumptions.';
lines{end+1} = '';
lines{end+1} = '## Recommended next validation steps';
lines{end+1} = '- Measure Crazyflie thrust-vs-voltage and update polynomial coefficients with test-stand data.';
lines{end+1} = '- Validate altitude-drop predictions against indoor tethered tests.';
lines{end+1} = '- Incorporate measured battery sag and internal resistance model.';
lines{end+1} = '- Add closed-loop vertical and attitude control coupling.';
lines{end+1} = sprintf('- Current run feasibility summary: %d feasible cases out of %d total cases.', numFeasible, numTotal);
lines{end+1} = '- Primary interpretation target: determine the minimum buoyancy ratio at which duty-cycled thrust becomes feasible, not only whether any duty-cycled case works.';

if numFeasible > 0
    feasibleRows = summaryTable(summaryTable.feasible, :);
    rankedBest = sortrows(feasibleRows, {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, {'descend', 'ascend', 'ascend', 'ascend'});
    bestCase = rankedBest(1, :);
    thresholdSource = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
    minBR = min(thresholdSource.buoyancy_ratio);
    maxBR = max(thresholdSource.buoyancy_ratio);
    isInteriorOptimum = (bestCase.buoyancy_ratio > minBR + 1e-12) && (bestCase.buoyancy_ratio < maxBR - 1e-12);
    if cfg.sweep.active_mode_label == "diagnostic_buoyancy" && isInteriorOptimum
        lines{end+1} = sprintf('- Suggested refinement sweep: BR %.3f to %.3f with step 0.005 around the identified optimum.', ...
            max(bestCase.buoyancy_ratio - 0.05, 0.0), min(bestCase.buoyancy_ratio + 0.05, 0.995));
    end
end

if numFeasible == 0
    lines{end+1} = '- No feasible-case dependent plots were replaced with explicit placeholders or closest-case summaries.';
end

fileText = strjoin(lines, newline);
fid = fopen(assumptionsPath, 'w');
if fid < 0
    error('Unable to write assumptions file: %s', assumptionsPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', fileText);

end
