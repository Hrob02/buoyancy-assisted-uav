function run_envelope_geometry_analysis()
%RUN_ENVELOPE_GEOMETRY_ANALYSIS Deterministic envelope geometry design screening.

clc;
close all;

cfg = config_envelope_geometry_parameters();
ensure_output_directories(cfg);
clean_output_directories(cfg);

fprintf('=== Envelope Geometry Design-Screening Analysis ===\n');

[decisionMatrix, analysisMeta] = generate_envelope_decision_matrix( ...
    cfg, cfg.system.reference_mass_g, cfg.system.target_buoyancy_ratio, cfg.envelope.sigma_ref_kg_m2);
validate_baseline_results(decisionMatrix, cfg);

paretoTable = generate_pareto_analysis(decisionMatrix);
[selectedShape, nextBestShape, decisionMatrix] = determine_selected_shape(cfg, decisionMatrix);
engineeringSignificanceSummary = calculate_engineering_significance(cfg, decisionMatrix, selectedShape, nextBestShape);


[sensitivityResults, rankingRobustness] = run_envelope_sensitivity_analysis(cfg);
selectedRobustness = rankingRobustness(rankingRobustness.shape == string(selectedShape), :);
modelNotStronglyDistinguished = model_not_strongly_distinguished(engineeringSignificanceSummary, selectedShape, nextBestShape);
decisionMatrix = update_recommendation_notes(decisionMatrix, paretoTable, selectedShape, modelNotStronglyDistinguished);
write_core_outputs(cfg, decisionMatrix, engineeringSignificanceSummary, sensitivityResults, rankingRobustness, paretoTable);
generate_envelope_plots(cfg, decisionMatrix, rankingRobustness, paretoTable);
analysis.decision_matrix = decisionMatrix;
analysis.selected_shape = string(selectedShape);
analysis.next_best_shape = string(nextBestShape);
analysis.engineering_significance_summary = engineeringSignificanceSummary;
analysis.selected_shape_non_pareto_percent = selectedRobustness.percentage_non_pareto_dominated;
analysis.selected_shape_robustness_note = selectedRobustness.robustness_note{1};
analysis.pareto_result_text = pareto_result_text(paretoTable, selectedShape);
analysis.analysis_meta = analysisMeta;
write_envelope_recommendation_md(cfg, analysis);
print_console_summary(decisionMatrix, paretoTable, rankingRobustness, engineeringSignificanceSummary, selectedShape, nextBestShape);
fprintf('Results written to: %s\n', cfg.paths.results_dir);
fprintf('Figures written to: %s\n', cfg.paths.figures_dir);

end

function ensure_output_directories(cfg)
if ~exist(cfg.paths.results_dir, 'dir')
    mkdir(cfg.paths.results_dir);
end
if ~exist(cfg.paths.figures_dir, 'dir')
    mkdir(cfg.paths.figures_dir);
end
end

function clean_output_directories(cfg)
resultFiles = { ...
    'envelope_decision_matrix.csv', ...
    'envelope_engineering_significance_summary.csv', ...
    'envelope_sensitivity_results.csv', ...
    'envelope_ranking_robustness.csv', ...
    'envelope_pareto_analysis.csv', ...
    'envelope_shape_recommendation.md', ...
    'envelope_geometry_assumptions.md'};

figureFiles = { ...
    'envelope_metric_comparison.png', ...
    'envelope_sensitivity_metric_ranking.png', ...
    'envelope_sensitivity_ranking.png', ...
    'envelope_pareto_plot.png', ...
    'envelope_geometry_dimensions.png'};

for fileIndex = 1:numel(resultFiles)
    safe_delete_file(fullfile(cfg.paths.results_dir, resultFiles{fileIndex}));
end
for fileIndex = 1:numel(figureFiles)
    safe_delete_file(fullfile(cfg.paths.figures_dir, figureFiles{fileIndex}));
end
end

function validate_baseline_results(decisionMatrix, cfg)
requiredVolumes = decisionMatrix.required_volume_L;
assert(max(requiredVolumes) - min(requiredVolumes) < 1.0e-9, ...
    'EnvelopeGeometry:VolumeMismatch', ...
    'Required volume must be identical for every shape in the baseline comparison.');

dimensionMatrix = [decisionMatrix.length_m, decisionMatrix.width_m, decisionMatrix.height_m];
assert(all(dimensionMatrix > 0, 'all'), ...
    'EnvelopeGeometry:InvalidDimensions', ...
    'All envelope dimensions must be positive.');
assert(all(decisionMatrix.surface_area_m2 > 0), ...
    'EnvelopeGeometry:InvalidSurfaceArea', ...
    'All surface areas must be positive.');
assert(all(decisionMatrix.surface_area_to_volume_1_m > 0), ...
    'EnvelopeGeometry:InvalidSAV', ...
    'All surface-area-to-volume ratios must be positive.');
assert(all(isfinite(decisionMatrix.disturbance_stability_index)), ...
    'EnvelopeGeometry:InvalidDisturbanceIndex', ...
    'Disturbance stability index must be finite for all candidate shapes.');
assert(height(decisionMatrix) == numel(cfg.shapes), ...
    'EnvelopeGeometry:IncompleteRanking', ...
    'Ranking table must include every candidate shape.');
assert_no_subjective_practicality_columns(decisionMatrix);
end

function paretoTable = generate_pareto_analysis(decisionMatrix)
metricMatrix = [ ...
    decisionMatrix.surface_area_to_volume_1_m, ...
    decisionMatrix.disturbance_stability_index, ...
    decisionMatrix.max_dimension_m];

shapeCount = height(decisionMatrix);
dominated = false(shapeCount, 1);
dominatedBy = strings(shapeCount, 1);
paretoNote = strings(shapeCount, 1);

for rowIndex = 1:shapeCount
    dominatingShapes = strings(0, 1);
    for comparisonIndex = 1:shapeCount
        if rowIndex == comparisonIndex
            continue;
        end

        comparisonBetterOrEqual = all(metricMatrix(comparisonIndex, :) <= metricMatrix(rowIndex, :));
        comparisonStrictlyBetter = any(metricMatrix(comparisonIndex, :) < metricMatrix(rowIndex, :));
        if comparisonBetterOrEqual && comparisonStrictlyBetter
            dominated(rowIndex) = true;
            dominatingShapes(end + 1, 1) = decisionMatrix.shape(comparisonIndex); %#ok<AGROW>
        end
    end

    if dominated(rowIndex)
        dominatedBy(rowIndex) = strjoin(cellstr(dominatingShapes), '; ');
        paretoNote(rowIndex) = "Pareto-dominated: another shape is equal or better across SA/V, disturbance index, and maximum dimension, and strictly better in at least one.";
    else
        dominatedBy(rowIndex) = "";
        paretoNote(rowIndex) = "Not Pareto-dominated under SA/V, disturbance index, and maximum dimension.";
    end
end

paretoTable = table(decisionMatrix.shape, dominated, dominatedBy, paretoNote, ...
    'VariableNames', {'shape', 'is_pareto_dominated', 'dominated_by', 'pareto_note'});
end

function [selectedShape, nextBestShape, updatedDecisionMatrix] = determine_selected_shape(cfg, decisionMatrix)
updatedDecisionMatrix = decisionMatrix;

validMask = updatedDecisionMatrix.length_m > 0 & updatedDecisionMatrix.width_m > 0 & ...
    updatedDecisionMatrix.height_m > 0 & updatedDecisionMatrix.surface_area_m2 > 0 & ...
    updatedDecisionMatrix.surface_area_to_volume_1_m > 0 & isfinite(updatedDecisionMatrix.disturbance_stability_index);
eligibleMask = validMask & updatedDecisionMatrix.meets_size_limit;

if ~any(eligibleMask)
    error('EnvelopeGeometry:NoEligibleShapes', ...
        'No shapes satisfy validity and configured size-constraint checks.');
end

eligibleTable = updatedDecisionMatrix(eligibleMask, :);
eligiblePareto = generate_pareto_analysis(eligibleTable);
nonDominatedMask = ~eligiblePareto.is_pareto_dominated;
if any(nonDominatedMask)
    candidatePool = eligibleTable(nonDominatedMask, :);
else
    candidatePool = eligibleTable;
end

materialThresholdPercent = cfg.engineering_significance.material_efficiency_threshold_percent;
disturbanceThresholdPercent = cfg.engineering_significance.disturbance_threshold_percent;
sizeThresholdPercent = cfg.engineering_significance.size_threshold_percent;

tolerance = 1.0e-12;
bestSAV = min(candidatePool.surface_area_to_volume_1_m);
bestDisturbance = min(candidatePool.disturbance_stability_index);
bestMaxDimension = min(candidatePool.max_dimension_m);

isBestSAV = abs(candidatePool.surface_area_to_volume_1_m - bestSAV) <= tolerance;
isBestDisturbance = abs(candidatePool.disturbance_stability_index - bestDisturbance) <= tolerance;
isBestDimension = abs(candidatePool.max_dimension_m - bestMaxDimension) <= tolerance;

isNearBestSAV = candidatePool.surface_area_to_volume_1_m <= bestSAV * (1 + materialThresholdPercent / 100);
isNearBestDisturbance = candidatePool.disturbance_stability_index <= bestDisturbance * (1 + disturbanceThresholdPercent / 100);
isNearBestDimension = candidatePool.max_dimension_m <= bestMaxDimension * (1 + sizeThresholdPercent / 100);

bestMetricCount = double(isBestSAV) + double(isBestDisturbance) + double(isBestDimension);
nearBestMetricCount = double(isNearBestSAV) + double(isNearBestDisturbance) + double(isNearBestDimension);
diagnosticAverageRank = mean([candidatePool.rank_SA_V, candidatePool.rank_disturbance, candidatePool.rank_max_dimension], 2);

decisionTable = table(candidatePool.shape, bestMetricCount, nearBestMetricCount, diagnosticAverageRank, candidatePool.max_dimension_m, ...
    'VariableNames', {'shape', 'best_metric_count', 'near_best_metric_count', 'diagnostic_average_rank', 'max_dimension_m'});
decisionTable = sortrows(decisionTable, ...
    {'best_metric_count', 'near_best_metric_count', 'diagnostic_average_rank', 'max_dimension_m'}, ...
    {'descend', 'descend', 'ascend', 'ascend'});

selectedShape = decisionTable.shape(1);
if height(decisionTable) > 1
    nextBestShape = decisionTable.shape(2);
else
    nextBestShape = selectedShape;
end

updatedDecisionMatrix.recommendation_note = repmat("Not selected.", height(updatedDecisionMatrix), 1);
end

function modelNotStronglyDistinguished = model_not_strongly_distinguished(engineeringSignificanceSummary, selectedShape, comparisonShape)
comparisonRows = engineeringSignificanceSummary( ...
    engineeringSignificanceSummary.selected_shape == string(selectedShape) & ...
    engineeringSignificanceSummary.comparison_shape == string(comparisonShape), :);
if isempty(comparisonRows)
    modelNotStronglyDistinguished = false;
    return;
end

negligibleOrMarginal = comparisonRows.engineering_significance_category == "negligible" | ...
    comparisonRows.engineering_significance_category == "marginal";
modelNotStronglyDistinguished = all(negligibleOrMarginal);
end

function updatedDecisionMatrix = update_recommendation_notes(decisionMatrix, paretoTable, selectedShape, modelNotStronglyDistinguished)
updatedDecisionMatrix = decisionMatrix;
for rowIndex = 1:height(updatedDecisionMatrix)
    rowShape = updatedDecisionMatrix.shape(rowIndex);
    if rowShape == string(selectedShape)
        if modelNotStronglyDistinguished
            updatedDecisionMatrix.recommendation_note(rowIndex) = "Selected: non-Pareto-dominated and best/near-best across metrics; leading alternatives are close, so physical validation is recommended.";
        else
            updatedDecisionMatrix.recommendation_note(rowIndex) = "Selected: non-Pareto-dominated and best/near-best across SA/V, disturbance, and maximum dimension.";
        end
    elseif paretoTable.is_pareto_dominated(rowIndex)
        updatedDecisionMatrix.recommendation_note(rowIndex) = "Not preferred: Pareto-dominated under SA/V, disturbance index, and maximum dimension.";
    else
        updatedDecisionMatrix.recommendation_note(rowIndex) = "Competitive: non-Pareto-dominated but not selected after metric-by-metric comparison.";
    end
end
end


function write_core_outputs(cfg, decisionMatrix, engineeringSignificanceSummary, sensitivityResults, rankingRobustness, paretoTable)
decisionOutput = removevars(decisionMatrix, {'meets_required_volume', 'meets_size_limit', ...
    'estimated_net_lift_after_envelope_mass_N_internal', 'estimated_envelope_material_mass_kg', ...
    'estimated_net_lift_after_envelope_mass_g', 'bounding_box_volume_m3', 'recommendation_note'});

requiredColumnOrder = { ...
    'shape', ...
    'required_volume_L', ...
    'length_m', ...
    'width_m', ...
    'height_m', ...
    'surface_area_m2', ...
    'surface_area_to_volume_1_m', ...
    'projected_area_xy_m2', ...
    'projected_area_xz_m2', ...
    'projected_area_yz_m2', ...
    'drag_coefficient_x', ...
    'drag_coefficient_y', ...
    'drag_coefficient_z', ...
    'disturbance_stability_index', ...
    'max_dimension_m', ...
    'rank_SA_V', ...
    'rank_disturbance', ...
    'rank_max_dimension'};

actualColumns = decisionOutput.Properties.VariableNames;
missingColumns = setdiff(requiredColumnOrder, actualColumns, 'stable');
unexpectedColumns = setdiff(actualColumns, requiredColumnOrder, 'stable');
assert(isempty(missingColumns) && isempty(unexpectedColumns), ...
    'EnvelopeGeometry:DecisionMatrixColumns', ...
    'Decision matrix schema mismatch. Missing: %s | Unexpected: %s', ...
    strjoin(missingColumns, ', '), strjoin(unexpectedColumns, ', '));
decisionOutput = decisionOutput(:, requiredColumnOrder);

    writetable(decisionOutput, fullfile(cfg.paths.results_dir, 'envelope_decision_matrix.csv'));
    writetable(engineeringSignificanceSummary, fullfile(cfg.paths.results_dir, 'envelope_engineering_significance_summary.csv'));
    writetable(sensitivityResults, fullfile(cfg.paths.results_dir, 'envelope_sensitivity_results.csv'));
    writetable(rankingRobustness, fullfile(cfg.paths.results_dir, 'envelope_ranking_robustness.csv'));
    writetable(paretoTable, fullfile(cfg.paths.results_dir, 'envelope_pareto_analysis.csv'));
end

function print_console_summary(decisionMatrix, paretoTable, rankingRobustness, engineeringSignificanceSummary, selectedShape, nextBestShape)
selectedRow = decisionMatrix(decisionMatrix.shape == string(selectedShape), :);
selectedPareto = paretoTable(paretoTable.shape == string(selectedShape), :);
selectedRobustness = rankingRobustness(rankingRobustness.shape == string(selectedShape), :);

cuboidMetricRows = engineeringSignificanceSummary( ...
    engineeringSignificanceSummary.selected_shape == string(selectedShape) & ...
    engineeringSignificanceSummary.comparison_shape == "Cuboid", :);
prolateMetricRows = engineeringSignificanceSummary( ...
    engineeringSignificanceSummary.selected_shape == string(selectedShape) & ...
    engineeringSignificanceSummary.comparison_shape == "Prolate Ellipsoid", :);
flattenedMetricRows = engineeringSignificanceSummary( ...
    engineeringSignificanceSummary.selected_shape == string(selectedShape) & ...
    engineeringSignificanceSummary.comparison_shape == "Flattened Ellipsoid", :);

selectedShapeChar = char(string(selectedShape));
nextBestShapeChar = char(string(nextBestShape));

fprintf('\n=== Envelope geometry recommendation ===\n');
fprintf('Selected shape: %s\n', selectedShapeChar);
fprintf('Required volume: %.2f L\n', selectedRow.required_volume_L);
fprintf('Selected shape dimensions [L x W x H]: %.3f x %.3f x %.3f m\n', selectedRow.length_m, selectedRow.width_m, selectedRow.height_m);
fprintf('Selected shape SA/V and rank: %.3f 1/m (rank %.1f)\n', selectedRow.surface_area_to_volume_1_m, selectedRow.rank_SA_V);
fprintf('Selected shape disturbance stability index and rank: %.4f (rank %.1f)\n', selectedRow.disturbance_stability_index, selectedRow.rank_disturbance);
fprintf('Selected shape max dimension and rank: %.3f m (rank %.1f)\n', selectedRow.max_dimension_m, selectedRow.rank_max_dimension);
fprintf('Selected shape Pareto-dominated: %s\n', logical_to_text(selectedPareto.is_pareto_dominated));
fprintf('Percentage non-Pareto-dominated across sensitivity cases: %.1f%%\n', selectedRobustness.percentage_non_pareto_dominated);

fprintf('Comparison to cuboid:\n');
print_metric_comparison_block(cuboidMetricRows, 'Cuboid');
fprintf('Comparison to prolate ellipsoid:\n');
print_metric_comparison_block(prolateMetricRows, 'Prolate Ellipsoid');
fprintf('Comparison to flattened ellipsoid:\n');
print_metric_comparison_block(flattenedMetricRows, 'Flattened Ellipsoid');

if model_not_strongly_distinguished(engineeringSignificanceSummary, selectedShape, nextBestShape)
    fprintf('Final recommendation: The %s is recommended because it is non-Pareto-dominated and ranked best or near-best across the supported geometry-derived metrics. The model does not strongly distinguish it from %s, so physical validation is recommended before final lock-in.\n', ...
        lower(selectedShapeChar), nextBestShapeChar);
else
    fprintf('Final recommendation: The %s is recommended because it is non-Pareto-dominated and ranked best or near-best across the supported geometry-derived metrics.\n', ...
        lower(selectedShapeChar));
end

fprintf('\nComparisons are based on deterministic, geometry-derived metrics and engineering-significance thresholds.\n');
end

function print_metric_comparison_block(metricRows, comparisonLabel)
if isempty(metricRows)
    fprintf('  %s comparison not available in current run.\n', comparisonLabel);
    return;
end

for rowIndex = 1:height(metricRows)
    fprintf('  %s: %.1f%% difference (%s).\n', ...
        metricRows.metric{rowIndex}, ...
        metricRows.percent_difference(rowIndex), ...
        metricRows.engineering_significance_category{rowIndex});
end
end

function textValue = logical_to_text(logicalValue)
if logicalValue
    textValue = 'yes';
else
    textValue = 'no';
end
end

function textValue = pareto_result_text(paretoTable, selectedShape)
selectedRow = paretoTable(paretoTable.shape == string(selectedShape), :);
selectedShapeChar = char(string(selectedShape));
if selectedRow.is_pareto_dominated
    textValue = sprintf('%s is Pareto-dominated under the selected metrics and should only be retained with explicit justification.', selectedShapeChar);
else
    textValue = sprintf('%s is not Pareto-dominated under surface-area-to-volume ratio, disturbance stability index, and maximum dimension.', selectedShapeChar);
end
end

function assert_no_subjective_practicality_columns(decisionMatrix)
unsupportedColumns = { ...
    'manufacturability_score', ...
    'availability_score', ...
    'practical_score_source', ...
    'normalised_practicality', ...
    'weighted_practicality_contribution', ...
    'practicality_rank'};

presentUnsupported = intersect(unsupportedColumns, decisionMatrix.Properties.VariableNames);
assert(isempty(presentUnsupported), ...
    'EnvelopeGeometry:UnsupportedPracticalityColumns', ...
    'Unsupported subjective practicality columns found in decision matrix: %s', strjoin(presentUnsupported, ', '));
end

function safe_delete_file(filePath)
if isfile(filePath)
    delete(filePath);
end
end
