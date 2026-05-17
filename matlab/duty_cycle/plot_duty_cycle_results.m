function plot_duty_cycle_results(cfg, continuousTable, summaryTable, bestCasesTable, validBRRangesTable)
%PLOT_DUTY_CYCLE_RESULTS Generate duty-cycle figures.

resultsFigDir = cfg.paths.figures_dir;
lineWidth = 1.6;
sweepLabel = sprintf('Sweep mode: %s', cfg.sweep.active_mode_label);

if ~isfield(cfg, 'output')
    cfg.output.write_debug_figures = false;
end
if ~isfield(cfg.output, 'write_debug_figures')
    cfg.output.write_debug_figures = false;
end

% Core figures.
plot_valid_br_range_by_duty_definition(resultsFigDir, validBRRangesTable);
plot_power_reduction_curve_with_optimum(resultsFigDir, summaryTable, sweepLabel, lineWidth);
plot_altitude_margin_vs_buoyancy_ratio(resultsFigDir, summaryTable, sweepLabel, lineWidth);
plot_absolute_power_comparison(resultsFigDir, summaryTable, validBRRangesTable, sweepLabel, lineWidth);

% Optional debug figures.
if cfg.output.write_debug_figures
    noFeasible = ~any(summaryTable.feasible);
    nominalMask = strcmpi(string(continuousTable.eta_case), "nominal");
    if any(nominalMask)
        continuousNominal = continuousTable(nominalMask, :);
    else
        continuousNominal = continuousTable;
    end

    bestByBuoyancy = get_best_feasible_by_buoyancy(bestCasesTable);
    closestCase = get_closest_case(summaryTable);

    plot_power_vs_buoyancy(resultsFigDir, continuousNominal, bestByBuoyancy, noFeasible, sweepLabel, lineWidth);
    plot_altitude_drop_vs_toff(resultsFigDir, summaryTable, cfg.sim.altitude_tolerance_m, sweepLabel, lineWidth);
    plot_best_case_summary(resultsFigDir, bestCasesTable, closestCase, noFeasible);
    plot_buoyancy_feasibility_boundary(resultsFigDir, summaryTable, sweepLabel, lineWidth);
    plot_off_fraction_vs_power_reduction(resultsFigDir, summaryTable, sweepLabel);
end

end

function plot_altitude_margin_vs_buoyancy_ratio(resultsFigDir, summaryTable, sweepLabel, lineWidth)
fig = figure('Color', 'w', 'Visible', 'off');
feasibleRows = summaryTable(summaryTable.feasible, :);
altitudeFailRows = summaryTable(~summaryTable.altitude_pass, :);

hold on;
if ~isempty(feasibleRows)
    scatter(feasibleRows.buoyancy_ratio, feasibleRows.altitude_margin_m, 20, 'o', 'filled', ...
        'DisplayName', 'Feasible cases');
end
if ~isempty(altitudeFailRows)
    scatter(altitudeFailRows.buoyancy_ratio, altitudeFailRows.altitude_margin_m, 22, 'x', ...
        'DisplayName', 'Altitude-failed cases');
end
yline(0, '--k', '0 m margin', 'LineWidth', lineWidth, 'DisplayName', '0 m margin');
hold off;
grid on;
xlabel('Buoyancy ratio [-]');
ylabel('Altitude margin [m]');
title('Altitude Margin vs Buoyancy Ratio');
subtitle(sweepLabel);
legend('Location', 'best');

exportgraphics(fig, fullfile(resultsFigDir, 'altitude_margin_vs_buoyancy_ratio.png'));
close(fig);
end

function plot_power_reduction_curve_with_optimum(resultsFigDir, summaryTable, sweepLabel, lineWidth)
feasibilityByBuoyancy = build_feasibility_by_buoyancy(summaryTable);
fig = figure('Color', 'w', 'Visible', 'off');

plot(feasibilityByBuoyancy.buoyancy_ratio, feasibilityByBuoyancy.best_power_reduction_percent, '-d', 'LineWidth', lineWidth, ...
    'DisplayName', 'Best feasible power reduction by buoyancy ratio');
hold on;
yline(0, '--k', '0% reduction', 'LineWidth', 1.0, 'DisplayName', '0% reduction');

feasibleCurve = feasibilityByBuoyancy(~isnan(feasibilityByBuoyancy.best_power_reduction_percent), :);
if ~isempty(feasibleCurve)
    [bestVal, bestIdx] = max(feasibleCurve.best_power_reduction_percent);
    bestBR = feasibleCurve.buoyancy_ratio(bestIdx);

    minBR = min(feasibilityByBuoyancy.buoyancy_ratio);
    maxBR = max(feasibilityByBuoyancy.buoyancy_ratio);
    if abs(bestBR - minBR) < 1e-12
        markerStyle = 'v';
        markerLabel = 'Best relative saving at lower boundary';
    elseif abs(bestBR - maxBR) < 1e-12
        markerStyle = '^';
        markerLabel = 'Best relative saving at upper boundary';
    else
        markerStyle = 'p';
        markerLabel = 'Best relative saving within sweep';
    end

    plot(bestBR, bestVal, markerStyle, 'MarkerSize', 12, 'MarkerFaceColor', [0.85 0.20 0.10], ...
        'MarkerEdgeColor', [0.30 0.10 0.05], 'DisplayName', markerLabel);
end

hold off;
grid on;
xlabel('Buoyancy ratio [-]');
ylabel('Best total power reduction [%]');
title('Best Relative Saving by Buoyancy Ratio');
subtitle(sweepLabel);
legend('Location', 'best');

exportgraphics(fig, fullfile(resultsFigDir, 'power_reduction_curve_with_optimum.png'));
close(fig);
end

function plot_valid_br_range_by_duty_definition(resultsFigDir, validBRRangesTable)
fig = figure('Color', 'w', 'Visible', 'off');
ax = axes(fig);
hold(ax, 'on');

categories = {'all_feasible_cases', 'short_break_pulsing', 'moderate_duty_cycle', 'strong_duty_cycle'};
yLabels = {'All feasible', 'Short-break', 'Moderate duty', 'Strong duty'};

for i = 1:numel(categories)
    match = strcmp(string(validBRRangesTable.category), categories{i});
    if ~any(match)
        continue;
    end
    row = validBRRangesTable(find(match, 1, 'first'), :);
    y = numel(categories) - i + 1;

    if ~isnan(row.lowest_valid_BR) && ~isnan(row.highest_valid_BR)
        plot(ax, [row.lowest_valid_BR, row.highest_valid_BR], [y, y], '-', 'LineWidth', 8, ...
            'Color', [0.20 0.45 0.75]);
        plot(ax, row.lowest_valid_BR, y, 'o', 'MarkerFaceColor', [0.15 0.65 0.35], ...
            'MarkerEdgeColor', 'k', 'MarkerSize', 7);
        plot(ax, row.highest_valid_BR, y, 's', 'MarkerFaceColor', [0.85 0.35 0.25], ...
            'MarkerEdgeColor', 'k', 'MarkerSize', 7);
    end
end

hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Buoyancy ratio [-]');
ylabel(ax, 'Duty-cycle definition');
set(ax, 'YTick', 1:numel(categories), 'YTickLabel', fliplr(yLabels));
title(ax, 'Valid Buoyancy-Ratio Range for Duty-Cycled Thrust');
subtitle(ax, 'Valid = power reduction + physical constraints + duty-cycle definition');
xlim(ax, [0.0, 1.0]);
ylim(ax, [0.5, numel(categories) + 0.5]);

exportgraphics(fig, fullfile(resultsFigDir, 'valid_BR_range_by_duty_definition.png'));
close(fig);
end

function plot_absolute_power_comparison(resultsFigDir, summaryTable, validBRRangesTable, sweepLabel, lineWidth)
fig = figure('Color', 'w', 'Visible', 'off');
ax = axes(fig);
hold(ax, 'on');

source = summaryTable(~summaryTable.is_idealized_neutral_reference, :);
if isempty(source)
    source = summaryTable;
end

contCurve = groupsummary(source, 'buoyancy_ratio', 'min', 'P_cont_total_W');
contCurve = sortrows(contCurve, 'buoyancy_ratio');
plot(ax, contCurve.buoyancy_ratio, contCurve.min_P_cont_total_W, '-o', 'LineWidth', lineWidth, ...
    'DisplayName', 'Continuous total power');

moderateValid = source(source.feasible_moderate_duty, :);
if ~isempty(moderateValid)
    modCurve = groupsummary(moderateValid, 'buoyancy_ratio', 'min', 'P_duty_total_W');
    modCurve = sortrows(modCurve, 'buoyancy_ratio');
    plot(ax, modCurve.buoyancy_ratio, modCurve.min_P_duty_total_W, '-s', 'LineWidth', lineWidth, ...
        'DisplayName', 'Lowest valid moderate duty-cycle power');

    [minDuty, idxDuty] = min(modCurve.min_P_duty_total_W);
    minDutyBR = modCurve.buoyancy_ratio(idxDuty);
    plot(ax, minDutyBR, minDuty, 'p', 'MarkerSize', 12, 'MarkerFaceColor', [0.85 0.30 0.20], ...
        'MarkerEdgeColor', [0.30 0.10 0.05], 'DisplayName', 'Lowest valid moderate duty-cycle power');
end

[minCont, idxCont] = min(contCurve.min_P_cont_total_W);
minContBR = contCurve.buoyancy_ratio(idxCont);
plot(ax, minContBR, minCont, '^', 'MarkerSize', 11, 'MarkerFaceColor', [0.15 0.45 0.80], ...
    'MarkerEdgeColor', [0.05 0.20 0.35], 'DisplayName', 'Lowest continuous total power');

modRange = validBRRangesTable(strcmp(string(validBRRangesTable.category), "moderate_duty_cycle"), :);
if ~isempty(modRange) && ~isnan(modRange.lowest_valid_BR)
    xline(ax, modRange.lowest_valid_BR, '--', 'Color', [0.20 0.20 0.20], 'LineWidth', 1.2, ...
        'DisplayName', 'Moderate valid BR lower bound');
    xline(ax, modRange.highest_valid_BR, '--', 'Color', [0.20 0.20 0.20], 'LineWidth', 1.2, ...
        'DisplayName', 'Moderate valid BR upper bound');
end

hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Buoyancy ratio [-]');
ylabel(ax, 'Total power [W]');
title(ax, 'Absolute Power Comparison: Continuous vs Valid Duty-Cycled Thrust');
subtitle(ax, { ...
    'Power reduction indicates relative benefit; absolute minimum power may occur under continuous low-thrust operation.', ...
    sweepLabel});
legend(ax, 'Location', 'best');

exportgraphics(fig, fullfile(resultsFigDir, 'absolute_power_comparison.png'));
close(fig);
end

function feasibilityByBuoyancy = build_feasibility_by_buoyancy(summaryTable)
uniqueBuoyancy = unique(summaryTable.buoyancy_ratio);
numRows = numel(uniqueBuoyancy);
feasible_percent = zeros(numRows, 1);
feasible_cases = zeros(numRows, 1);
best_power_reduction_percent = nan(numRows, 1);

for i = 1:numRows
    rows = summaryTable(summaryTable.buoyancy_ratio == uniqueBuoyancy(i), :);
    feasibleRows = rows(rows.feasible, :);
    feasible_cases(i) = height(feasibleRows);
    feasible_percent(i) = 100.0 * feasible_cases(i) / max(height(rows), 1);
    if ~isempty(feasibleRows)
        best_power_reduction_percent(i) = max(feasibleRows.total_power_reduction_percent);
    end
end

feasibilityByBuoyancy = table(uniqueBuoyancy, feasible_cases, feasible_percent, ...
    best_power_reduction_percent, ...
    'VariableNames', {'buoyancy_ratio', 'feasible_cases', 'feasible_percent', 'best_power_reduction_percent'});
end

function bestByBuoyancy = get_best_feasible_by_buoyancy(bestCasesTable)
bestByBuoyancy = table();
if isempty(bestCasesTable)
    return;
end
uniqueBR = unique(bestCasesTable.buoyancy_ratio);
keepRows = false(height(bestCasesTable), 1);
for i = 1:numel(uniqueBR)
    rows = find(bestCasesTable.buoyancy_ratio == uniqueBR(i));
    [~, localIdx] = max(bestCasesTable.total_power_reduction_percent(rows));
    keepRows(rows(localIdx)) = true;
end
bestByBuoyancy = sortrows(bestCasesTable(keepRows, :), 'buoyancy_ratio');
end

function closestCase = get_closest_case(summaryTable)
ranked = summaryTable;
ranked.total_power_penalty_W = ranked.P_duty_total_W - ranked.P_cont_total_W;
ranked = sortrows(ranked, {'failed_check_count', 'total_power_penalty_W', 'altitude_drop_m', 'P_on_required_W'}, ...
    {'ascend', 'ascend', 'ascend', 'ascend'});
closestCase = ranked(1, :);
end

function plot_power_vs_buoyancy(resultsFigDir, continuousNominal, bestByBuoyancy, noFeasible, sweepLabel, lineWidth)
fig = figure('Color', 'w', 'Visible', 'off');
plot(continuousNominal.buoyancy_ratio, continuousNominal.P_cont_propulsion_W, '-o', 'LineWidth', lineWidth, ...
    'DisplayName', 'Continuous propulsion power');
hold on;
plot(continuousNominal.buoyancy_ratio, continuousNominal.P_cont_total_W, '-s', 'LineWidth', lineWidth, ...
    'DisplayName', 'Continuous total power');

if ~isempty(bestByBuoyancy)
    plot(bestByBuoyancy.buoyancy_ratio, bestByBuoyancy.P_duty_propulsion_avg_W, '--^', 'LineWidth', lineWidth, ...
        'DisplayName', 'Duty-cycle propulsion (best feasible)');
    plot(bestByBuoyancy.buoyancy_ratio, bestByBuoyancy.P_duty_total_W, '--d', 'LineWidth', lineWidth, ...
        'DisplayName', 'Duty-cycle total (best feasible)');
end

hold off;
grid on;
xlabel('Buoyancy ratio [-]');
ylabel('Power [W] (propulsion and total)');
title('Power vs Buoyancy Ratio');
if noFeasible
    subtitle({sweepLabel, 'No feasible duty-cycle cases found.'});
else
    subtitle(sweepLabel);
end
legend('Location', 'best');
exportgraphics(fig, fullfile(resultsFigDir, 'power_vs_buoyancy_ratio.png'));
close(fig);
end

function plot_altitude_drop_vs_toff(resultsFigDir, summaryTable, altitudeTolerance_m, sweepLabel, lineWidth)
selectedBR = [0.90, 0.95, 0.98, 0.99, 0.995];
selectedBR = select_available_ratios(summaryTable.buoyancy_ratio, selectedBR);

nominalMask = strcmpi(string(summaryTable.eta_case), "nominal") & abs(summaryTable.startup_energy_J - 0.05) < 1e-12;
subset = summaryTable(nominalMask, :);
if isempty(subset)
    subset = summaryTable;
end

targetTon = pick_representative_ton(subset.T_on_s);
subset = subset(abs(subset.T_on_s - targetTon) < 1e-12, :);

fig = figure('Color', 'w', 'Visible', 'off');
hold on;
for i = 1:numel(selectedBR)
    br = selectedBR(i);
    rows = subset(abs(subset.buoyancy_ratio - br) < 1e-12, :);
    if isempty(rows)
        continue;
    end
    toffVals = unique(rows.T_off_s);
    minDrop = nan(size(toffVals));
    for k = 1:numel(toffVals)
        mk = rows.T_off_s == toffVals(k);
        minDrop(k) = min(rows.altitude_drop_m(mk));
    end
    [toffValsSorted, order] = sort(toffVals);
    minDropSorted = minDrop(order);
    plot(toffValsSorted, minDropSorted, '-o', 'LineWidth', lineWidth, 'DisplayName', sprintf('BR=%.3f', br));
end

yline(altitudeTolerance_m, '--r', sprintf('Altitude tolerance = %.2f m', altitudeTolerance_m), 'LineWidth', 1.2);
hold off;
grid on;
xlabel('T_{off} [s]');
ylabel('Minimum altitude drop [m]');
title(sprintf('Altitude Drop vs T_{off} (T_{on}=%.2f s)', targetTon));
subtitle(sweepLabel);
legend('Location', 'best');

exportgraphics(fig, fullfile(resultsFigDir, 'altitude_drop_vs_toff.png'));
close(fig);
end

function plot_best_case_summary(resultsFigDir, bestCasesTable, closestCase, noFeasible)
fig = figure('Color', 'w', 'Visible', 'off');
ax = axes(fig);
if noFeasible
    bar(ax, categorical({'Continuous total power', 'Duty-cycle total power'}), [closestCase.P_cont_total_W, closestCase.P_duty_total_W]);
    ylabel(ax, 'Power [W]');
    title(ax, 'Debug Power Comparison');
    subtitle(ax, 'No feasible case found; closest infeasible case shown.');
else
    overallBest = bestCasesTable(1, :);
    bar(ax, categorical({'Continuous total power', 'Duty-cycle total power'}), [overallBest.P_cont_total_W, overallBest.P_duty_total_W]);
    ylabel(ax, 'Power [W]');
    title(ax, 'Debug Power Comparison');
end
grid(ax, 'on');
exportgraphics(fig, fullfile(resultsFigDir, 'best_case_summary.png'));
close(fig);
end

function plot_buoyancy_feasibility_boundary(resultsFigDir, summaryTable, sweepLabel, lineWidth)
feasibilityByBuoyancy = build_feasibility_by_buoyancy(summaryTable);
fig = figure('Color', 'w', 'Visible', 'off');
plot(feasibilityByBuoyancy.buoyancy_ratio, feasibilityByBuoyancy.feasible_percent, '-o', 'LineWidth', lineWidth);
grid on;
xlabel('Buoyancy ratio [-]');
ylabel('Feasible cases [%]');
title('Buoyancy Feasibility Boundary');
subtitle(sweepLabel);
exportgraphics(fig, fullfile(resultsFigDir, 'buoyancy_feasibility_boundary.png'));
close(fig);
end

function plot_off_fraction_vs_power_reduction(resultsFigDir, summaryTable, sweepLabel)
fig = figure('Color', 'w', 'Visible', 'off');
feasibleRows = summaryTable(summaryTable.feasible, :);

if isempty(feasibleRows)
    text(0.5, 0.5, 'No feasible duty-cycle cases found under current assumptions.', ...
        'HorizontalAlignment', 'center');
    axis off;
else
    scatter(feasibleRows.off_fraction, feasibleRows.total_power_reduction_percent, 18, feasibleRows.buoyancy_ratio, 'filled');
    cb = colorbar;
    cb.Label.String = 'Buoyancy ratio [-]';
    grid on;
    xlabel('Off fraction [-]');
    ylabel('Total power reduction [%]');
    title('Off Fraction vs Total Power Reduction (Feasible Cases)');
    subtitle(sweepLabel);
end

exportgraphics(fig, fullfile(resultsFigDir, 'off_fraction_vs_power_reduction.png'));
close(fig);
end

function selected = select_available_ratios(allRatios, preferred)
selected = [];
for i = 1:numel(preferred)
    [~, idx] = min(abs(allRatios - preferred(i)));
    if ~isempty(idx)
        selected = [selected; allRatios(idx)]; %#ok<AGROW>
    end
end
selected = unique(selected, 'stable');
end

function ton = pick_representative_ton(tonValues)
if isempty(tonValues)
    ton = 0.2;
    return;
end
vals = unique(tonValues);
[~, idx] = min(abs(vals - 0.2));
ton = vals(idx);
end
