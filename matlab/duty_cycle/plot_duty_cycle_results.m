function plot_duty_cycle_results(cfg, continuousTable, summaryTable, bestCasesTable)
%PLOT_DUTY_CYCLE_RESULTS Generate report-ready duty-cycle figures.

resultsFigDir = cfg.paths.figures_dir;
lineWidth = 1.6;
sweepLabel = sprintf('Sweep mode: %s', cfg.sweep.active_mode_label);
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
plot_feasibility_maps(resultsFigDir, summaryTable, sweepLabel);
plot_altitude_drop_vs_toff(resultsFigDir, summaryTable, cfg.sim.altitude_tolerance_m, sweepLabel, lineWidth);
plot_energy_cycle_comparison(resultsFigDir, bestByBuoyancy, closestCase, noFeasible, sweepLabel);
plot_best_case_summary(resultsFigDir, bestCasesTable, closestCase, noFeasible);
plot_buoyancy_feasibility_boundary(resultsFigDir, summaryTable, sweepLabel, lineWidth);
plot_best_improvement_curves(resultsFigDir, summaryTable, sweepLabel, lineWidth);
plot_power_reduction_curve_with_optimum(resultsFigDir, summaryTable, sweepLabel, lineWidth);
plot_off_fraction_vs_power_reduction(resultsFigDir, summaryTable, sweepLabel);

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

function plot_feasibility_maps(resultsFigDir, summaryTable, sweepLabel)
selectedBR = [0.90, 0.95, 0.98, 0.99, 0.995];
selectedBR = select_available_ratios(summaryTable.buoyancy_ratio, selectedBR);

figOverview = figure('Color', 'w', 'Visible', 'off');
numTiles = max(numel(selectedBR), 1);
t = tiledlayout(figOverview, ceil(numTiles / 2), 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numTiles
    nexttile(t);
    if isempty(selectedBR)
        axis off;
        text(0.5, 0.5, 'No selected buoyancy ratios available.', 'HorizontalAlignment', 'center');
        continue;
    end
    br = selectedBR(i);
    map = build_feasibility_map(summaryTable, br);
    imagesc(map.toffVals, map.tonVals, map.feasiblePercent);
    axis xy;
    caxis([0 100]);
    colormap(parula);
    colorbar;
    xlabel('T_{off} [s]');
    ylabel('T_{on} [s]');
    title(sprintf('BR = %.3f', br));

    % Save separate readable maps for each selected ratio.
    figSingle = figure('Color', 'w', 'Visible', 'off');
    imagesc(map.toffVals, map.tonVals, map.feasiblePercent);
    axis xy;
    caxis([0 100]);
    colormap(parula);
    colorbar;
    xlabel('T_{off} [s]');
    ylabel('T_{on} [s]');
    title(sprintf('Duty-Cycle Feasibility Map (BR = %.3f)', br));
    subtitle(sweepLabel);
    fileSuffix = strrep(sprintf('%.3f', br), '.', 'p');
    exportgraphics(figSingle, fullfile(resultsFigDir, sprintf('duty_cycle_feasibility_map_BR_%s.png', fileSuffix)));
    close(figSingle);
end

title(t, 'Duty-Cycle Feasibility Map (Selected Buoyancy Ratios)');
subtitle(t, sweepLabel);
exportgraphics(figOverview, fullfile(resultsFigDir, 'duty_cycle_feasibility_map.png'));
close(figOverview);
end

function map = build_feasibility_map(summaryTable, buoyancyRatio)
subset = summaryTable(summaryTable.buoyancy_ratio == buoyancyRatio, :);
tonVals = unique(subset.T_on_s);
toffVals = unique(subset.T_off_s);
feasiblePercent = nan(numel(tonVals), numel(toffVals));

for r = 1:numel(tonVals)
    for c = 1:numel(toffVals)
        m = subset.T_on_s == tonVals(r) & subset.T_off_s == toffVals(c);
        if any(m)
            feasiblePercent(r, c) = 100.0 * sum(subset.feasible(m)) / sum(m);
        end
    end
end

map = struct('tonVals', tonVals, 'toffVals', toffVals, 'feasiblePercent', feasiblePercent);
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
title(sprintf('Altitude Drop vs T_{off} (T_{on}=%.2f s, nominal eta, medium startup)', targetTon));
subtitle(sweepLabel);
legend('Location', 'best');

allDrop = subset.altitude_drop_m;
if isempty(allDrop)
    ylim([0, max(altitudeTolerance_m * 1.2, 0.5)]);
else
    yCap = max(altitudeTolerance_m * 1.2, 0.3);
    ylim([0, yCap]);
end

exportgraphics(fig, fullfile(resultsFigDir, 'altitude_drop_vs_toff.png'));
close(fig);
end

function plot_energy_cycle_comparison(resultsFigDir, bestByBuoyancy, closestCase, noFeasible, sweepLabel)
fig = figure('Color', 'w', 'Visible', 'off');
if noFeasible
    x = categorical({'Closest case'});
    y = [closestCase.E_cont_cycle_J, closestCase.E_duty_cycle_J];
    bar(x, y);
    legend({'Continuous cycle energy', 'Duty-cycle energy'}, 'Location', 'best');
    title('Energy Per Cycle Comparison: Closest Case');
    subtitle({sweepLabel, 'No feasible duty-cycle case found. Closest case shown.'});
else
    if isempty(bestByBuoyancy)
        create_placeholder_figure(fig, 'Energy Per Cycle Comparison', 'No feasible duty-cycle cases found under current assumptions.');
        exportgraphics(fig, fullfile(resultsFigDir, 'energy_per_cycle_comparison.png'));
        close(fig);
        return;
    end
    x = categorical(string(bestByBuoyancy.buoyancy_ratio));
    y = [bestByBuoyancy.E_cont_cycle_J, bestByBuoyancy.E_duty_cycle_J];
    bar(x, y);
    legend({'Continuous cycle energy', 'Duty-cycle energy'}, 'Location', 'best');
    title('Energy Per Cycle Comparison: Best Feasible Cases');
    subtitle(sweepLabel);
end
grid on;
xlabel('Buoyancy ratio [-]');
ylabel('Energy per cycle [J]');
exportgraphics(fig, fullfile(resultsFigDir, 'energy_per_cycle_comparison.png'));
close(fig);
end

function plot_best_case_summary(resultsFigDir, bestCasesTable, closestCase, noFeasible)
fig = figure('Color', 'w', 'Visible', 'off');
ax = axes(fig);
if noFeasible
    bar(ax, categorical({'Continuous total power', 'Duty-cycle total power'}), [closestCase.P_cont_total_W, closestCase.P_duty_total_W]);
    ylabel(ax, 'Power [W]');
    title(ax, 'Best Feasible Duty-Cycle Power Comparison');
    subtitle(ax, 'No feasible case found; closest infeasible case shown.');
    grid(ax, 'on');
else
    overallBest = bestCasesTable(1, :);
    bar(ax, categorical({'Continuous total power', 'Duty-cycle total power'}), [overallBest.P_cont_total_W, overallBest.P_duty_total_W]);
    ylabel(ax, 'Power [W]');
    title(ax, 'Best Feasible Duty-Cycle Power Comparison');
    grid(ax, 'on');
end
annotation(fig, 'textbox', [0.16 0.01 0.7 0.06], 'String', ...
    'Endurance change is derived from average power reduction.', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontAngle', 'italic');
exportgraphics(fig, fullfile(resultsFigDir, 'best_case_summary.png'));
close(fig);
end

function plot_buoyancy_feasibility_boundary(resultsFigDir, summaryTable, sweepLabel, lineWidth)
feasibilityByBuoyancy = build_feasibility_by_buoyancy(summaryTable);
fig = figure('Color', 'w', 'Visible', 'off');
plot(feasibilityByBuoyancy.buoyancy_ratio, feasibilityByBuoyancy.feasible_percent, '-o', 'LineWidth', lineWidth);
hold on;
firstFeasible = feasibilityByBuoyancy.buoyancy_ratio(find(feasibilityByBuoyancy.feasible_percent > 0, 1, 'first'));
if ~isempty(firstFeasible)
    xline(firstFeasible, '--r', sprintf('First feasible BR=%.3f', firstFeasible), 'LineWidth', 1.2);
else
    text(0.5, 0.9, 'No feasible duty-cycle cases found under current assumptions.', 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
hold off;
grid on;
xlabel('Buoyancy ratio [-]');
ylabel('Feasible cases [%]');
title('Buoyancy Feasibility Boundary');
subtitle(sweepLabel);
exportgraphics(fig, fullfile(resultsFigDir, 'buoyancy_feasibility_boundary.png'));
close(fig);
end

function plot_best_improvement_curves(resultsFigDir, summaryTable, sweepLabel, lineWidth)
feasibilityByBuoyancy = build_feasibility_by_buoyancy(summaryTable);
feasibleSummary = feasibilityByBuoyancy(feasibilityByBuoyancy.feasible_cases > 0, :);

fig2 = figure('Color', 'w', 'Visible', 'off');
if ~isempty(feasibleSummary)
    plot(feasibleSummary.buoyancy_ratio, feasibleSummary.best_power_reduction_percent, '-d', 'LineWidth', lineWidth);
    yline(0, '--k', '0% reduction', 'LineWidth', 1.0);
else
    create_placeholder_figure(fig2, 'Best Power Reduction vs Buoyancy Ratio', ...
        'No feasible duty-cycle cases found under current assumptions.');
end
grid on;
xlabel('Buoyancy ratio [-]');
ylabel('Best power reduction [%]');
if ~isempty(feasibleSummary)
    title('Best Power Reduction vs Buoyancy Ratio');
    subtitle(sweepLabel);
end
exportgraphics(fig2, fullfile(resultsFigDir, 'best_power_reduction_vs_buoyancy_ratio.png'));
close(fig2);
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
        markerLabel = 'Best case at lower boundary';
    elseif abs(bestBR - maxBR) < 1e-12
        markerStyle = '^';
        markerLabel = 'Best case at upper boundary';
    else
        markerStyle = 'p';
        markerLabel = 'Best case within sweep range';
    end

    plot(bestBR, bestVal, markerStyle, 'MarkerSize', 12, 'MarkerFaceColor', [0.85 0.20 0.10], ...
        'MarkerEdgeColor', [0.30 0.10 0.05], 'DisplayName', markerLabel);
end

hold off;
grid on;
xlabel('Buoyancy ratio [-]');
ylabel('Best total power reduction [%]');
title('Best Duty-Cycle Power Reduction vs Buoyancy Ratio');
subtitle(sweepLabel);
legend('Location', 'best');

exportgraphics(fig, fullfile(resultsFigDir, 'power_reduction_curve_with_optimum.png'));
close(fig);
end

function plot_off_fraction_vs_power_reduction(resultsFigDir, summaryTable, sweepLabel)
fig = figure('Color', 'w', 'Visible', 'off');
feasibleRows = summaryTable(summaryTable.feasible, :);

if isempty(feasibleRows)
    create_placeholder_figure(fig, 'Off-Fraction vs Power Reduction', 'No feasible duty-cycle cases found under current assumptions.');
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
        % Keep derived endurance for downstream tables, but plots are power-first.
        best_power_reduction_percent(i) = max(feasibleRows.total_power_reduction_percent);
    end
end

feasibilityByBuoyancy = table(uniqueBuoyancy, feasible_cases, feasible_percent, ...
    best_power_reduction_percent, ...
    'VariableNames', {'buoyancy_ratio', 'feasible_cases', 'feasible_percent', ...
    'best_power_reduction_percent'});
end

function selected = select_available_ratios(allRatios, preferred)
selected = [];
for i = 1:numel(preferred)
    [minDiff, idx] = min(abs(allRatios - preferred(i))); %#ok<ASGLU>
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
[~, idx] = min(abs(unique(tonValues) - 0.2));
vals = unique(tonValues);
ton = vals(idx);
end

function create_placeholder_figure(figHandle, titleText, messageText)
figure(figHandle);
clf(figHandle);
axes('Position', [0 0 1 1], 'Visible', 'off');
text(0.5, 0.55, titleText, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 12);
text(0.5, 0.45, messageText, 'HorizontalAlignment', 'center', 'FontSize', 11);
end
