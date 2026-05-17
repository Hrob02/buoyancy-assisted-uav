function run_envelope_geometry_analysis()
%RUN_ENVELOPE_GEOMETRY_ANALYSIS Deterministic envelope geometry design screening.

clc;
close all;

cfg = config_envelope_geometry_parameters();
ensure_output_directories(cfg);
clean_output_directories(cfg);
validate_weight_sum(cfg);

fprintf('=== Envelope Geometry Design-Screening Analysis ===\n');

[decisionMatrix, analysisMeta] = generate_envelope_decision_matrix( ...
    cfg, cfg.system.reference_mass_g, cfg.system.target_buoyancy_ratio, cfg.envelope.sigma_ref_kg_m2);
validate_baseline_results(decisionMatrix, cfg);

paretoTable = generate_pareto_analysis(decisionMatrix);
[selectedShape, nextBestShape, decisionMatrix] = determine_selected_shape(cfg, decisionMatrix, paretoTable);
engineeringSignificanceSummary = calculate_engineering_significance(cfg, decisionMatrix, selectedShape, nextBestShape);

[sensitivityResults, rankingRobustness] = run_envelope_sensitivity_analysis(cfg);
selectedRobustness = rankingRobustness(rankingRobustness.shape == string(selectedShape), :);
supplementaryAnova = run_supplementary_anova(cfg, sensitivityResults);

write_core_outputs(cfg, decisionMatrix, engineeringSignificanceSummary, sensitivityResults, rankingRobustness, paretoTable);
generate_envelope_plots(cfg, decisionMatrix, rankingRobustness, paretoTable);

analysis.decision_matrix = decisionMatrix;
analysis.selected_shape = string(selectedShape);
analysis.next_best_shape = string(nextBestShape);
analysis.engineering_significance_summary = engineeringSignificanceSummary;
analysis.selected_shape_rank_first_percent = selectedRobustness.percentage_of_sweep_cases_ranked_first;
analysis.selected_shape_average_rank = selectedRobustness.average_rank;
analysis.pareto_result_text = pareto_result_text(paretoTable, selectedShape);
analysis.supplementary_anova_note = supplementaryAnova.note;
analysis.analysis_meta = analysisMeta;

write_envelope_recommendation_md(cfg, analysis);
print_console_summary(decisionMatrix, paretoTable, rankingRobustness, engineeringSignificanceSummary, selectedShape);
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
    'envelope_geometry_assumptions.md', ...
    'envelope_supplementary_anova_summary.csv', ...
    'envelope_supplementary_pairwise_comparisons.csv'};

figureFiles = { ...
    'envelope_metric_comparison.png', ...
    'envelope_decision_score.png', ...
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

function validate_weight_sum(cfg)
weightSum = cfg.weights.material_efficiency + cfg.weights.disturbance_response + ...
    cfg.weights.size_constraint;
assert(abs(weightSum - 1.0) <= cfg.weights.sum_tolerance, ...
    'EnvelopeGeometry:WeightSum', ...
    'Decision weights must sum to 1.0 within tolerance.');
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
assert(all(decisionMatrix.estimated_envelope_material_mass_kg >= 0), ...
    'EnvelopeGeometry:InvalidEnvelopeMass', ...
    'Estimated envelope material mass must be non-negative.');
assert(all(isfinite(decisionMatrix.estimated_net_lift_after_envelope_mass_g)), ...
    'EnvelopeGeometry:InvalidNetLift', ...
    'Estimated net lift after envelope mass must be finite.');
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
        paretoNote(rowIndex) = "Dominated by a shape that is equal or better across all selected Pareto metrics.";
    else
        dominatedBy(rowIndex) = "";
        paretoNote(rowIndex) = "Not Pareto-dominated under SA/V, disturbance index, and maximum dimension.";
    end
end

paretoTable = table(decisionMatrix.shape, dominated, dominatedBy, paretoNote, ...
    'VariableNames', {'shape', 'is_pareto_dominated', 'dominated_by', 'pareto_note'});
end

function [selectedShape, nextBestShape, updatedDecisionMatrix] = determine_selected_shape(cfg, decisionMatrix, paretoTable)
updatedDecisionMatrix = decisionMatrix;
updatedDecisionMatrix.is_pareto_dominated_internal = paretoTable.is_pareto_dominated;

eligibleMask = updatedDecisionMatrix.meets_required_volume & updatedDecisionMatrix.meets_size_limit & ...
    ~updatedDecisionMatrix.is_pareto_dominated_internal;

if ~any(eligibleMask)
    eligibleMask = updatedDecisionMatrix.meets_required_volume & updatedDecisionMatrix.meets_size_limit;
end
if ~any(eligibleMask)
    eligibleMask = true(height(updatedDecisionMatrix), 1);
end

eligibleTable = updatedDecisionMatrix(eligibleMask, :);
bestScore = min(eligibleTable.weighted_total_score);
scoreMargin = bestScore * (1 + cfg.engineering_significance.score_difference_threshold_percent / 100);
nearBestMask = eligibleMask & (updatedDecisionMatrix.weighted_total_score <= scoreMargin);
nearBestTable = updatedDecisionMatrix(nearBestMask, :);

if height(nearBestTable) > 1
    [~, nearBestOrder] = sortrows([nearBestTable.weighted_total_score, nearBestTable.max_dimension_m], [1 2]);
    selectedShape = nearBestTable.shape(nearBestOrder(1));
    modelCloseCall = true;
else
    [~, localOrder] = sort(eligibleTable.weighted_total_score, 'ascend');
    selectedShape = eligibleTable.shape(localOrder(1));
    modelCloseCall = false;
end

rankedTable = sortrows(updatedDecisionMatrix, {'weighted_total_score', 'max_dimension_m'}, {'ascend', 'ascend'});
nextBestShape = rankedTable.shape(find(rankedTable.shape ~= selectedShape, 1, 'first'));

for rowIndex = 1:height(updatedDecisionMatrix)
    rowShape = updatedDecisionMatrix.shape(rowIndex);
    if rowShape == selectedShape
        if modelCloseCall
            updatedDecisionMatrix.recommendation_note(rowIndex) = "Selected: non-dominated with near-best score; model does not strongly distinguish near-best shapes, so physical validation is recommended.";
        else
            updatedDecisionMatrix.recommendation_note(rowIndex) = "Selected: non-dominated with the best geometry-derived weighted score.";
        end
    elseif paretoTable.is_pareto_dominated(rowIndex)
        updatedDecisionMatrix.recommendation_note(rowIndex) = "Not preferred: Pareto-dominated under the selected screening metrics.";
    elseif updatedDecisionMatrix.weighted_total_score(rowIndex) <= scoreMargin
        updatedDecisionMatrix.recommendation_note(rowIndex) = "Competitive: near-best score; model does not strongly distinguish this option from the selected shape.";
    else
        updatedDecisionMatrix.recommendation_note(rowIndex) = "Not selected: lower overall design-screening balance than the leading candidate.";
    end
end

end

function supplementaryAnova = run_supplementary_anova(cfg, sensitivityResults)
supplementaryAnova.note = "ANOVA is included as a screening tool only. The primary decision is based on engineering significance because the simulation outputs are deterministic model results, not repeated physical measurements.";
supplementaryAnova.summaryTable = table();
supplementaryAnova.pairwiseTable = table();

if ~cfg.statistics.enable_supplementary_anova
    return;
end

if ~(exist('anova1', 'file') == 2 && exist('multcompare', 'file') == 2)
    supplementaryAnova.note = sprintf('%s Statistics and Machine Learning Toolbox functions were not available, so supplementary ANOVA tables were not generated.', supplementaryAnova.note);
    return;
end

metricFields = { ...
    'surface_area_to_volume_1_m', ...
    'estimated_envelope_material_mass_kg', ...
    'estimated_net_lift_after_envelope_mass_g', ...
    'disturbance_stability_index', ...
    'weighted_total_score'};

summaryRows = {};
pairwiseRows = {};
for metricIndex = 1:numel(metricFields)
    metricField = metricFields{metricIndex};
    metricValues = sensitivityResults.(metricField);
    groupLabels = cellstr(sensitivityResults.shape);

    [pValue, ~, stats] = anova1(metricValues, groupLabels, 'off');
    summaryRows(end + 1, :) = {metricField, pValue, pValue < cfg.statistics.anova_alpha}; %#ok<AGROW>

    comparisonTable = multcompare(stats, 'Display', 'off');
    for rowIndex = 1:size(comparisonTable, 1)
        pairwiseRows(end + 1, :) = { ...
            metricField, ...
            stats.gnames{comparisonTable(rowIndex, 1)}, ...
            stats.gnames{comparisonTable(rowIndex, 2)}, ...
            comparisonTable(rowIndex, 4), ...
            comparisonTable(rowIndex, 6), ...
            comparisonTable(rowIndex, 6) < cfg.statistics.anova_alpha}; %#ok<AGROW>
    end
end

supplementaryAnova.summaryTable = cell2table(summaryRows, 'VariableNames', {'metric', 'anova_p_value', 'anova_significant'});
supplementaryAnova.pairwiseTable = cell2table(pairwiseRows, 'VariableNames', { ...
    'metric', 'shape_a', 'shape_b', 'mean_difference', 'p_value', 'significant_at_alpha'});

if cfg.output.write_debug_tables
    writetable(supplementaryAnova.summaryTable, fullfile(cfg.paths.results_dir, 'envelope_supplementary_anova_summary.csv'));
    writetable(supplementaryAnova.pairwiseTable, fullfile(cfg.paths.results_dir, 'envelope_supplementary_pairwise_comparisons.csv'));
end
end

function write_core_outputs(cfg, decisionMatrix, engineeringSignificanceSummary, sensitivityResults, rankingRobustness, paretoTable)
decisionOutput = removevars(decisionMatrix, {'meets_required_volume', 'meets_size_limit', ...
    'estimated_net_lift_after_envelope_mass_N_internal', 'is_pareto_dominated_internal'});

requiredColumnOrder = { ...
    'shape', ...
    'required_volume_L', ...
    'length_m', ...
    'width_m', ...
    'height_m', ...
    'max_dimension_m', ...
    'bounding_box_volume_m3', ...
    'surface_area_m2', ...
    'surface_area_to_volume_1_m', ...
    'estimated_envelope_material_mass_kg', ...
    'estimated_net_lift_after_envelope_mass_g', ...
    'projected_area_xy_m2', ...
    'projected_area_xz_m2', ...
    'projected_area_yz_m2', ...
    'drag_coefficient_x', ...
    'drag_coefficient_y', ...
    'drag_coefficient_z', ...
    'disturbance_stability_index', ...
    'normalised_material_efficiency', ...
    'normalised_disturbance', ...
    'normalised_size_constraint', ...
    'weighted_material_contribution', ...
    'weighted_disturbance_contribution', ...
    'weighted_size_contribution', ...
    'weighted_total_score', ...
    'rank', ...
    'recommendation_note'};

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

function print_console_summary(decisionMatrix, paretoTable, rankingRobustness, engineeringSignificanceSummary, selectedShape)
selectedRow = decisionMatrix(decisionMatrix.shape == string(selectedShape), :);
selectedPareto = paretoTable(paretoTable.shape == string(selectedShape), :);
selectedRobustness = rankingRobustness(rankingRobustness.shape == string(selectedShape), :);

cuboidRow = decisionMatrix(decisionMatrix.shape == "Cuboid", :);
prolateRow = decisionMatrix(decisionMatrix.shape == "Prolate Ellipsoid", :);
selectedShapeChar = char(string(selectedShape));

fprintf('\n=== Envelope geometry recommendation ===\n');
fprintf('Selected shape: %s\n', selectedShapeChar);
fprintf('Required volume: %.2f L\n', selectedRow.required_volume_L);
fprintf('Dimensions [L x W x H]: %.3f x %.3f x %.3f m\n', selectedRow.length_m, selectedRow.width_m, selectedRow.height_m);
fprintf('Selected SA/V: %.3f 1/m\n', selectedRow.surface_area_to_volume_1_m);
fprintf('Selected estimated envelope material mass: %.4f kg\n', selectedRow.estimated_envelope_material_mass_kg);
fprintf('Selected estimated net lift after envelope material mass: %.2f g\n', selectedRow.estimated_net_lift_after_envelope_mass_g);
fprintf('Selected disturbance index: %.4f\n', selectedRow.disturbance_stability_index);
fprintf('Selected weighted decision score: %.4f\n', selectedRow.weighted_total_score);
fprintf('Selected shape Pareto-dominated: %s\n', logical_to_text(selectedPareto.is_pareto_dominated));
fprintf('Ranking robustness: ranked first in %.1f%% of sensitivity cases\n', selectedRobustness.percentage_of_sweep_cases_ranked_first);
fprintf('Comparison to cuboid: SA/V improvement %.1f%%, weighted score improvement %.1f%%\n', ...
    lookup_improvement(engineeringSignificanceSummary, 'surface_area_to_volume_ratio', selectedShape, 'Cuboid'), ...
    lookup_improvement(engineeringSignificanceSummary, 'weighted_total_score', selectedShape, 'Cuboid'));
fprintf('Comparison to prolate ellipsoid: SA/V improvement %.1f%%, weighted score improvement %.1f%%\n', ...
    relative_improvement(selectedRow.surface_area_to_volume_1_m, prolateRow.surface_area_to_volume_1_m, 'lower'), ...
    relative_improvement(selectedRow.weighted_total_score, prolateRow.weighted_total_score, 'lower'));
fprintf('Final recommendation: The %s is selected as the preferred envelope geometry based on geometry-derived engineering metrics, with non-dominated performance and robust sensitivity ranking.\n', lower(selectedShapeChar));

if contains(selectedRow.recommendation_note, 'does not strongly distinguish')
    fprintf('Model distinction note: Near-best shapes have close scores at the current threshold; physical validation is recommended before final shape lock-in.\n');
end

fprintf('\nSupplementary context: ANOVA is included as a screening tool only. The primary decision is based on engineering significance because the simulation outputs are deterministic model results, not repeated physical measurements.\n');
fprintf('Cuboid reference weighted score: %.4f\n', cuboidRow.weighted_total_score);
end

function textValue = logical_to_text(logicalValue)
if logicalValue
    textValue = 'yes';
else
    textValue = 'no';
end
end

function improvement = lookup_improvement(summaryTable, metricName, selectedShape, comparisonShape)
row = summaryTable(strcmp(summaryTable.metric, metricName) & strcmp(summaryTable.selected_shape, selectedShape) & ...
    strcmp(summaryTable.comparison_shape, comparisonShape), :);
if isempty(row)
    improvement = NaN;
else
    improvement = row.percent_improvement(1);
end
end

function improvement = relative_improvement(selectedValue, comparisonValue, direction)
referenceValue = max(abs(comparisonValue), eps);
if strcmpi(direction, 'higher')
    improvement = 100 * (selectedValue - comparisonValue) / referenceValue;
else
    improvement = 100 * (comparisonValue - selectedValue) / referenceValue;
end
end

function textValue = pareto_result_text(paretoTable, selectedShape)
selectedRow = paretoTable(paretoTable.shape == string(selectedShape), :);
selectedShapeChar = char(string(selectedShape));
if selectedRow.is_pareto_dominated
    textValue = sprintf('%s is Pareto-dominated under the selected metrics and was retained only because of the hierarchical recommendation constraints.', selectedShapeChar);
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