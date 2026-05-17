function [parameterTable, feasibilityTable, bestCasesTable, failedCasesTable] = generate_duty_cycle_tables(cfg, battery, continuousTable, summaryTable)
%GENERATE_DUTY_CYCLE_TABLES Build and save all duty-cycle CSV tables.

if ~isfield(cfg.sweep, 'include_ideal_reference_in_threshold')
    cfg.sweep.include_ideal_reference_in_threshold = false;
end

rows = {
    'sweep_mode', string(cfg.sweep.active_mode_label), '-', 'Active buoyancy sweep mode', 'configuration', 'analysis_setting';
    'include_ideal_neutral_reference', double(cfg.sweep.include_ideal_neutral_reference), '-', 'Whether BR=1.00 idealized reference is included', 'configuration', 'analysis_setting';
    'include_ideal_reference_in_threshold', double(cfg.sweep.include_ideal_reference_in_threshold), '-', 'Whether BR=1.00 is included in threshold calculations', 'configuration', 'analysis_setting';
    'mass_airframe_kg', cfg.vehicle.mass_airframe_kg, 'kg', 'Crazyflie 2.1+ airframe mass', 'evidence', 'platform_spec';
    'max_payload_kg', cfg.vehicle.max_payload_kg, 'kg', 'Maximum recommended payload', 'evidence', 'platform_spec';
    'battery_mass_kg', cfg.vehicle.battery_mass_kg, 'kg', 'Battery mass', 'evidence', 'battery_spec';
    'battery_capacity_Ah', cfg.battery.capacity_Ah, 'Ah', 'Battery capacity', 'evidence', 'battery_spec';
    'battery_nominal_voltage_V', cfg.battery.nominal_voltage_V, 'V', 'Nominal battery voltage', 'evidence', 'battery_spec';
    'battery_C_rating', cfg.battery.max_discharge_C, 'C', 'Battery max discharge rating', 'evidence', 'battery_spec';
    'E_bat_Wh', battery.E_bat_Wh, 'Wh', 'Battery nominal energy', 'derived', 'equation';
    'E_bat_J', battery.E_bat_J, 'J', 'Battery nominal energy', 'derived', 'equation';
    'I_max_A', battery.I_max_A, 'A', 'Battery max current', 'derived', 'equation';
    'P_bat_max_W', battery.P_bat_max_W, 'W', 'Battery max electrical power', 'derived', 'equation';
    'E_usable_J', battery.E_usable_J, 'J', 'Usable battery energy after reserve factor', 'assumption', 'modelling_choice';
    'rho_air_kg_m3', cfg.environment.rho_air_kg_m3, 'kg/m^3', 'Air density', 'evidence', 'standard_condition';
    'rho_helium_kg_m3', cfg.environment.rho_helium_kg_m3, 'kg/m^3', 'Helium density', 'evidence', 'standard_condition';
    'gravity_m_s2', cfg.environment.gravity_m_s2, 'm/s^2', 'Gravity acceleration', 'evidence', 'physical_constant';
    'prop_diameter_m', cfg.rotor.prop_diameter_m, 'm', 'Propeller diameter', 'evidence', 'platform_spec';
    'number_of_rotors', cfg.rotor.number_of_rotors, '-', 'Number of rotors', 'evidence', 'platform_spec';
    'altitude_tolerance_m', cfg.sim.altitude_tolerance_m, 'm', 'Altitude drop feasibility threshold', 'assumption', 'modelling_choice';
    'electronics_idle_power_W', cfg.sim.electronics_idle_power_W, 'W', 'Electronics power draw used in both continuous and duty-cycle modes', 'assumption', 'modelling_choice';
    'off_thrust_fraction', cfg.sim.off_thrust_fraction, '-', 'Fraction of required hover thrust during off-window', 'assumption', 'modelling_choice';
    'thrust_poly_coeff_a3', cfg.motor.thrust_poly_per_rotor_N_vs_V(1), 'N/V^3', 'Per-rotor thrust polynomial coefficient', 'assumption', 'placeholder_fit';
    'thrust_poly_coeff_a2', cfg.motor.thrust_poly_per_rotor_N_vs_V(2), 'N/V^2', 'Per-rotor thrust polynomial coefficient', 'assumption', 'placeholder_fit';
    'thrust_poly_coeff_a1', cfg.motor.thrust_poly_per_rotor_N_vs_V(3), 'N/V', 'Per-rotor thrust polynomial coefficient', 'assumption', 'placeholder_fit';
    'thrust_poly_coeff_a0', cfg.motor.thrust_poly_per_rotor_N_vs_V(4), 'N', 'Per-rotor thrust polynomial coefficient', 'assumption', 'placeholder_fit';
    'diagnostic_buoyancy_min', min(cfg.sweep.diagnostic_buoyancy_ratio), '-', 'Diagnostic sweep minimum buoyancy ratio', 'configuration', 'analysis_setting';
    'diagnostic_buoyancy_max', max(cfg.sweep.diagnostic_buoyancy_ratio), '-', 'Diagnostic sweep maximum buoyancy ratio', 'configuration', 'analysis_setting';
    'high_buoyancy_buoyancy_min', min(cfg.sweep.high_buoyancy_ratio), '-', 'High-buoyancy sweep minimum buoyancy ratio', 'configuration', 'analysis_setting';
    'high_buoyancy_buoyancy_max', max(cfg.sweep.high_buoyancy_ratio), '-', 'High-buoyancy sweep maximum buoyancy ratio', 'configuration', 'analysis_setting';
    'near_neutral_buoyancy_min', min(cfg.sweep.near_neutral_buoyancy_ratio), '-', 'Near-neutral sweep minimum buoyancy ratio', 'configuration', 'analysis_setting';
    'near_neutral_buoyancy_max', max(cfg.sweep.near_neutral_buoyancy_ratio), '-', 'Near-neutral sweep maximum buoyancy ratio', 'configuration', 'analysis_setting';
    'broad_buoyancy_min', min(cfg.sweep.broad_buoyancy_ratio), '-', 'Broad sweep minimum buoyancy ratio', 'configuration', 'analysis_setting';
    'broad_buoyancy_max', max(cfg.sweep.broad_buoyancy_ratio), '-', 'Broad sweep maximum buoyancy ratio', 'configuration', 'analysis_setting';
    'minimum_off_fraction_for_primary_results', cfg.minimum_off_fraction_for_primary_results, '-', 'Minimum off-fraction applied to primary best-case ranking', 'configuration', 'analysis_setting';
};

parameterTable = cell2table(rows, 'VariableNames', ...
    {'variable_name', 'value', 'unit', 'description', 'evidence_or_assumption', 'reference_type'});

feasibilityTable = summaryTable(:, {'case_id', 'sweep_mode', 'buoyancy_ratio', 'is_idealized_neutral_reference', ...
    'T_on_s', 'T_off_s', 'on_fraction', 'off_fraction', 'duty_cycle_type', ...
    'altitude_drop_m', 'altitude_tolerance_m', 'altitude_margin_m', ...
    'altitude_pass', 'battery_power_pass', 'battery_current_pass', 'thrust_pass', 'voltage_pass', ...
    'power_reduction_pass', 'physical_constraints_pass', 'feasible', ...
    'infeasible_average_power', 'infeasible_altitude_tolerance', 'infeasible_battery_limit', 'infeasible_thrust_capability', ...
    'failed_check_count', 'failed_checks_list', 'primary_failure_reason', 'failure_reason'});

bestCasesTable = summaryTable(summaryTable.feasible & (summaryTable.off_fraction >= cfg.minimum_off_fraction_for_primary_results), :);
if ~isempty(bestCasesTable)
    bestCasesTable = sortrows(bestCasesTable, ...
    {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
    {'descend', 'ascend', 'ascend', 'ascend'});
end

filteredOff25Table = summaryTable(summaryTable.feasible & (summaryTable.off_fraction >= 0.25), :);
if ~isempty(filteredOff25Table)
    filteredOff25Table = sortrows(filteredOff25Table, ...
        {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
        {'descend', 'ascend', 'ascend', 'ascend'});
end

failedCasesTable = summaryTable(~summaryTable.feasible, :);

closestCasesTable = build_closest_cases(summaryTable);

writetable(parameterTable, fullfile(cfg.paths.results_dir, 'duty_cycle_parameter_table.csv'));
writetable(summaryTable, fullfile(cfg.paths.results_dir, 'duty_cycle_summary_table.csv'));
writetable(feasibilityTable, fullfile(cfg.paths.results_dir, 'duty_cycle_feasibility_table.csv'));
writetable(bestCasesTable, fullfile(cfg.paths.results_dir, 'duty_cycle_best_cases.csv'));
writetable(filteredOff25Table, fullfile(cfg.paths.results_dir, 'duty_cycle_feasible_cases_min_off_fraction_25.csv'));
writetable(failedCasesTable, fullfile(cfg.paths.results_dir, 'duty_cycle_failed_cases.csv'));
writetable(closestCasesTable, fullfile(cfg.paths.results_dir, 'duty_cycle_closest_cases.csv'));

feasibilityByBuoyancy = build_feasibility_by_buoyancy_ratio(summaryTable);
writetable(feasibilityByBuoyancy, fullfile(cfg.paths.results_dir, 'feasibility_by_buoyancy_ratio.csv'));

thresholdTable = build_buoyancy_threshold_table(summaryTable, cfg.sweep.include_ideal_reference_in_threshold);
writetable(thresholdTable, fullfile(cfg.paths.results_dir, 'buoyancy_feasibility_threshold.csv'));

optimumSummaryTable = build_optimum_summary_table(summaryTable);
writetable(optimumSummaryTable, fullfile(cfg.paths.results_dir, 'duty_cycle_optimum_summary.csv'));

% Keep an additional baseline table for plotting traceability.
writetable(continuousTable, fullfile(cfg.paths.results_dir, 'continuous_hover_baseline_cases.csv'));

end

function closestCasesTable = build_closest_cases(summaryTable)
closestCasesTable = summaryTable;
closestCasesTable.total_power_penalty_W = closestCasesTable.P_duty_total_W - closestCasesTable.P_cont_total_W;
closestCasesTable = sortrows(closestCasesTable, ...
    {'failed_check_count', 'total_power_penalty_W', 'altitude_drop_m', 'P_on_required_W'}, ...
    {'ascend', 'ascend', 'ascend', 'ascend'});

topN = min(10, height(closestCasesTable));
closestCasesTable = closestCasesTable(1:topN, {'buoyancy_ratio', 'T_on_s', 'T_off_s', 'on_fraction', 'off_fraction', 'duty_cycle_type', ...
    'startup_energy_J', 'eta_case', ...
    'P_cont_total_W', 'P_duty_total_W', 'total_power_reduction_percent', 'derived_endurance_improvement_percent', ...
    'altitude_drop_m', 'altitude_tolerance_m', 'altitude_margin_m', ...
    'F_on_required_N', 'P_on_required_W', 'I_on_required_A', 'failed_check_count', 'failed_checks_list', 'failure_reason'});
end

function feasibilityByBuoyancy = build_feasibility_by_buoyancy_ratio(summaryTable)
uniqueBuoyancy = unique(summaryTable.buoyancy_ratio);
numRows = numel(uniqueBuoyancy);
sweep_mode = repmat(summaryTable.sweep_mode(1), numRows, 1);

buoyancy_ratio = zeros(numRows, 1);
total_cases = zeros(numRows, 1);
feasible_cases = zeros(numRows, 1);
feasible_percent = zeros(numRows, 1);
best_power_reduction_percent = nan(numRows, 1);
best_derived_endurance_improvement_percent = nan(numRows, 1);
lowest_altitude_drop_m = nan(numRows, 1);
lowest_required_burst_power_W = nan(numRows, 1);
best_T_on_s = nan(numRows, 1);
best_T_off_s = nan(numRows, 1);

for i = 1:numRows
    rows = summaryTable(summaryTable.buoyancy_ratio == uniqueBuoyancy(i), :);
    buoyancy_ratio(i) = uniqueBuoyancy(i);
    total_cases(i) = height(rows);
    feasible_cases(i) = sum(rows.feasible);
    feasible_percent(i) = 100.0 * feasible_cases(i) / max(total_cases(i), 1);

    feasibleRows = rows(rows.feasible, :);
    if ~isempty(feasibleRows)
        [bestPowerReduction, idxPower] = max(feasibleRows.total_power_reduction_percent);
        [bestDerivedEnduranceImprovement, ~] = max(feasibleRows.derived_endurance_improvement_percent);
        [lowestAltitudeDrop, ~] = min(feasibleRows.altitude_drop_m);
        [lowestBurstPower, ~] = min(feasibleRows.P_on_required_W);

        best_power_reduction_percent(i) = bestPowerReduction;
        best_derived_endurance_improvement_percent(i) = bestDerivedEnduranceImprovement;
        lowest_altitude_drop_m(i) = lowestAltitudeDrop;
        lowest_required_burst_power_W(i) = lowestBurstPower;

        best_T_on_s(i) = feasibleRows.T_on_s(idxPower);
        best_T_off_s(i) = feasibleRows.T_off_s(idxPower);
    end
end

feasibilityByBuoyancy = table( ...
    sweep_mode, buoyancy_ratio, total_cases, feasible_cases, feasible_percent, ...
    best_power_reduction_percent, best_derived_endurance_improvement_percent, ...
    lowest_altitude_drop_m, lowest_required_burst_power_W, best_T_on_s, best_T_off_s);
end

function thresholdTable = build_buoyancy_threshold_table(summaryTable, includeIdealReference)
thresholdSource = summaryTable;
if ~includeIdealReference
    thresholdSource = thresholdSource(~thresholdSource.is_idealized_neutral_reference, :);
end

if isempty(thresholdSource)
    thresholdTable = table( ...
        summaryTable.sweep_mode(1), false, nan, nan, nan, nan, nan, nan, nan, nan, nan, ...
        'VariableNames', {'sweep_mode', 'included_idealized_reference_in_threshold', ...
        'lowest_buoyancy_with_feasible_case', 'feasible_buoyancy_min', 'feasible_buoyancy_max', ...
        'min_buoyancy_for_positive_derived_endurance_improvement', 'min_buoyancy_for_positive_power_reduction', ...
        'buoyancy_ratio', 'best_T_on_s', 'best_T_off_s', 'best_derived_endurance_improvement_percent', 'best_power_reduction_percent'});
    return;
end

feasibleMask = thresholdSource.feasible;
if any(feasibleMask)
    feasibleBuoyancyAll = thresholdSource.buoyancy_ratio(feasibleMask);
    lowestFeasibleBuoyancy = min(feasibleBuoyancyAll);
    feasibleRangeMin = min(feasibleBuoyancyAll);
    feasibleRangeMax = max(feasibleBuoyancyAll);
else
    lowestFeasibleBuoyancy = nan;
    feasibleRangeMin = nan;
    feasibleRangeMax = nan;
end

improveMask = thresholdSource.feasible & (thresholdSource.derived_endurance_improvement_percent > 0);
if any(improveMask)
    minBuoyancyForPositiveEndurance = min(thresholdSource.buoyancy_ratio(improveMask));
else
    minBuoyancyForPositiveEndurance = nan;
end

powerMask = thresholdSource.feasible & (thresholdSource.total_power_reduction_percent > 0);
if any(powerMask)
    minBuoyancyForPositivePower = min(thresholdSource.buoyancy_ratio(powerMask));
else
    minBuoyancyForPositivePower = nan;
end

feasibleRows = thresholdSource(thresholdSource.feasible, :);
if isempty(feasibleRows)
    thresholdTable = table( ...
        thresholdSource.sweep_mode(1), includeIdealReference, lowestFeasibleBuoyancy, feasibleRangeMin, feasibleRangeMax, ...
        minBuoyancyForPositiveEndurance, minBuoyancyForPositivePower, nan, nan, nan, nan, nan, ...
        'VariableNames', {'sweep_mode', 'included_idealized_reference_in_threshold', ...
        'lowest_buoyancy_with_feasible_case', 'feasible_buoyancy_min', 'feasible_buoyancy_max', ...
        'min_buoyancy_for_positive_derived_endurance_improvement', 'min_buoyancy_for_positive_power_reduction', ...
        'buoyancy_ratio', 'best_T_on_s', 'best_T_off_s', 'best_derived_endurance_improvement_percent', 'best_power_reduction_percent'});
    return;
end

feasibleBuoyancy = unique(feasibleRows.buoyancy_ratio);
numRows = numel(feasibleBuoyancy);

sweep_mode = repmat(thresholdSource.sweep_mode(1), numRows, 1);
included_idealized_reference_in_threshold = repmat(includeIdealReference, numRows, 1);
lowest_buoyancy_with_feasible_case = repmat(lowestFeasibleBuoyancy, numRows, 1);
feasible_buoyancy_min = repmat(feasibleRangeMin, numRows, 1);
feasible_buoyancy_max = repmat(feasibleRangeMax, numRows, 1);
min_buoyancy_for_positive_derived_endurance_improvement = repmat(minBuoyancyForPositiveEndurance, numRows, 1);
min_buoyancy_for_positive_power_reduction = repmat(minBuoyancyForPositivePower, numRows, 1);

buoyancy_ratio = feasibleBuoyancy;
best_T_on_s = nan(numRows, 1);
best_T_off_s = nan(numRows, 1);
best_derived_endurance_improvement_percent = nan(numRows, 1);
best_power_reduction_percent = nan(numRows, 1);

for i = 1:numRows
    rows = feasibleRows(feasibleRows.buoyancy_ratio == feasibleBuoyancy(i), :);
    [bestReduction, idx] = max(rows.total_power_reduction_percent);
    best_T_on_s(i) = rows.T_on_s(idx);
    best_T_off_s(i) = rows.T_off_s(idx);
    best_derived_endurance_improvement_percent(i) = rows.derived_endurance_improvement_percent(idx);
    best_power_reduction_percent(i) = bestReduction;
end

thresholdTable = table( ...
    sweep_mode, included_idealized_reference_in_threshold, ...
    lowest_buoyancy_with_feasible_case, feasible_buoyancy_min, feasible_buoyancy_max, ...
    min_buoyancy_for_positive_derived_endurance_improvement, min_buoyancy_for_positive_power_reduction, ...
    buoyancy_ratio, best_T_on_s, best_T_off_s, best_derived_endurance_improvement_percent, best_power_reduction_percent);
end

function optimumSummaryTable = build_optimum_summary_table(summaryTable)
thresholdSource = summaryTable(~summaryTable.is_idealized_neutral_reference, :);

sweep_mode = string(summaryTable.sweep_mode(1));
buoyancy_ratio_min_tested = min(thresholdSource.buoyancy_ratio);
buoyancy_ratio_max_tested = max(thresholdSource.buoyancy_ratio);
feasible_case_count = sum(thresholdSource.feasible);
feasible_percent = 100.0 * feasible_case_count / max(height(thresholdSource), 1);

if feasible_case_count > 0
    feasibleRows = thresholdSource(thresholdSource.feasible, :);
    rankedBest = sortrows(feasibleRows, ...
        {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
        {'descend', 'ascend', 'ascend', 'ascend'});
    bestCase = rankedBest(1, :);

    best_buoyancy_ratio = bestCase.buoyancy_ratio;
    best_T_on_s = bestCase.T_on_s;
    best_T_off_s = bestCase.T_off_s;
    best_total_power_reduction_percent = bestCase.total_power_reduction_percent;
    derived_endurance_improvement_percent = bestCase.derived_endurance_improvement_percent;
    on_fraction = bestCase.on_fraction;
    off_fraction = bestCase.off_fraction;
    duty_cycle_type = bestCase.duty_cycle_type;
    altitude_drop_m = bestCase.altitude_drop_m;
    altitude_tolerance_m = bestCase.altitude_tolerance_m;
    altitude_margin_m = bestCase.altitude_margin_m;

    best_case_at_lower_boundary = abs(best_buoyancy_ratio - buoyancy_ratio_min_tested) < 1e-12;
    best_case_at_upper_boundary = abs(best_buoyancy_ratio - buoyancy_ratio_max_tested) < 1e-12;
    optimum_captured_within_sweep = ~(best_case_at_lower_boundary || best_case_at_upper_boundary);

    feasibleOff25Rows = feasibleRows(feasibleRows.off_fraction >= 0.25, :);
    best_case_with_off_fraction_25_exists = ~isempty(feasibleOff25Rows);
    if best_case_with_off_fraction_25_exists
        rankedOff25 = sortrows(feasibleOff25Rows, ...
            {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
            {'descend', 'ascend', 'ascend', 'ascend'});
        best_case_with_off_fraction_25_power_reduction_percent = rankedOff25.total_power_reduction_percent(1);
    else
        best_case_with_off_fraction_25_power_reduction_percent = nan;
    end

    if sweep_mode == "diagnostic_buoyancy" && optimum_captured_within_sweep
        recommended_refinement_BR_min = max(best_buoyancy_ratio - 0.05, 0.0);
        recommended_refinement_BR_max = min(best_buoyancy_ratio + 0.05, 0.995);
        recommended_refinement_BR_step = 0.005;
    else
        recommended_refinement_BR_min = nan;
        recommended_refinement_BR_max = nan;
        recommended_refinement_BR_step = nan;
    end

    if best_case_at_lower_boundary
        interpretation_note = "Boundary note: Best case occurs at the lower boundary. The tested range may still be truncating the optimum.";
    elseif best_case_at_upper_boundary
        interpretation_note = "Boundary note: Best case occurs at the upper boundary. A higher-buoyancy sweep may be needed.";
    else
        interpretation_note = "Boundary note: Best case occurs inside the tested range. The sweep appears to capture a local optimum.";
    end
else
    best_buoyancy_ratio = nan;
    best_T_on_s = nan;
    best_T_off_s = nan;
    best_total_power_reduction_percent = nan;
    derived_endurance_improvement_percent = nan;
    on_fraction = nan;
    off_fraction = nan;
    duty_cycle_type = "";
    altitude_drop_m = nan;
    altitude_tolerance_m = nan;
    altitude_margin_m = nan;

    best_case_at_lower_boundary = false;
    best_case_at_upper_boundary = false;
    optimum_captured_within_sweep = false;
    best_case_with_off_fraction_25_exists = false;
    best_case_with_off_fraction_25_power_reduction_percent = nan;
    recommended_refinement_BR_min = nan;
    recommended_refinement_BR_max = nan;
    recommended_refinement_BR_step = nan;
    interpretation_note = "Boundary note: No feasible duty-cycle case was found within the tested buoyancy range.";
end

optimumSummaryTable = table( ...
    sweep_mode, buoyancy_ratio_min_tested, buoyancy_ratio_max_tested, ...
    best_buoyancy_ratio, best_T_on_s, best_T_off_s, ...
    on_fraction, off_fraction, duty_cycle_type, ...
    best_total_power_reduction_percent, derived_endurance_improvement_percent, ...
    altitude_drop_m, altitude_tolerance_m, altitude_margin_m, ...
    feasible_case_count, feasible_percent, ...
    best_case_at_lower_boundary, best_case_at_upper_boundary, optimum_captured_within_sweep, ...
    best_case_with_off_fraction_25_exists, best_case_with_off_fraction_25_power_reduction_percent, ...
    recommended_refinement_BR_min, recommended_refinement_BR_max, recommended_refinement_BR_step, ...
    interpretation_note);
end
