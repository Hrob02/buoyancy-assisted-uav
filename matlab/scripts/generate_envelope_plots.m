function generate_envelope_plots(cfg, decisionMatrix, rankingRobustness, paretoTable)
%GENERATE_ENVELOPE_PLOTS Create report-facing envelope geometry figures.

create_metric_comparison_plot(cfg, decisionMatrix);
create_decision_score_plot(cfg, decisionMatrix);
create_sensitivity_ranking_plot(cfg, rankingRobustness);
create_pareto_plot(cfg, decisionMatrix, paretoTable);
create_geometry_dimensions_plot(cfg, decisionMatrix);

end

function create_metric_comparison_plot(cfg, decisionMatrix)
figureHandle = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 700]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

sortedTable = sortrows(decisionMatrix, 'rank');
shapeLabels = cellstr(sortedTable.shape);

nexttile;
bar(sortedTable.surface_area_to_volume_1_m, 'FaceColor', [0.16 0.45 0.70]);
set(gca, 'XTick', 1:height(sortedTable), 'XTickLabel', shapeLabels);
ylabel('SA/V [1/m]');
title('Material Efficiency');
grid on;

nexttile;
bar(sortedTable.estimated_net_lift_after_envelope_mass_g, 'FaceColor', [0.21 0.63 0.37]);
set(gca, 'XTick', 1:height(sortedTable), 'XTickLabel', shapeLabels);
ylabel('Estimated net lift after envelope mass [g]');
title('Useful Lift Estimate');
grid on;

nexttile;
bar(sortedTable.disturbance_stability_index, 'FaceColor', [0.85 0.33 0.10]);
set(gca, 'XTick', 1:height(sortedTable), 'XTickLabel', shapeLabels);
ylabel('Disturbance stability index [-]');
title('Disturbance Response');
grid on;

nexttile;
bar(sortedTable.spatial_footprint_m2, 'FaceColor', [0.49 0.18 0.56]);
set(gca, 'XTick', 1:height(sortedTable), 'XTickLabel', shapeLabels);
ylabel('Spatial footprint [m^2]');
title('Spatial Compactness');
grid on;

sgtitle('Envelope Geometry Design-Screening Metrics');
safe_export_figure(figureHandle, fullfile(cfg.paths.figures_dir, 'envelope_metric_comparison.png'));
close(figureHandle);
end

function create_decision_score_plot(cfg, decisionMatrix)
figureHandle = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 500]);
sortedTable = sortrows(decisionMatrix, 'weighted_total_score');
barh(sortedTable.weighted_total_score, 'FaceColor', [0.23 0.51 0.96]);
set(gca, 'YDir', 'reverse', 'YTick', 1:height(sortedTable), 'YTickLabel', cellstr(sortedTable.shape));
xlabel('Weighted total score [-]');
title('Envelope Decision Score (Lower Is Better)');
grid on;
safe_export_figure(figureHandle, fullfile(cfg.paths.figures_dir, 'envelope_decision_score.png'));
close(figureHandle);
end

function create_sensitivity_ranking_plot(cfg, rankingRobustness)
figureHandle = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 500]);
data = [rankingRobustness.percentage_of_sweep_cases_ranked_first, ...
    rankingRobustness.percentage_of_sweep_cases_ranked_second];
bar(data, 'stacked');
set(gca, 'XTick', 1:height(rankingRobustness), 'XTickLabel', cellstr(rankingRobustness.shape));
ylabel('Sweep-case share [%]');
legend({'Ranked first', 'Ranked second'}, 'Location', 'northeast');
title('Sensitivity Ranking Robustness');
grid on;
safe_export_figure(figureHandle, fullfile(cfg.paths.figures_dir, 'envelope_sensitivity_ranking.png'));
close(figureHandle);
end

function create_pareto_plot(cfg, decisionMatrix, paretoTable)
figureHandle = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 650]);
hold on;

markerArea = 4000 * (decisionMatrix.spatial_footprint_m2 ./ max(decisionMatrix.spatial_footprint_m2));
isDominated = paretoTable.is_pareto_dominated;

scatter(decisionMatrix.surface_area_to_volume_1_m(~isDominated), ...
    decisionMatrix.disturbance_stability_index(~isDominated), markerArea(~isDominated), ...
    'filled', 'MarkerFaceColor', [0.18 0.56 0.28], 'MarkerEdgeColor', 'k');
scatter(decisionMatrix.surface_area_to_volume_1_m(isDominated), ...
    decisionMatrix.disturbance_stability_index(isDominated), markerArea(isDominated), ...
    'filled', 'MarkerFaceColor', [0.75 0.32 0.20], 'MarkerEdgeColor', 'k');

for rowIndex = 1:height(decisionMatrix)
    text(decisionMatrix.surface_area_to_volume_1_m(rowIndex) * 1.003, ...
        decisionMatrix.disturbance_stability_index(rowIndex) * 1.003, ...
        char(decisionMatrix.shape(rowIndex)), 'FontSize', 10);
end

xlabel('Surface-area-to-volume ratio [1/m]');
ylabel('Disturbance stability index [-]');
title('Pareto Screening of Envelope Shapes');
legend({'Pareto-efficient', 'Pareto-dominated'}, 'Location', 'best');
grid on;
hold off;
safe_export_figure(figureHandle, fullfile(cfg.paths.figures_dir, 'envelope_pareto_plot.png'));
close(figureHandle);
end

function create_geometry_dimensions_plot(cfg, decisionMatrix)
figureHandle = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1100 550]);
dimensionMatrix = [decisionMatrix.length_m, decisionMatrix.width_m, decisionMatrix.height_m];
bar(dimensionMatrix);
set(gca, 'XTick', 1:height(decisionMatrix), 'XTickLabel', cellstr(decisionMatrix.shape));
ylabel('Dimension [m]');
legend({'Length', 'Width', 'Height'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
title('Envelope Dimensions at Equal Required Helium Volume');
grid on;
safe_export_figure(figureHandle, fullfile(cfg.paths.figures_dir, 'envelope_geometry_dimensions.png'));
close(figureHandle);
end

function safe_export_figure(figureHandle, outputPath)
outputFolder = fileparts(outputPath);
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

exportgraphics(figureHandle, outputPath, 'Resolution', 220);
end