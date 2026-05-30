function run_duty_cycle_analysis
%RUN_DUTY_CYCLE_ANALYSIS Main entrypoint for duty-cycle thrust evaluation.

clc;
close all;

cfg = config_duty_cycle_parameters();
cfg = prepare_sweep_settings(cfg);
ensure_output_directories(cfg);
clean_new_output_directories(cfg);

battery = calculate_battery_limits(cfg);
continuousTable = build_continuous_cases(cfg, battery);

plannedCases = height(continuousTable) * numel(cfg.sweep.T_on_s) * numel(cfg.sweep.T_off_s) * numel(cfg.sweep.startup_energy_cases);
fprintf('Planned evaluated cases: %d\n', plannedCases);

summaryTable = run_duty_cycle_sweep(cfg, battery, continuousTable);

[~, ~, bestCasesTable, failedCasesTable, validBRRangesTable, mainResultsTable] = ...
    generate_duty_cycle_tables(cfg, battery, continuousTable, summaryTable);

plot_duty_cycle_results(cfg, continuousTable, summaryTable, bestCasesTable, validBRRangesTable);
write_duty_cycle_assumptions_md(cfg, battery, summaryTable);

print_console_summary(cfg, battery, summaryTable, failedCasesTable, validBRRangesTable, mainResultsTable);

end

function ensure_output_directories(cfg)
if ~exist(cfg.paths.results_dir, 'dir')
    mkdir(cfg.paths.results_dir);
end
if ~exist(cfg.paths.figures_dir, 'dir')
    mkdir(cfg.paths.figures_dir);
end
end

function clean_new_output_directories(cfg)
resultFiles = {
    'duty_cycle_main_results.csv'
    'duty_cycle_valid_BR_ranges.csv'
    'duty_cycle_practical_significance_summary.csv'
    'duty_cycle_feasibility_audit.csv'
    'duty_cycle_assumptions.md'
    'duty_cycle_summary_table.csv'
    'duty_cycle_parameter_table.csv'
    'duty_cycle_feasibility_table.csv'
    'duty_cycle_best_cases.csv'
    'duty_cycle_feasible_cases_min_off_fraction_25.csv'
    'duty_cycle_high_buoyancy_relevant_cases.csv'
    'duty_cycle_high_buoyancy_summary.csv'
    'duty_cycle_failed_cases.csv'
    'duty_cycle_closest_cases.csv'
    'duty_cycle_optimum_summary.csv'
    'feasibility_by_buoyancy_ratio.csv'
    'buoyancy_feasibility_threshold.csv'
    'altitude_threshold_summary_by_buoyancy.csv'
    'continuous_hover_baseline_cases.csv'
};

figureFiles = {
    'valid_BR_range_by_duty_definition.png'
    'practical_significance_vs_buoyancy_ratio.png'
    'altitude_margin_vs_buoyancy_ratio.png'
    'absolute_power_comparison.png'
    'power_reduction_curve_with_optimum.png'
    'power_vs_buoyancy_ratio.png'
    'altitude_drop_vs_toff.png'
    'best_case_summary.png'
    'buoyancy_feasibility_boundary.png'
    'off_fraction_vs_power_reduction.png'
    'duty_cycle_feasibility_map.png'
    'energy_per_cycle_comparison.png'
    'best_power_reduction_vs_buoyancy_ratio.png'
    'endurance_vs_buoyancy_ratio.png'
    'endurance_vs_buoyancy_ratio_log.png'
    'best_endurance_improvement_vs_buoyancy_ratio.png'
};

for i = 1:numel(resultFiles)
    safe_delete_file(fullfile(cfg.paths.results_dir, resultFiles{i}));
end
for i = 1:numel(figureFiles)
    safe_delete_file(fullfile(cfg.paths.figures_dir, figureFiles{i}));
end

perBuoyancyMaps = dir(fullfile(cfg.paths.figures_dir, 'duty_cycle_feasibility_map_BR_*.png'));
for i = 1:numel(perBuoyancyMaps)
    safe_delete_file(fullfile(perBuoyancyMaps(i).folder, perBuoyancyMaps(i).name));
end
end

function safe_delete_file(filePath)
if ~isfile(filePath)
    return;
end
try
    delete(filePath);
catch ME
    warning('[cleanup] Failed to delete file: %s (%s)', filePath, ME.message);
end
end

function continuousTable = build_continuous_cases(cfg, battery)
numCases = numel(cfg.sweep.active_buoyancy_ratio) * numel(cfg.sweep.efficiency_cases);
caseRows = cell(numCases, 1);
idx = 0;
for etaIdx = 1:numel(cfg.sweep.efficiency_cases)
    etaCase = cfg.sweep.efficiency_cases(etaIdx);
    for brIdx = 1:numel(cfg.sweep.active_buoyancy_ratio)
        idx = idx + 1;
        caseRows{idx} = simulate_continuous_hover_case(cfg, battery, cfg.sweep.active_buoyancy_ratio(brIdx), etaCase);
    end
end
continuousTable = struct2table(vertcat(caseRows{:}));
continuousTable = sortrows(continuousTable, {'eta_case', 'buoyancy_ratio'});
end

function cfg = prepare_sweep_settings(cfg)
activeBuoyancy = cfg.sweep.buoyancy_ratio;
if cfg.sweep.include_ideal_neutral_reference
    activeBuoyancy = unique([activeBuoyancy, 1.0]);
end

cfg.sweep.active_buoyancy_ratio = activeBuoyancy;
cfg.sweep.active_mode_label = "configured_sweep";
cfg.sweep.include_ideal_reference_in_threshold = false;
end

function print_console_summary(cfg, battery, summaryTable, failedCasesTable, validBRRangesTable, mainResultsTable)
fprintf('\n=== Duty-Cycle Thrust Evaluation Summary ===\n');
fprintf('Output results directory: %s\n', cfg.paths.results_dir);
fprintf('Output figures directory: %s\n', cfg.paths.figures_dir);
fprintf('Sweep label: %s\n', cfg.sweep.active_mode_label);
fprintf('Battery nominal energy: %.3f Wh (%.1f J)\n', battery.E_bat_Wh, battery.E_bat_J);
fprintf('Battery max current/power: %.3f A / %.3f W\n', battery.I_max_A, battery.P_bat_max_W);
fprintf('Total evaluated cases: %d\n', height(summaryTable));
fprintf('Feasible cases: %d\n', sum(summaryTable.feasible));
fprintf('Infeasible cases: %d\n', sum(~summaryTable.feasible));

fprintf('\nDuty-cycle validity range by definition\n');
fprintf('\nPrimary result: valid duty-cycle buoyancy range\n');
print_category_summary(validBRRangesTable, summaryTable, "short_break_pulsing", ...
    'short-break pulsing', cfg.thresholds.short_break_min_off_fraction, cfg.thresholds.short_break_min_T_off_s);
print_category_summary(validBRRangesTable, summaryTable, "moderate_duty_cycle", ...
    'moderate duty cycle', cfg.thresholds.moderate_min_off_fraction, cfg.thresholds.moderate_min_T_off_s);
print_category_summary(validBRRangesTable, summaryTable, "strong_duty_cycle", ...
    'strong duty cycle', cfg.thresholds.strong_min_off_fraction, cfg.thresholds.strong_min_T_off_s);

moderateRow = validBRRangesTable(strcmp(string(validBRRangesTable.category), "moderate_duty_cycle"), :);
if ~isempty(moderateRow) && ~isnan(moderateRow.lowest_valid_BR)
    fprintf(['Moderate duty-cycle cases were valid from BR = %.3f to BR = %.3f. ' ...
        'Below this range, cases mainly failed physical constraints, especially altitude tolerance. ' ...
        'Above this range, duty cycling no longer reduced total average power compared with continuous thrust.\n'], ...
        moderateRow.lowest_valid_BR, moderateRow.highest_valid_BR);
end

print_absolute_power_comparison(summaryTable);
print_practical_significance_assessment(cfg, validBRRangesTable);

if ~isempty(failedCasesTable)
    fprintf('\nMost common failure reasons:\n');
    reasons = split(join(string(failedCasesTable.failure_reason), ';'), ';');
    reasons = strtrim(reasons);
    reasons = reasons(reasons ~= "");
    [uniqueReasons, ~, reasonIdx] = unique(reasons);
    counts = accumarray(reasonIdx, 1);
    [countsSorted, order] = sort(counts, 'descend');
    showN = min(5, numel(order));
    for i = 1:showN
        fprintf('  - %s: %d\n', uniqueReasons(order(i)), countsSorted(i));
    end
end

fprintf('\nGenerated core files:\n');
fprintf('  - duty_cycle_main_results.csv\n');
fprintf('  - duty_cycle_valid_BR_ranges.csv\n');
fprintf('  - duty_cycle_practical_significance_summary.csv\n');
fprintf('  - duty_cycle_feasibility_audit.csv\n');
fprintf('  - duty_cycle_assumptions.md\n');
fprintf('  - valid_BR_range_by_duty_definition.png\n');
fprintf('  - practical_significance_vs_buoyancy_ratio.png\n');
fprintf('  - altitude_margin_vs_buoyancy_ratio.png\n');
fprintf('  - absolute_power_comparison.png\n');

if cfg.output.write_debug_tables || cfg.output.write_debug_figures
    fprintf('\nDebug outputs are enabled for this run.\n');
else
    fprintf('\nDebug outputs are disabled by default (cfg.output.write_debug_tables=false, cfg.output.write_debug_figures=false).\n');
end

if ~isempty(mainResultsTable)
    fprintf('Main results table rows: %d\n', height(mainResultsTable));
end

fprintf('\nDuty-cycle analysis complete.\n');
end

function print_practical_significance_assessment(cfg, validBRRangesTable)
fprintf('\nPractical significance assessment\n');
fprintf(['This is a deterministic simulation, so statistical significance is not assessed. ' ...
    'Practical significance is assessed using a configurable power-reduction threshold.\n']);
fprintf('Practical follow-up threshold: %.1f%%\n', cfg.practical_significance.minimum_followup_threshold_percent);

moderateRow = validBRRangesTable(strcmp(string(validBRRangesTable.category), "moderate_duty_cycle"), :);
if isempty(moderateRow)
    fprintf('Moderate duty-cycle valid BR range: not available\n');
    fprintf('Moderate duty-cycle practically significant BR range: not available\n');
    fprintf('Best practically significant case: not available\n');
    fprintf('Number of practically significant cases: 0\n');
    return;
end

if isnan(moderateRow.lowest_valid_BR)
    fprintf('Moderate duty-cycle valid BR range: none\n');
else
    fprintf('Moderate duty-cycle valid BR range: BR = %.3f to BR = %.3f\n', ...
        moderateRow.lowest_valid_BR, moderateRow.highest_valid_BR);
end

if isnan(moderateRow.lowest_practically_significant_BR)
    fprintf('Moderate duty-cycle practically significant BR range: none\n');
    fprintf('Best practically significant case: none\n');
    fprintf('Number of practically significant cases: %d\n', moderateRow.total_practically_significant_cases);
else
    fprintf('Moderate duty-cycle practically significant BR range: BR = %.3f to BR = %.3f\n', ...
        moderateRow.lowest_practically_significant_BR, moderateRow.highest_practically_significant_BR);
    fprintf('Best practically significant case: BR = %.3f, T_on = %.2f s, T_off = %.2f s, total power reduction = %.2f%%, altitude margin = %.3f m\n', ...
        moderateRow.best_practically_significant_BR, ...
        moderateRow.best_practically_significant_T_on_s, ...
        moderateRow.best_practically_significant_T_off_s, ...
        moderateRow.best_practically_significant_power_reduction_percent, ...
        moderateRow.best_practically_significant_altitude_margin_m);
    fprintf('Number of practically significant cases: %d\n', moderateRow.total_practically_significant_cases);
    fprintf(['Using a %.1f%% power-reduction threshold, moderate duty-cycle cases are practically significant from BR = %.3f to BR = %.3f. ' ...
        'Above this range, duty cycling may remain feasible but the power saving is below the selected follow-up threshold.\n'], ...
        cfg.practical_significance.minimum_followup_threshold_percent, ...
        moderateRow.lowest_practically_significant_BR, moderateRow.highest_practically_significant_BR);
end
end

function print_category_summary(validBRRangesTable, summaryTable, categoryKey, categoryLabel, minOffFraction, minTOff)
row = validBRRangesTable(strcmp(string(validBRRangesTable.category), string(categoryKey)), :);
if isempty(row)
    fprintf('\nCategory: %s\n', categoryLabel);
    fprintf('Duty-cycle definition: off_fraction >= %.2f and T_off >= %.2f s\n', minOffFraction, minTOff);
    fprintf('No category result was generated.\n');
    return;
end

fprintf('\nCategory: %s\n', categoryLabel);
fprintf('Duty-cycle definition: off_fraction >= %.2f and T_off >= %.2f s\n', minOffFraction, minTOff);

if isnan(row.lowest_valid_BR)
    fprintf('Lowest valid BR: none\n');
    fprintf('Highest valid BR: none\n');
else
    fprintf('Lowest valid BR: %.3f\n', row.lowest_valid_BR);
    fprintf('Highest valid BR: %.3f\n', row.highest_valid_BR);
end
fprintf('Lower-bound limiting reason: %s\n', string(row.dominant_failure_below_lower_bound));
fprintf('Upper-bound limiting reason: %s\n', string(row.dominant_failure_above_upper_bound));

validRows = get_valid_rows(summaryTable, categoryKey);
if isempty(validRows)
    fprintf('Best power reduction within this valid range: n/a\n');
    fprintf('Best actual duty-cycle total power within this valid range: n/a\n');
    fprintf('Best actual continuous total power within this valid range: n/a\n');
    return;
end

[bestReduction, idxRel] = max(validRows.total_power_reduction_percent);
bestRel = validRows(idxRel, :);
[bestDutyPower, idxAbs] = min(validRows.P_duty_total_W);
bestAbs = validRows(idxAbs, :);

fprintf('Best power reduction within this valid range: %.2f%% (BR=%.3f, T_on=%.2f s, T_off=%.2f s)\n', ...
    bestReduction, bestRel.buoyancy_ratio, bestRel.T_on_s, bestRel.T_off_s);
fprintf('Best actual duty-cycle total power within this valid range: %.4f W (BR=%.3f, T_on=%.2f s, T_off=%.2f s)\n', ...
    bestDutyPower, bestAbs.buoyancy_ratio, bestAbs.T_on_s, bestAbs.T_off_s);
fprintf('Best actual continuous total power within this valid range: %.4f W\n', min(validRows.P_cont_total_W));
end

function validRows = get_valid_rows(summaryTable, categoryKey)
source = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
if isempty(source)
    source = summaryTable;
end

switch string(categoryKey)
    case "short_break_pulsing"
        validRows = source(source.feasible_short_break, :);
    case "moderate_duty_cycle"
        validRows = source(source.feasible_moderate_duty, :);
    case "strong_duty_cycle"
        validRows = source(source.feasible_strong_duty, :);
    otherwise
        validRows = source(source.feasible, :);
end
end

function print_absolute_power_comparison(summaryTable)
source = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
if isempty(source)
    source = summaryTable;
end

contByBR = groupsummary(source, 'buoyancy_ratio', 'min', 'P_cont_total_W');
[lowestContW, idxCont] = min(contByBR.min_P_cont_total_W);
lowestContBR = contByBR.buoyancy_ratio(idxCont);

validAll = source(source.feasible, :);
if isempty(validAll)
    fprintf('\nAbsolute power comparison:\n');
    fprintf('- Lowest continuous total power occurred at BR = %.3f with P_cont_total = %.4f W.\n', lowestContBR, lowestContW);
    fprintf('- Lowest valid duty-cycle total power could not be computed because no valid duty-cycle cases were found.\n');
    return;
end

[lowestDutyW, idxDuty] = min(validAll.P_duty_total_W);
lowestDuty = validAll(idxDuty, :);

fprintf('\nAbsolute power comparison:\n');
fprintf('- Lowest continuous total power occurred at BR = %.3f with P_cont_total = %.4f W.\n', lowestContBR, lowestContW);
fprintf('- Lowest valid duty-cycle total power occurred at BR = %.3f with P_duty_total = %.4f W.\n', ...
    lowestDuty.buoyancy_ratio, lowestDutyW);
if lowestContW < lowestDutyW
    fprintf(['Minimum absolute power is achieved by continuous low-thrust operation, not duty-cycled thrust. ' ...
        'Duty cycling is therefore only beneficial as a relative saving within its valid BR range, not as the global minimum-power strategy.\n']);
end
end
