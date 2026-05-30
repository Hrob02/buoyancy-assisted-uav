function [parameterTable, feasibilityTable, bestCasesTable, failedCasesTable, validBRRangesTable, mainResultsTable] = generate_duty_cycle_tables(cfg, battery, continuousTable, summaryTable)
%GENERATE_DUTY_CYCLE_TABLES Build and save duty-cycle CSV tables.

if ~isfield(cfg.sweep, 'include_ideal_reference_in_threshold')
    cfg.sweep.include_ideal_reference_in_threshold = false;
end
if ~isfield(cfg, 'output')
    cfg.output.write_debug_tables = false;
end
if ~isfield(cfg.output, 'write_debug_tables')
    cfg.output.write_debug_tables = false;
end

rows = {
    'sweep_mode', string(cfg.sweep.active_mode_label), '-', 'Active buoyancy sweep mode', 'configuration', 'analysis_setting';
    'include_ideal_neutral_reference', double(cfg.sweep.include_ideal_neutral_reference), '-', 'Whether BR=1.00 idealized reference is included', 'configuration', 'analysis_setting';
    'include_ideal_reference_in_threshold', double(cfg.sweep.include_ideal_reference_in_threshold), '-', 'Whether BR=1.00 is included in threshold calculations', 'configuration', 'analysis_setting';
    'configured_buoyancy_min', min(cfg.sweep.buoyancy_ratio), '-', 'Configured sweep minimum buoyancy ratio', 'configuration', 'analysis_setting';
    'configured_buoyancy_max', max(cfg.sweep.buoyancy_ratio), '-', 'Configured sweep maximum buoyancy ratio', 'configuration', 'analysis_setting';
    'configured_T_on_min_s', min(cfg.sweep.T_on_s), 's', 'Configured sweep minimum T_on', 'configuration', 'analysis_setting';
    'configured_T_on_max_s', max(cfg.sweep.T_on_s), 's', 'Configured sweep maximum T_on', 'configuration', 'analysis_setting';
    'configured_T_off_min_s', min(cfg.sweep.T_off_s), 's', 'Configured sweep minimum T_off', 'configuration', 'analysis_setting';
    'configured_T_off_max_s', max(cfg.sweep.T_off_s), 's', 'Configured sweep maximum T_off', 'configuration', 'analysis_setting';
    'short_break_min_off_fraction', cfg.thresholds.short_break_min_off_fraction, '-', 'Short-break minimum off fraction', 'configuration', 'analysis_setting';
    'moderate_min_off_fraction', cfg.thresholds.moderate_min_off_fraction, '-', 'Moderate-duty minimum off fraction', 'configuration', 'analysis_setting';
    'strong_min_off_fraction', cfg.thresholds.strong_min_off_fraction, '-', 'Strong-duty minimum off fraction', 'configuration', 'analysis_setting';
    'short_break_min_T_off_s', cfg.thresholds.short_break_min_T_off_s, 's', 'Short-break minimum T_off', 'configuration', 'analysis_setting';
    'moderate_min_T_off_s', cfg.thresholds.moderate_min_T_off_s, 's', 'Moderate-duty minimum T_off', 'configuration', 'analysis_setting';
    'strong_min_T_off_s', cfg.thresholds.strong_min_T_off_s, 's', 'Strong-duty minimum T_off', 'configuration', 'analysis_setting';
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
    'minimum_off_fraction_for_primary_results', cfg.minimum_off_fraction_for_primary_results, '-', 'Minimum off-fraction applied to ranking', 'configuration', 'analysis_setting';
};

parameterTable = cell2table(rows, 'VariableNames', ...
    {'variable_name', 'value', 'unit', 'description', 'evidence_or_assumption', 'reference_type'});

feasibilityTable = summaryTable(:, {'case_id', 'sweep_mode', 'buoyancy_ratio', 'is_idealized_neutral_reference', ...
    'T_on_s', 'T_off_s', 'on_fraction', 'off_fraction', 'duty_cycle_type', ...
    'passes_short_break_definition', 'passes_moderate_duty_definition', 'passes_strong_duty_definition', ...
    'feasible_short_break', 'feasible_moderate_duty', 'feasible_strong_duty', ...
    'altitude_drop_m', 'altitude_tolerance_m', 'altitude_margin_m', ...
    'altitude_pass', 'battery_power_pass', 'battery_current_pass', 'thrust_pass', 'voltage_pass', ...
    'power_reduction_pass', 'physical_constraints_pass', 'feasible', ...
    'failed_check_count', 'failed_checks_list', 'primary_failure_reason', 'failure_reason'});

bestCasesTable = summaryTable(summaryTable.feasible & (summaryTable.off_fraction >= cfg.minimum_off_fraction_for_primary_results), :);
if ~isempty(bestCasesTable)
    bestCasesTable = sortrows(bestCasesTable, ...
        {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
        {'descend', 'ascend', 'ascend', 'ascend'});
end
failedCasesTable = summaryTable(~summaryTable.feasible, :);

feasibilityAuditTable = build_feasibility_audit_table(summaryTable);
validBRRangesTable = build_valid_br_ranges_table(cfg, summaryTable);
mainResultsTable = build_main_results_table(cfg, summaryTable, validBRRangesTable);

% Core outputs only.
writetable(validBRRangesTable, fullfile(cfg.paths.results_dir, 'duty_cycle_valid_BR_ranges.csv'));
writetable(feasibilityAuditTable, fullfile(cfg.paths.results_dir, 'duty_cycle_feasibility_audit.csv'));
writetable(mainResultsTable, fullfile(cfg.paths.results_dir, 'duty_cycle_main_results.csv'));
% Practical significance summary table (core output).
practicalSignificanceSummaryTable = build_practical_significance_summary(cfg, summaryTable);
writetable(practicalSignificanceSummaryTable, fullfile(cfg.paths.results_dir, 'duty_cycle_practical_significance_summary.csv'));

if cfg.output.write_debug_tables
    writetable(summaryTable, fullfile(cfg.paths.results_dir, 'duty_cycle_summary_table.csv'));

    filteredOff25Table = summaryTable(summaryTable.feasible & (summaryTable.off_fraction >= 0.25), :);
    if ~isempty(filteredOff25Table)
        filteredOff25Table = sortrows(filteredOff25Table, ...
            {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
            {'descend', 'ascend', 'ascend', 'ascend'});
    end

    highBuoyancyRelevantCasesTable = summaryTable(summaryTable.feasible & summaryTable.buoyancy_ratio >= 0.70, :);
    closestCasesTable = build_closest_cases(summaryTable);
    altitudeThresholdSummaryTable = build_altitude_threshold_summary_by_buoyancy(summaryTable);
    highBuoyancySummaryTable = build_high_buoyancy_summary_table(summaryTable);
    feasibilityByBuoyancy = build_feasibility_by_buoyancy_ratio(summaryTable);
    thresholdTable = build_buoyancy_threshold_table(summaryTable, cfg.sweep.include_ideal_reference_in_threshold);
    optimumSummaryTable = build_optimum_summary_table(summaryTable);

    writetable(parameterTable, fullfile(cfg.paths.results_dir, 'duty_cycle_parameter_table.csv'));
    writetable(feasibilityTable, fullfile(cfg.paths.results_dir, 'duty_cycle_feasibility_table.csv'));
    writetable(bestCasesTable, fullfile(cfg.paths.results_dir, 'duty_cycle_best_cases.csv'));
    writetable(filteredOff25Table, fullfile(cfg.paths.results_dir, 'duty_cycle_feasible_cases_min_off_fraction_25.csv'));
    writetable(highBuoyancyRelevantCasesTable, fullfile(cfg.paths.results_dir, 'duty_cycle_high_buoyancy_relevant_cases.csv'));
    writetable(highBuoyancySummaryTable, fullfile(cfg.paths.results_dir, 'duty_cycle_high_buoyancy_summary.csv'));
    writetable(failedCasesTable, fullfile(cfg.paths.results_dir, 'duty_cycle_failed_cases.csv'));
    writetable(closestCasesTable, fullfile(cfg.paths.results_dir, 'duty_cycle_closest_cases.csv'));
    writetable(optimumSummaryTable, fullfile(cfg.paths.results_dir, 'duty_cycle_optimum_summary.csv'));
    writetable(feasibilityByBuoyancy, fullfile(cfg.paths.results_dir, 'feasibility_by_buoyancy_ratio.csv'));
    writetable(thresholdTable, fullfile(cfg.paths.results_dir, 'buoyancy_feasibility_threshold.csv'));
    writetable(altitudeThresholdSummaryTable, fullfile(cfg.paths.results_dir, 'altitude_threshold_summary_by_buoyancy.csv'));
end

% Keep baseline table for plotting traceability in debug mode.
if cfg.output.write_debug_tables
    writetable(continuousTable, fullfile(cfg.paths.results_dir, 'continuous_hover_baseline_cases.csv'));
end

end

function mainResultsTable = build_main_results_table(cfg, summaryTable, validBRRangesTable)
source = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
if isempty(source)
    source = summaryTable;
end

allValid = source(source.feasible, :);
moderateValid = source(source.feasible_moderate_duty, :);

rowCells = {};

rowCells{end+1,1} = make_range_row('all_feasible_cases_valid_range', source, validBRRangesTable, 'all_feasible_cases', ...
    0.0, 0.0); %#ok<AGROW>
rowCells{end+1,1} = make_range_row('short_break_pulsing_valid_range', source, validBRRangesTable, 'short_break_pulsing', ...
    cfg.thresholds.short_break_min_off_fraction, cfg.thresholds.short_break_min_T_off_s); %#ok<AGROW>
rowCells{end+1,1} = make_range_row('moderate_duty_cycle_valid_range', source, validBRRangesTable, 'moderate_duty_cycle', ...
    cfg.thresholds.moderate_min_off_fraction, cfg.thresholds.moderate_min_T_off_s); %#ok<AGROW>
rowCells{end+1,1} = make_range_row('strong_duty_cycle_valid_range', source, validBRRangesTable, 'strong_duty_cycle', ...
    cfg.thresholds.strong_min_off_fraction, cfg.thresholds.strong_min_T_off_s); %#ok<AGROW>

[lowestContRow, lowestContBR, lowestContW] = get_lowest_continuous_row(source);
rowCells{end+1,1} = make_result_row( ...
    'lowest_absolute_continuous_power', ...
    'continuous_total_power', nan, nan, nan, nan, ...
    "n/a", "n/a", ...
    lowestContBR, nan, nan, nan, ...
    lowestContW, nan, nan, ...
    lowestContRow.altitude_drop_m, lowestContRow.altitude_margin_m, ...
    'Lowest absolute continuous total power across tested buoyancy ratios.'); %#ok<AGROW>

if isempty(allValid)
    rowCells{end+1,1} = make_result_row('lowest_absolute_valid_duty_cycle_power', 'all_valid_duty_cycle', nan, nan, nan, nan, ...
        "No valid duty-cycle cases", "No valid duty-cycle cases", ...
        nan, nan, nan, nan, nan, nan, nan, nan, nan, ...
        'No valid duty-cycle cases found for absolute power comparison.'); %#ok<AGROW>
else
    [~, idxDutyMin] = min(allValid.P_duty_total_W);
    minDuty = allValid(idxDutyMin, :);
    rowCells{end+1,1} = make_result_row('lowest_absolute_valid_duty_cycle_power', 'all_valid_duty_cycle', nan, nan, nan, nan, ...
        "n/a", "n/a", ...
        minDuty.buoyancy_ratio, minDuty.T_on_s, minDuty.T_off_s, minDuty.off_fraction, ...
        minDuty.P_cont_total_W, minDuty.P_duty_total_W, minDuty.total_power_reduction_percent, ...
        minDuty.altitude_drop_m, minDuty.altitude_margin_m, ...
        'Lowest absolute duty-cycle total power across all valid duty-cycle cases.'); %#ok<AGROW>
end

if isempty(moderateValid)
    rowCells{end+1,1} = make_result_row('best_moderate_relative_saving', 'off_fraction>=0.25 and T_off>=0.30 s', ...
        cfg.thresholds.moderate_min_off_fraction, cfg.thresholds.moderate_min_T_off_s, nan, nan, ...
        "No valid moderate duty-cycle range", "No valid moderate duty-cycle range", ...
        nan, nan, nan, nan, nan, nan, nan, nan, nan, ...
        'No valid moderate duty-cycle case found for relative saving.'); %#ok<AGROW>

    rowCells{end+1,1} = make_result_row('best_moderate_absolute_duty_power', 'off_fraction>=0.25 and T_off>=0.30 s', ...
        cfg.thresholds.moderate_min_off_fraction, cfg.thresholds.moderate_min_T_off_s, nan, nan, ...
        "No valid moderate duty-cycle range", "No valid moderate duty-cycle range", ...
        nan, nan, nan, nan, nan, nan, nan, nan, nan, ...
        'No valid moderate duty-cycle case found for absolute duty-cycle power.'); %#ok<AGROW>
else
    validRow = validBRRangesTable(strcmp(string(validBRRangesTable.category), "moderate_duty_cycle"), :);

    [~, idxRel] = max(moderateValid.total_power_reduction_percent);
    bestRel = moderateValid(idxRel, :);
    rowCells{end+1,1} = make_result_row('best_moderate_relative_saving', 'off_fraction>=0.25 and T_off>=0.30 s', ...
        cfg.thresholds.moderate_min_off_fraction, cfg.thresholds.moderate_min_T_off_s, ...
        validRow.lowest_valid_BR, validRow.highest_valid_BR, ...
        validRow.dominant_failure_below_lower_bound, validRow.dominant_failure_above_upper_bound, ...
        bestRel.buoyancy_ratio, bestRel.T_on_s, bestRel.T_off_s, bestRel.off_fraction, ...
        bestRel.P_cont_total_W, bestRel.P_duty_total_W, bestRel.total_power_reduction_percent, ...
        bestRel.altitude_drop_m, bestRel.altitude_margin_m, ...
        'Best relative saving within the valid moderate duty-cycle BR range.'); %#ok<AGROW>

    [~, idxAbs] = min(moderateValid.P_duty_total_W);
    bestAbs = moderateValid(idxAbs, :);
    rowCells{end+1,1} = make_result_row('best_moderate_absolute_duty_power', 'off_fraction>=0.25 and T_off>=0.30 s', ...
        cfg.thresholds.moderate_min_off_fraction, cfg.thresholds.moderate_min_T_off_s, ...
        validRow.lowest_valid_BR, validRow.highest_valid_BR, ...
        validRow.dominant_failure_below_lower_bound, validRow.dominant_failure_above_upper_bound, ...
        bestAbs.buoyancy_ratio, bestAbs.T_on_s, bestAbs.T_off_s, bestAbs.off_fraction, ...
        bestAbs.P_cont_total_W, bestAbs.P_duty_total_W, bestAbs.total_power_reduction_percent, ...
        bestAbs.altitude_drop_m, bestAbs.altitude_margin_m, ...
        'Lowest absolute duty-cycle power within the valid moderate duty-cycle BR range.'); %#ok<AGROW>
end

mainResultsTable = vertcat(rowCells{:});
mainResultsTable = add_practical_columns_to_main_results(mainResultsTable, validBRRangesTable);
end

function mainResultsTable = add_practical_columns_to_main_results(mainResultsTable, validBRRangesTable)
n = height(mainResultsTable);
mainResultsTable.lowest_practically_significant_BR = nan(n, 1);
mainResultsTable.highest_practically_significant_BR = nan(n, 1);
mainResultsTable.number_of_practically_significant_BR_values = nan(n, 1);
mainResultsTable.total_practically_significant_cases = nan(n, 1);
mainResultsTable.best_practically_significant_BR = nan(n, 1);
mainResultsTable.best_practically_significant_power_reduction_percent = nan(n, 1);
mainResultsTable.best_practically_significant_T_on_s = nan(n, 1);
mainResultsTable.best_practically_significant_T_off_s = nan(n, 1);
mainResultsTable.best_practically_significant_altitude_margin_m = nan(n, 1);

resultNames = string(mainResultsTable.result_name);
    categories = ["all_feasible_cases"; "short_break_pulsing"; "moderate_duty_cycle"; "strong_duty_cycle"];
for i = 1:numel(categories)
    cat = categories(i);
    src = validBRRangesTable(strcmp(string(validBRRangesTable.category), cat), :);
    if isempty(src)
        continue;
    end

    targetName = cat + "_valid_range";
    idx = find(resultNames == targetName, 1, 'first');
    if isempty(idx)
        continue;
    end

    mainResultsTable.lowest_practically_significant_BR(idx) = src.lowest_practically_significant_BR;
    mainResultsTable.highest_practically_significant_BR(idx) = src.highest_practically_significant_BR;
    mainResultsTable.number_of_practically_significant_BR_values(idx) = src.number_of_practically_significant_BR_values;
    mainResultsTable.total_practically_significant_cases(idx) = src.total_practically_significant_cases;
    mainResultsTable.best_practically_significant_BR(idx) = src.best_practically_significant_BR;
    mainResultsTable.best_practically_significant_power_reduction_percent(idx) = src.best_practically_significant_power_reduction_percent;
    mainResultsTable.best_practically_significant_T_on_s(idx) = src.best_practically_significant_T_on_s;
    mainResultsTable.best_practically_significant_T_off_s(idx) = src.best_practically_significant_T_off_s;
    mainResultsTable.best_practically_significant_altitude_margin_m(idx) = src.best_practically_significant_altitude_margin_m;
end
end

function rowTable = make_range_row(resultName, source, validBRRangesTable, categoryName, minOffFraction, minTOff)
row = validBRRangesTable(strcmp(string(validBRRangesTable.category), string(categoryName)), :);
if isempty(row)
    rowTable = make_result_row(resultName, get_definition_text(categoryName, minOffFraction, minTOff), ...
        minOffFraction, minTOff, nan, nan, ...
        "Category not available", "Category not available", ...
        nan, nan, nan, nan, nan, nan, nan, nan, nan, ...
        'Category not available in validity range table.');
    return;
end

validMask = get_valid_mask_for_category(source, categoryName);
validRows = source(validMask, :);

if isempty(validRows)
    rowTable = make_result_row(resultName, get_definition_text(categoryName, minOffFraction, minTOff), ...
        minOffFraction, minTOff, row.lowest_valid_BR, row.highest_valid_BR, ...
        row.dominant_failure_below_lower_bound, row.dominant_failure_above_upper_bound, ...
        nan, nan, nan, nan, nan, nan, nan, nan, nan, ...
        sprintf('No valid range under %s definition.', strrep(categoryName, '_', ' ')));
    return;
end

ranked = sortrows(validRows, {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
    {'descend', 'ascend', 'ascend', 'ascend'});
best = ranked(1, :);

rowTable = make_result_row(resultName, get_definition_text(categoryName, minOffFraction, minTOff), ...
    minOffFraction, minTOff, row.lowest_valid_BR, row.highest_valid_BR, ...
    row.dominant_failure_below_lower_bound, row.dominant_failure_above_upper_bound, ...
    best.buoyancy_ratio, best.T_on_s, best.T_off_s, best.off_fraction, ...
    best.P_cont_total_W, best.P_duty_total_W, best.total_power_reduction_percent, ...
    best.altitude_drop_m, best.altitude_margin_m, ...
    char(row.interpretation_note));
end

function row = make_result_row(resultName, dutyDefinition, minOff, minTOff, lowValid, highValid, lowerReason, upperReason, ...
    br, ton, toff, offFraction, pCont, pDuty, powerReductionPercent, altitudeDrop, altitudeMargin, interpretation)
row = table(string(resultName), string(dutyDefinition), minOff, minTOff, lowValid, highValid, ...
    string(lowerReason), string(upperReason), br, ton, toff, offFraction, pCont, pDuty, powerReductionPercent, ...
    altitudeDrop, altitudeMargin, string(interpretation), ...
    'VariableNames', {'result_name', 'duty_cycle_definition', 'min_off_fraction', 'min_T_off_s', ...
    'lowest_valid_BR', 'highest_valid_BR', 'lower_bound_reason', 'upper_bound_reason', ...
    'BR', 'T_on_s', 'T_off_s', 'off_fraction', 'P_cont_total_W', 'P_duty_total_W', ...
    'total_power_reduction_percent', 'altitude_drop_m', 'altitude_margin_m', 'primary_interpretation'});
end

function [lowestRow, lowestBR, lowestW] = get_lowest_continuous_row(source)
contByBR = groupsummary(source, 'buoyancy_ratio', 'min', 'P_cont_total_W');
[lowestW, idx] = min(contByBR.min_P_cont_total_W);
lowestBR = contByBR.buoyancy_ratio(idx);
matching = source(abs(source.buoyancy_ratio - lowestBR) < 1e-12, :);
[~, mIdx] = min(matching.P_cont_total_W);
lowestRow = matching(mIdx, :);
end

function mask = get_valid_mask_for_category(source, categoryName)
switch string(categoryName)
    case "short_break_pulsing"
        mask = source.feasible_short_break;
    case "moderate_duty_cycle"
        mask = source.feasible_moderate_duty;
    case "strong_duty_cycle"
        mask = source.feasible_strong_duty;
    otherwise
        mask = source.feasible;
end
end

function text = get_definition_text(categoryName, minOff, minTOff)
text = sprintf('%s: off_fraction >= %.2f and T_off >= %.2f s', strrep(char(categoryName), '_', ' '), minOff, minTOff);
end

function validBRRangesTable = build_valid_br_ranges_table(cfg, summaryTable)
source = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
if isempty(source)
    source = summaryTable;
end

validBRRangesTable = vertcat( ...
    build_category_row(source, "all_feasible_cases", 0.0, 0.0, true(height(source), 1)), ...
    build_category_row(source, "short_break_pulsing", cfg.thresholds.short_break_min_off_fraction, cfg.thresholds.short_break_min_T_off_s, source.passes_short_break_definition), ...
    build_category_row(source, "moderate_duty_cycle", cfg.thresholds.moderate_min_off_fraction, cfg.thresholds.moderate_min_T_off_s, source.passes_moderate_duty_definition), ...
    build_category_row(source, "strong_duty_cycle", cfg.thresholds.strong_min_off_fraction, cfg.thresholds.strong_min_T_off_s, source.passes_strong_duty_definition));
end

function rowTable = build_category_row(source, categoryName, minOffFractionRequired, minTOffRequired, categoryMask)
tested_BR_min = min(source.buoyancy_ratio);
tested_BR_max = max(source.buoyancy_ratio);

catRows = source(categoryMask, :);
powerOnlyRows = catRows(catRows.power_reduction_pass, :);
physicalOnlyRows = catRows(catRows.physical_constraints_pass, :);
validRows = catRows(catRows.power_reduction_pass & catRows.physical_constraints_pass, :);
practicalRows = validRows(validRows.passes_practical_followup_threshold, :);

lowest_BR_with_power_reduction_only = bound_or_nan(powerOnlyRows, true);
highest_BR_with_power_reduction_only = bound_or_nan(powerOnlyRows, false);
lowest_BR_passing_physical_constraints_only = bound_or_nan(physicalOnlyRows, true);
highest_BR_passing_physical_constraints_only = bound_or_nan(physicalOnlyRows, false);
lowest_valid_BR = bound_or_nan(validRows, true);
highest_valid_BR = bound_or_nan(validRows, false);
lowest_practically_significant_BR = bound_or_nan(practicalRows, true);
highest_practically_significant_BR = bound_or_nan(practicalRows, false);

if isempty(validRows)
    lower_bound_found = false;
    upper_bound_found = false;
    number_of_BR_values_valid = 0;
    total_valid_cases = 0;
    best_BR_in_valid_range = nan;
    best_power_reduction_percent = nan;
    best_T_on_s = nan;
    best_T_off_s = nan;
    best_off_fraction = nan;
    best_altitude_drop_m = nan;
    best_altitude_margin_m = nan;
    dominant_failure_below_lower_bound = "No valid cases for this duty-cycle definition.";
    dominant_failure_above_upper_bound = "No valid cases for this duty-cycle definition.";
    interpretation_note = "No valid buoyancy-ratio interval found under this duty-cycle definition.";
    number_of_practically_significant_BR_values = 0;
    total_practically_significant_cases = 0;
    best_practically_significant_BR = nan;
    best_practically_significant_power_reduction_percent = nan;
    best_practically_significant_T_on_s = nan;
    best_practically_significant_T_off_s = nan;
    best_practically_significant_altitude_margin_m = nan;
else
    number_of_BR_values_valid = numel(unique(validRows.buoyancy_ratio));
    total_valid_cases = height(validRows);

    ranked = sortrows(validRows, {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
        {'descend', 'ascend', 'ascend', 'ascend'});
    best = ranked(1, :);
    best_BR_in_valid_range = best.buoyancy_ratio;
    best_power_reduction_percent = best.total_power_reduction_percent;
    best_T_on_s = best.T_on_s;
    best_T_off_s = best.T_off_s;
    best_off_fraction = best.off_fraction;
    best_altitude_drop_m = best.altitude_drop_m;
    best_altitude_margin_m = best.altitude_margin_m;

    belowRows = catRows(catRows.buoyancy_ratio < lowest_valid_BR - 1e-12, :);
    belowInvalid = belowRows(~(belowRows.power_reduction_pass & belowRows.physical_constraints_pass), :);
    belowPhysicalFailCount = sum(~belowInvalid.physical_constraints_pass);
    belowPowerOnlyFailCount = sum(belowInvalid.physical_constraints_pass & ~belowInvalid.power_reduction_pass);
    lower_bound_found = (~isempty(belowInvalid)) && (belowPhysicalFailCount > belowPowerOnlyFailCount);

    if isempty(belowInvalid)
        dominant_failure_below_lower_bound = "No invalid cases below valid range within tested BRs.";
    else
        dominant_failure_below_lower_bound = summarize_dominant_failure(belowInvalid, true);
    end

    aboveRows = catRows(catRows.buoyancy_ratio > highest_valid_BR + 1e-12, :);
    aboveInvalid = aboveRows(~(aboveRows.power_reduction_pass & aboveRows.physical_constraints_pass), :);
    abovePowerOnlyCount = sum(aboveInvalid.physical_constraints_pass & ~aboveInvalid.power_reduction_pass);
    upper_bound_found = (~isempty(aboveInvalid)) && (highest_valid_BR < tested_BR_max - 1e-12) && (abovePowerOnlyCount > 0);

    if isempty(aboveInvalid)
        dominant_failure_above_upper_bound = "No invalid cases above valid range within tested BRs.";
    else
        dominant_failure_above_upper_bound = summarize_dominant_failure(aboveInvalid, false);
    end

    if abs(lowest_valid_BR - tested_BR_min) < 1e-12
        lowerText = "Lower physical failure boundary was not identified within the tested range.";
    else
        lowerText = sprintf("Lower physical feasibility limit identified at BR = %.3f. Below this, duty-cycled thrust failed altitude, battery, thrust, or voltage constraints under the tested timing requirements.", lowest_valid_BR);
    end

    if upper_bound_found
        upperText = sprintf("Upper power-benefit limit identified at BR = %.3f. Above this, continuous low-thrust hover is more efficient than the tested duty-cycled strategy.", highest_valid_BR);
    elseif abs(highest_valid_BR - tested_BR_max) < 1e-12
        upperText = "Upper power-benefit limit was not identified within the tested range.";
    else
        upperText = "Upper power-benefit limit was not conclusively identified from the tested cases.";
    end

    interpretation_note = sprintf("%s %s", lowerText, upperText);

    if isempty(practicalRows)
        number_of_practically_significant_BR_values = 0;
        total_practically_significant_cases = 0;
        best_practically_significant_BR = nan;
        best_practically_significant_power_reduction_percent = nan;
        best_practically_significant_T_on_s = nan;
        best_practically_significant_T_off_s = nan;
        best_practically_significant_altitude_margin_m = nan;
    else
        number_of_practically_significant_BR_values = numel(unique(practicalRows.buoyancy_ratio));
        total_practically_significant_cases = height(practicalRows);
        rankedPractical = sortrows(practicalRows, {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
            {'descend', 'ascend', 'ascend', 'ascend'});
        bestPractical = rankedPractical(1, :);
        best_practically_significant_BR = bestPractical.buoyancy_ratio;
        best_practically_significant_power_reduction_percent = bestPractical.total_power_reduction_percent;
        best_practically_significant_T_on_s = bestPractical.T_on_s;
        best_practically_significant_T_off_s = bestPractical.T_off_s;
        best_practically_significant_altitude_margin_m = bestPractical.altitude_margin_m;
    end
end

rowTable = table( ...
    string(categoryName), minOffFractionRequired, minTOffRequired, ...
    tested_BR_min, tested_BR_max, ...
    lowest_BR_with_power_reduction_only, highest_BR_with_power_reduction_only, ...
    lowest_BR_passing_physical_constraints_only, highest_BR_passing_physical_constraints_only, ...
    lowest_valid_BR, highest_valid_BR, ...
    lowest_practically_significant_BR, highest_practically_significant_BR, ...
    lower_bound_found, upper_bound_found, ...
    number_of_BR_values_valid, total_valid_cases, ...
    number_of_practically_significant_BR_values, total_practically_significant_cases, ...
    best_BR_in_valid_range, best_power_reduction_percent, best_T_on_s, best_T_off_s, ...
    best_practically_significant_BR, best_practically_significant_power_reduction_percent, ...
    best_practically_significant_T_on_s, best_practically_significant_T_off_s, ...
    best_off_fraction, best_altitude_drop_m, best_altitude_margin_m, ...
    best_practically_significant_altitude_margin_m, ...
    string(dominant_failure_below_lower_bound), string(dominant_failure_above_upper_bound), ...
    string(interpretation_note), ...
    'VariableNames', {'category', 'min_off_fraction_required', 'min_T_off_s_required', ...
    'tested_BR_min', 'tested_BR_max', ...
    'lowest_BR_with_power_reduction_only', 'highest_BR_with_power_reduction_only', ...
    'lowest_BR_passing_physical_constraints_only', 'highest_BR_passing_physical_constraints_only', ...
    'lowest_valid_BR', 'highest_valid_BR', ...
    'lowest_practically_significant_BR', 'highest_practically_significant_BR', ...
    'lower_bound_found', 'upper_bound_found', ...
    'number_of_BR_values_valid', 'total_valid_cases', ...
    'number_of_practically_significant_BR_values', 'total_practically_significant_cases', ...
    'best_BR_in_valid_range', 'best_power_reduction_percent', 'best_T_on_s', 'best_T_off_s', ...
    'best_practically_significant_BR', 'best_practically_significant_power_reduction_percent', ...
    'best_practically_significant_T_on_s', 'best_practically_significant_T_off_s', ...
    'best_off_fraction', 'best_altitude_drop_m', 'best_altitude_margin_m', ...
    'best_practically_significant_altitude_margin_m', ...
    'dominant_failure_below_lower_bound', 'dominant_failure_above_upper_bound', 'interpretation_note'});
end

function value = bound_or_nan(rows, isLower)
if isempty(rows)
    value = nan;
    return;
end
if isLower
    value = min(rows.buoyancy_ratio);
else
    value = max(rows.buoyancy_ratio);
end
end

function summary = summarize_dominant_failure(rows, isBelowRange)
if isempty(rows)
    summary = "No failures available.";
    return;
end

tokens = strings(0, 1);
for i = 1:height(rows)
    failureTokens = split(string(rows.failed_checks_list(i)), ';');
    failureTokens = strtrim(failureTokens);
    failureTokens = failureTokens(failureTokens ~= "");
    if isempty(failureTokens)
        if ~rows.physical_constraints_pass(i) && ~rows.altitude_pass(i)
            failureTokens = "altitude_drop_exceeds_tolerance";
        elseif ~rows.physical_constraints_pass(i)
            failureTokens = "physical_constraints_failed";
        elseif ~rows.power_reduction_pass(i)
            failureTokens = "average_power_not_lower_than_continuous";
        else
            failureTokens = "unknown_failure";
        end
    end
    tokens = [tokens; failureTokens]; %#ok<AGROW>
end

[uniqueTokens, ~, idx] = unique(tokens);
counts = accumarray(idx, 1);
[~, order] = sort(counts, 'descend');
showN = min(2, numel(order));
parts = strings(showN, 1);
for k = 1:showN
    parts(k) = sprintf('%s (%d)', uniqueTokens(order(k)), counts(order(k)));
end

directionPrefix = "Above valid range";
if isBelowRange
    directionPrefix = "Below valid range";
end
summary = sprintf('%s dominant failures: %s', directionPrefix, strjoin(parts, ', '));
end

function feasibilityAuditTable = build_feasibility_audit_table(summaryTable)
total_cases = height(summaryTable);
feasible_cases = sum(summaryTable.feasible);
infeasible_cases = total_cases - feasible_cases;

altitude_pass_count = sum(summaryTable.altitude_pass);
altitude_fail_count = total_cases - altitude_pass_count;
battery_power_pass_count = sum(summaryTable.battery_power_pass);
battery_power_fail_count = total_cases - battery_power_pass_count;
battery_current_pass_count = sum(summaryTable.battery_current_pass);
battery_current_fail_count = total_cases - battery_current_pass_count;
thrust_pass_count = sum(summaryTable.thrust_pass);
thrust_fail_count = total_cases - thrust_pass_count;
voltage_pass_count = sum(summaryTable.voltage_pass);
voltage_fail_count = total_cases - voltage_pass_count;
power_reduction_pass_count = sum(summaryTable.power_reduction_pass);
power_reduction_fail_count = total_cases - power_reduction_pass_count;

feasible_with_altitude_fail_count = sum(summaryTable.feasible & ~summaryTable.altitude_pass);
feasible_with_battery_power_fail_count = sum(summaryTable.feasible & ~summaryTable.battery_power_pass);
feasible_with_battery_current_fail_count = sum(summaryTable.feasible & ~summaryTable.battery_current_pass);
feasible_with_thrust_fail_count = sum(summaryTable.feasible & ~summaryTable.thrust_pass);
feasible_with_voltage_fail_count = sum(summaryTable.feasible & ~summaryTable.voltage_pass);
feasible_with_power_reduction_fail_count = sum(summaryTable.feasible & ~summaryTable.power_reduction_pass);

if any([feasible_with_altitude_fail_count, feasible_with_battery_power_fail_count, feasible_with_battery_current_fail_count, ...
        feasible_with_thrust_fail_count, feasible_with_voltage_fail_count, feasible_with_power_reduction_fail_count] ~= 0)
    error('Feasibility audit failed: one or more feasible_with_*_fail_count values are nonzero.');
end

feasibilityAuditTable = table(total_cases, feasible_cases, infeasible_cases, ...
    altitude_pass_count, altitude_fail_count, ...
    battery_power_pass_count, battery_power_fail_count, ...
    battery_current_pass_count, battery_current_fail_count, ...
    thrust_pass_count, thrust_fail_count, ...
    voltage_pass_count, voltage_fail_count, ...
    power_reduction_pass_count, power_reduction_fail_count, ...
    feasible_with_altitude_fail_count, feasible_with_battery_power_fail_count, ...
    feasible_with_battery_current_fail_count, feasible_with_thrust_fail_count, ...
    feasible_with_voltage_fail_count, feasible_with_power_reduction_fail_count);
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
    'P_cont_total_W', 'P_duty_total_W', 'total_power_reduction_percent', ...
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

for i = 1:numRows
    rows = summaryTable(summaryTable.buoyancy_ratio == uniqueBuoyancy(i), :);
    buoyancy_ratio(i) = uniqueBuoyancy(i);
    total_cases(i) = height(rows);
    feasible_cases(i) = sum(rows.feasible);
    feasible_percent(i) = 100.0 * feasible_cases(i) / max(total_cases(i), 1);

    feasibleRows = rows(rows.feasible, :);
    if ~isempty(feasibleRows)
        best_power_reduction_percent(i) = max(feasibleRows.total_power_reduction_percent);
    end
end

feasibilityByBuoyancy = table( ...
    sweep_mode, buoyancy_ratio, total_cases, feasible_cases, feasible_percent, ...
    best_power_reduction_percent);
end

function altitudeSummaryTable = build_altitude_threshold_summary_by_buoyancy(summaryTable)
uniqueBuoyancy = unique(summaryTable.buoyancy_ratio);
numRows = numel(uniqueBuoyancy);

buoyancy_ratio = uniqueBuoyancy;
total_cases = zeros(numRows, 1);
altitude_pass_count = zeros(numRows, 1);
altitude_fail_count = zeros(numRows, 1);
min_altitude_drop_m = nan(numRows, 1);
max_altitude_drop_m = nan(numRows, 1);
best_altitude_margin_m = nan(numRows, 1);
worst_altitude_margin_m = nan(numRows, 1);
feasible_cases = zeros(numRows, 1);

for i = 1:numRows
    rows = summaryTable(summaryTable.buoyancy_ratio == uniqueBuoyancy(i), :);
    total_cases(i) = height(rows);
    altitude_pass_count(i) = sum(rows.altitude_pass);
    altitude_fail_count(i) = total_cases(i) - altitude_pass_count(i);
    min_altitude_drop_m(i) = min(rows.altitude_drop_m);
    max_altitude_drop_m(i) = max(rows.altitude_drop_m);
    best_altitude_margin_m(i) = max(rows.altitude_margin_m);
    worst_altitude_margin_m(i) = min(rows.altitude_margin_m);
    feasible_cases(i) = sum(rows.feasible);
end

altitudeSummaryTable = table(buoyancy_ratio, total_cases, altitude_pass_count, altitude_fail_count, ...
    min_altitude_drop_m, max_altitude_drop_m, best_altitude_margin_m, worst_altitude_margin_m, feasible_cases);
end

function highBuoyancySummaryTable = build_high_buoyancy_summary_table(summaryTable)
feasibleHigh = summaryTable(summaryTable.feasible & summaryTable.buoyancy_ratio >= 0.70, :);
feasible_cases = height(feasibleHigh);
if feasible_cases > 0
    ranked = sortrows(feasibleHigh, {'total_power_reduction_percent', 'altitude_drop_m', 'P_on_required_W', 'T_off_s'}, ...
        {'descend', 'ascend', 'ascend', 'ascend'});
    bestCase = ranked(1, :);
    best_power_reduction_percent = bestCase.total_power_reduction_percent;
    best_T_on_s = bestCase.T_on_s;
    best_T_off_s = bestCase.T_off_s;
    best_off_fraction = bestCase.off_fraction;
    highest_feasible_buoyancy_ratio = max(feasibleHigh.buoyancy_ratio);
    interpretation_note = "High-buoyancy subset isolates thesis-relevant buoyancy-assisted cases with BR >= 0.70.";
else
    best_power_reduction_percent = nan;
    best_T_on_s = nan;
    best_T_off_s = nan;
    best_off_fraction = nan;
    highest_feasible_buoyancy_ratio = nan;
    interpretation_note = "No feasible thesis-relevant cases were found for BR >= 0.70.";
end
highBuoyancySummaryTable = table(feasible_cases, best_power_reduction_percent, best_T_on_s, best_T_off_s, ...
    best_off_fraction, highest_feasible_buoyancy_ratio, interpretation_note);
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
        nan, minBuoyancyForPositivePower, nan, nan, nan, nan, nan, ...
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
min_buoyancy_for_positive_derived_endurance_improvement = nan(numRows, 1);
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
if isempty(thresholdSource)
    thresholdSource = summaryTable;
end

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
end

optimumSummaryTable = table( ...
    sweep_mode, buoyancy_ratio_min_tested, buoyancy_ratio_max_tested, ...
    best_buoyancy_ratio, best_T_on_s, best_T_off_s, ...
    on_fraction, off_fraction, duty_cycle_type, ...
    best_total_power_reduction_percent, derived_endurance_improvement_percent, ...
    altitude_drop_m, altitude_tolerance_m, altitude_margin_m, ...
    feasible_case_count, feasible_percent);
end

function practicalSignificanceSummaryTable = build_practical_significance_summary(cfg, summaryTable)
source = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
if isempty(source)
    source = summaryTable;
end

categories = ["all_feasible_cases"; "short_break_pulsing"; "moderate_duty_cycle"; "strong_duty_cycle"];
n = numel(categories);

duty_cycle_definition = categories;
valid_BR_min = nan(n, 1);
valid_BR_max = nan(n, 1);
practical_followup_threshold_percent = repmat(cfg.practical_significance.minimum_followup_threshold_percent, n, 1);
practically_significant_BR_min = nan(n, 1);
practically_significant_BR_max = nan(n, 1);
practically_significant_case_count = zeros(n, 1);
negligible_case_count = zeros(n, 1);
marginal_case_count = zeros(n, 1);
moderate_case_count = zeros(n, 1);
strong_case_count = zeros(n, 1);
best_power_reduction_percent = nan(n, 1);
best_power_reduction_category = strings(n, 1);
interpretation_note = strings(n, 1);

for i = 1:n
    cat = categories(i);
    mask = get_valid_mask_for_category(source, cat);
    valid = source(mask, :);
    practical = valid(valid.passes_practical_followup_threshold, :);

    if ~isempty(valid)
        valid_BR_min(i) = min(valid.buoyancy_ratio);
        valid_BR_max(i) = max(valid.buoyancy_ratio);
    end

    negligible_case_count(i) = sum(valid.practical_significance_category == "negligible");
    marginal_case_count(i) = sum(valid.practical_significance_category == "marginal");
    moderate_case_count(i) = sum(valid.practical_significance_category == "moderate");
    strong_case_count(i) = sum(valid.practical_significance_category == "strong");

    if isempty(practical)
        best_power_reduction_category(i) = "n/a";
        interpretation_note(i) = sprintf([ ...
            '%s are physically valid from BR = %s to BR = %s. ' ...
            'Using a %.1f%% practical follow-up threshold, no practically significant cases were found.'], ...
            strrep(char(cat), '_', ' '), fmt_or_none(valid_BR_min(i), '%.3f'), fmt_or_none(valid_BR_max(i), '%.3f'), ...
            cfg.practical_significance.minimum_followup_threshold_percent);
        continue;
    end

    practically_significant_BR_min(i) = min(practical.buoyancy_ratio);
    practically_significant_BR_max(i) = max(practical.buoyancy_ratio);
    practically_significant_case_count(i) = height(practical);

    [best_power_reduction_percent(i), idxBest] = max(practical.total_power_reduction_percent);
    best_power_reduction_category(i) = practical.practical_significance_category(idxBest);

    interpretation_note(i) = sprintf([ ...
        '%s are physically valid from BR = %s to BR = %s. ' ...
        'Using a %.1f%% practical follow-up threshold, practically significant cases occur from BR = %.3f to BR = %.3f. ' ...
        'Above this range, duty cycling may remain valid but the simulated power saving is below the selected follow-up threshold.'], ...
        strrep(char(cat), '_', ' '), fmt_or_none(valid_BR_min(i), '%.3f'), fmt_or_none(valid_BR_max(i), '%.3f'), ...
        cfg.practical_significance.minimum_followup_threshold_percent, ...
        practically_significant_BR_min(i), practically_significant_BR_max(i));
end

practicalSignificanceSummaryTable = table( ...
    duty_cycle_definition, valid_BR_min, valid_BR_max, practical_followup_threshold_percent, ...
    practically_significant_BR_min, practically_significant_BR_max, practically_significant_case_count, ...
    negligible_case_count, marginal_case_count, moderate_case_count, strong_case_count, ...
    best_power_reduction_percent, best_power_reduction_category, interpretation_note);
end

function text = fmt_or_none(value, fmt)
if isnan(value)
    text = 'none';
else
    text = sprintf(fmt, value);
end
end
