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

[parameterTable, ~, bestCasesTable, failedCasesTable] = generate_duty_cycle_tables(cfg, battery, continuousTable, summaryTable); %#ok<ASGLU>
plot_duty_cycle_results(cfg, continuousTable, summaryTable, bestCasesTable);
write_duty_cycle_assumptions_md(cfg, battery, summaryTable);

print_console_summary(cfg, battery, bestCasesTable, failedCasesTable, summaryTable, parameterTable);

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
% Clean only known duty-cycle outputs to avoid deleting unrelated artifacts.
resultFiles = {
    'duty_cycle_parameter_table.csv'
    'duty_cycle_summary_table.csv'
    'duty_cycle_feasibility_table.csv'
    'duty_cycle_best_cases.csv'
    'duty_cycle_feasible_cases_min_off_fraction_25.csv'
    'duty_cycle_high_buoyancy_relevant_cases.csv'
    'duty_cycle_high_buoyancy_summary.csv'
    'duty_cycle_failed_cases.csv'
    'duty_cycle_closest_cases.csv'
    'duty_cycle_optimum_summary.csv'
    'duty_cycle_feasibility_audit.csv'
    'feasibility_by_buoyancy_ratio.csv'
    'buoyancy_feasibility_threshold.csv'
    'altitude_threshold_summary_by_buoyancy.csv'
    'continuous_hover_baseline_cases.csv'
    'duty_cycle_assumptions.md'
};

figureFiles = {
    'power_vs_buoyancy_ratio.png'
    'altitude_margin_vs_buoyancy_ratio.png'
    'altitude_drop_vs_toff.png'
    'best_case_summary.png'
    'buoyancy_feasibility_boundary.png'
    'power_reduction_curve_with_optimum.png'
    'off_fraction_vs_power_reduction.png'
    'duty_cycle_feasibility_map.png'
    'energy_per_cycle_comparison.png'
    'best_power_reduction_vs_buoyancy_ratio.png'
    % Deprecated endurance figures are removed if they exist.
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
    warnState = warning('off', 'all');
    cleanupWarn = onCleanup(@() warning(warnState)); %#ok<NASGU>
    delete(filePath);
catch ME
    warning('[cleanup] Failed to delete file: %s (%s)', filePath, ME.message);
end
if isfile(filePath)
    warning('[cleanup] Failed to delete file: %s', filePath);
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

function print_console_summary(cfg, battery, bestCasesTable, failedCasesTable, summaryTable, parameterTable)
fprintf('\n=== Duty-Cycle Thrust Evaluation Summary ===\n');
fprintf('Output results directory: %s\n', cfg.paths.results_dir);
fprintf('Output figures directory: %s\n', cfg.paths.figures_dir);
fprintf('Sweep label: %s\n', cfg.sweep.active_mode_label);
fprintf('Battery nominal energy: %.3f Wh (%.1f J)\n', battery.E_bat_Wh, battery.E_bat_J);
fprintf('Battery max current/power: %.3f A / %.3f W\n', battery.I_max_A, battery.P_bat_max_W);
fprintf('Total evaluated cases: %d\n', height(summaryTable));
fprintf('Feasible cases: %d\n', sum(summaryTable.feasible));
fprintf('Infeasible cases: %d\n', sum(~summaryTable.feasible));

feasibleCaseCount = sum(summaryTable.feasible);
feasiblePercent = 100.0 * feasibleCaseCount / max(height(summaryTable), 1);
fprintf('Feasible percentage: %.2f%%\n', feasiblePercent);

passedAltitudeOnlyCount = sum(~summaryTable.infeasible_altitude_tolerance);
passedBatteryOnlyCount = sum(~summaryTable.infeasible_battery_limit);
passedThrustOnlyCount = sum(~summaryTable.infeasible_thrust_capability);
passedPhysicalFailedPowerCount = sum((~summaryTable.infeasible_altitude_tolerance) & ...
    (~summaryTable.infeasible_battery_limit) & (~summaryTable.infeasible_thrust_capability) & summaryTable.infeasible_average_power);

fprintf('Cases passing altitude criterion: %d\n', passedAltitudeOnlyCount);
fprintf('Cases passing battery criterion: %d\n', passedBatteryOnlyCount);
fprintf('Cases passing thrust criterion: %d\n', passedThrustOnlyCount);
fprintf('Cases passing all physical constraints but failing power reduction: %d\n', passedPhysicalFailedPowerCount);

if ~isempty(bestCasesTable)
    topN = min(5, height(bestCasesTable));
    fprintf('\nTop %d feasible cases (sorted by total power reduction):\n', topN);
    fprintf('%-8s %-8s %-8s %-10s %-29s %-10s\n', 'BR', 'T_on', 'T_off', 'PowerRed%', 'DerivedEnduranceImprovement%', 'Drop[m]');
    for i = 1:topN
        fprintf('%-8.2f %-8.2f %-8.2f %-10.2f %-16.2f %-10.4f\n', ...
            bestCasesTable.buoyancy_ratio(i), ...
            bestCasesTable.T_on_s(i), ...
            bestCasesTable.T_off_s(i), ...
            bestCasesTable.total_power_reduction_percent(i), ...
            bestCasesTable.derived_endurance_improvement_percent(i), ...
            bestCasesTable.altitude_drop_m(i));
    end
else
    fprintf('\nNo feasible duty-cycle cases were found under current assumptions.\n');
end

closestCase = get_closest_case(summaryTable);
if feasibleCaseCount > 0
    feasibleOnly = summaryTable(summaryTable.feasible, :);
    [~, idxBestPower] = max(feasibleOnly.total_power_reduction_percent);
    bestPowerCase = feasibleOnly(idxBestPower, :);
    feasibleOff25 = feasibleOnly(feasibleOnly.off_fraction >= 0.25, :);
    feasibleHighBuoyancy = feasibleOnly(feasibleOnly.buoyancy_ratio >= 0.70, :);
    feasibleHighBuoyancyOff25 = feasibleOnly(feasibleOnly.buoyancy_ratio >= 0.70 & feasibleOnly.off_fraction >= 0.25, :);

    thresholdSource = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
    sweepMin = min(thresholdSource.buoyancy_ratio);
    sweepMax = max(thresholdSource.buoyancy_ratio);
    atLowerBoundary = abs(bestPowerCase.buoyancy_ratio - sweepMin) < 1e-12;
    atUpperBoundary = abs(bestPowerCase.buoyancy_ratio - sweepMax) < 1e-12;

    feasibleByBuoyancyAll = groupsummary(feasibleOnly, 'buoyancy_ratio', 'sum', 'feasible');
    lowestFeasibleBuoyancy = min(feasibleByBuoyancyAll.buoyancy_ratio);
    highestFeasibleBuoyancy = max(feasibleByBuoyancyAll.buoyancy_ratio);

    fprintf('\nBest feasible case: BR=%.3f, T_on=%.2f s, T_off=%.2f s, total power reduction=%.2f%%, altitude drop=%.4f m.\n', ...
        bestPowerCase.buoyancy_ratio, bestPowerCase.T_on_s, bestPowerCase.T_off_s, ...
        bestPowerCase.total_power_reduction_percent, bestPowerCase.altitude_drop_m);
    fprintf('Lowest BR with feasible cases: %.3f\n', lowestFeasibleBuoyancy);
    fprintf('Highest BR with feasible cases: %.3f\n', highestFeasibleBuoyancy);
    fprintf('Buoyancy ratio with best power reduction: %.3f\n', bestPowerCase.buoyancy_ratio);
    fprintf('Best power reduction percent: %.2f%%\n', bestPowerCase.total_power_reduction_percent);
    fprintf('Best derived endurance improvement percent: %.2f%%\n', bestPowerCase.derived_endurance_improvement_percent);
    fprintf('Best T_on and T_off: T_on=%.2f s, T_off=%.2f s\n', bestPowerCase.T_on_s, bestPowerCase.T_off_s);
    fprintf('Best feasible case (no off-fraction filter): BR=%.3f, T_on=%.2f s, T_off=%.2f s, off_fraction=%.3f, duty_cycle_type=%s, power reduction=%.2f%%\n', ...
        bestPowerCase.buoyancy_ratio, bestPowerCase.T_on_s, bestPowerCase.T_off_s, bestPowerCase.off_fraction, ...
        string(bestPowerCase.duty_cycle_type), bestPowerCase.total_power_reduction_percent);
    fprintf('Feasible cases with off_fraction >= 0.25: %d\n', height(feasibleOff25));
    if ~isempty(feasibleOff25)
        [~, idxOff25] = max(feasibleOff25.total_power_reduction_percent);
        bestOff25 = feasibleOff25(idxOff25, :);
        fprintf('Best feasible case (off_fraction >= 0.25): BR=%.3f, T_on=%.2f s, T_off=%.2f s, off_fraction=%.3f, duty_cycle_type=%s, power reduction=%.2f%%\n', ...
            bestOff25.buoyancy_ratio, bestOff25.T_on_s, bestOff25.T_off_s, bestOff25.off_fraction, ...
            string(bestOff25.duty_cycle_type), bestOff25.total_power_reduction_percent);
    else
        fprintf('Best feasible case (off_fraction >= 0.25): none found.\n');
    end
    if ~isempty(feasibleHighBuoyancyOff25)
        [~, idxHighOff25] = max(feasibleHighBuoyancyOff25.total_power_reduction_percent);
        bestHighOff25 = feasibleHighBuoyancyOff25(idxHighOff25, :);
        fprintf('Best feasible case (BR >= 0.70 and off_fraction >= 0.25): BR=%.3f, T_on=%.2f s, T_off=%.2f s, off_fraction=%.3f, duty_cycle_type=%s, power reduction=%.2f%%\n', ...
            bestHighOff25.buoyancy_ratio, bestHighOff25.T_on_s, bestHighOff25.T_off_s, bestHighOff25.off_fraction, ...
            string(bestHighOff25.duty_cycle_type), bestHighOff25.total_power_reduction_percent);
    else
        fprintf('Best feasible case (BR >= 0.70 and off_fraction >= 0.25): none found.\n');
    end

    if atLowerBoundary
        fprintf('Boundary note: Best case occurs at the lower boundary. The tested range may still be truncating the optimum.\n');
    elseif atUpperBoundary
        fprintf('Boundary note: Best case occurs at the upper boundary. A higher-buoyancy sweep may be needed.\n');
    else
        fprintf('Boundary note: Best case occurs inside the tested range. The sweep appears to capture a local optimum.\n');
    end

    fprintf('\nThesis-relevant high-buoyancy subset\n');
    fprintf('Feasible cases with BR >= 0.70: %d\n', height(feasibleHighBuoyancy));
    if ~isempty(feasibleHighBuoyancy)
        [~, idxHigh] = max(feasibleHighBuoyancy.total_power_reduction_percent);
        bestHigh = feasibleHighBuoyancy(idxHigh, :);
        fprintf('Best power reduction for BR >= 0.70: %.2f%%\n', bestHigh.total_power_reduction_percent);
        fprintf('Best BR >= 0.70 case: BR=%.3f, T_on=%.2f s, T_off=%.2f s, off_fraction=%.3f, duty_cycle_type=%s\n', ...
            bestHigh.buoyancy_ratio, bestHigh.T_on_s, bestHigh.T_off_s, bestHigh.off_fraction, string(bestHigh.duty_cycle_type));
        fprintf('Highest feasible buoyancy ratio for BR >= 0.70 subset: %.3f\n', max(feasibleHighBuoyancy.buoyancy_ratio));
    else
        fprintf('No feasible cases found for BR >= 0.70.\n');
    end
else
    fprintf('\nClosest infeasible case: BR=%.3f, T_on=%.2f s, T_off=%.2f s, failed checks=%d, total power reduction=%.2f%%, altitude drop=%.4f m\n', ...
        closestCase.buoyancy_ratio, closestCase.T_on_s, closestCase.T_off_s, closestCase.failed_check_count, ...
        closestCase.total_power_reduction_percent, closestCase.altitude_drop_m);
end

thresholdSource = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
feasibleByBuoyancy = groupsummary(thresholdSource, 'buoyancy_ratio', 'sum', 'feasible');
firstFeasibleMask = feasibleByBuoyancy.sum_feasible > 0;
if any(firstFeasibleMask)
    firstFeasibleBuoyancy = min(feasibleByBuoyancy.buoyancy_ratio(firstFeasibleMask));
    maxFeasibleBuoyancy = max(feasibleByBuoyancy.buoyancy_ratio(firstFeasibleMask));
    lowerSweepBound = min(feasibleByBuoyancy.buoyancy_ratio);
    if abs(firstFeasibleBuoyancy - lowerSweepBound) < 1e-12
        fprintf('\nLower-bound note: Feasible cases exist at the minimum tested buoyancy ratio. This means the true lower feasibility threshold may be below the tested range.\n');
    else
        fprintf('\nLower-bound note: Feasible cases first appear at BR=%.3f and remain feasible up to BR=%.3f under the tested range.\n', ...
            firstFeasibleBuoyancy, maxFeasibleBuoyancy);
    end
else
    fprintf('\nLower-bound note: No feasible duty-cycled case was found in the tested buoyancy range.\n');
end

if feasibleCaseCount > 0
    thresholdSource = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
    sweepMin = min(thresholdSource.buoyancy_ratio);
    [~, idxBestAll] = max(summaryTable(summaryTable.feasible, :).total_power_reduction_percent);
    feasibleAll = summaryTable(summaryTable.feasible, :);
    bestAll = feasibleAll(idxBestAll, :);
    if abs(bestAll.buoyancy_ratio - sweepMin) < 1e-12
        if abs(sweepMin) < 1e-12 && abs(bestAll.buoyancy_ratio) < 1e-12
            fprintf('Optimum note: The best power reduction occurs at BR = 0. This indicates the model is favouring thrust pulsing even without buoyancy assistance, so the duty-cycle control model should be interpreted cautiously for a conventional multirotor.\n');
        else
            fprintf('Optimum note: The best power reduction occurs at the minimum tested buoyancy ratio. The optimum has not been captured unless the sweep starts at BR = 0.\n');
        end
    end
end

if feasibleCaseCount == 0
    fprintf('Main interpretation: The primary metric is total average power reduction. Endurance improvement is derived from this power reduction and is therefore reported only as a consequence of the power result. Under current assumptions, no duty-cycled cases reduced total average power while satisfying altitude, thrust, and battery limits. Continuous low-thrust hover remains more efficient than the tested motor-off/motor-on duty-cycle strategy.\n');
else
    fprintf('Main interpretation: The primary metric is total average power reduction. Endurance improvement is derived from this power reduction and is therefore reported only as a consequence of the power result. Under current assumptions, a small number of duty-cycled cases reduced total average power while satisfying altitude, thrust, and battery limits. The benefit is marginal and occurs only over a limited buoyancy-ratio and timing range.\n');
end

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

fprintf('\nGenerated files:\n');
fprintf('  - duty_cycle_parameter_table.csv\n');
fprintf('  - duty_cycle_summary_table.csv\n');
fprintf('  - duty_cycle_feasibility_table.csv\n');
fprintf('  - duty_cycle_best_cases.csv\n');
fprintf('  - duty_cycle_feasible_cases_min_off_fraction_25.csv\n');
fprintf('  - duty_cycle_high_buoyancy_relevant_cases.csv\n');
fprintf('  - duty_cycle_high_buoyancy_summary.csv\n');
fprintf('  - duty_cycle_failed_cases.csv\n');
fprintf('  - duty_cycle_closest_cases.csv\n');
fprintf('  - duty_cycle_optimum_summary.csv\n');
fprintf('  - duty_cycle_feasibility_audit.csv\n');
fprintf('  - feasibility_by_buoyancy_ratio.csv\n');
fprintf('  - buoyancy_feasibility_threshold.csv\n');
fprintf('  - altitude_threshold_summary_by_buoyancy.csv\n');
fprintf('  - duty_cycle_assumptions.md\n');
fprintf('  - power_vs_buoyancy_ratio.png\n');
fprintf('  - altitude_margin_vs_buoyancy_ratio.png\n');
fprintf('  - altitude_drop_vs_toff.png\n');
fprintf('  - best_case_summary.png\n');
fprintf('  - buoyancy_feasibility_boundary.png\n');
fprintf('  - power_reduction_curve_with_optimum.png\n');
fprintf('  - off_fraction_vs_power_reduction.png\n');

if isempty(parameterTable)
    fprintf('Warning: parameter table is empty.\n');
end

fprintf('\nDuty-cycle analysis complete.\n');
end

function closestCase = get_closest_case(summaryTable)
ranked = summaryTable;
ranked.total_power_penalty_W = ranked.P_duty_total_W - ranked.P_cont_total_W;
ranked = sortrows(ranked, {'failed_check_count', 'total_power_penalty_W', 'altitude_drop_m', 'P_on_required_W'}, ...
    {'ascend', 'ascend', 'ascend', 'ascend'});
closestCase = ranked(1, :);
end
