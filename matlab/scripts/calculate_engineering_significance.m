function significanceSummary = calculate_engineering_significance(cfg, decisionMatrix, selectedShape, nextBestShape)
%CALCULATE_ENGINEERING_SIGNIFICANCE Summarise engineering-significance comparisons.

comparisonShapes = [string(nextBestShape), "Cuboid", "Prolate Ellipsoid", "Flattened Ellipsoid"];
comparisonShapes = comparisonShapes(comparisonShapes ~= string(selectedShape));
comparisonShapes = unique(comparisonShapes, 'stable');

metricDefinitions = [ ...
    struct('field', "surface_area_to_volume_1_m", 'label', "surface_area_to_volume_1_m", 'direction', "lower", 'thresholdField', "material_efficiency_threshold_percent"), ...
    struct('field', "disturbance_stability_index", 'label', "disturbance_stability_index", 'direction', "lower", 'thresholdField', "disturbance_threshold_percent"), ...
    struct('field', "max_dimension_m", 'label', "max_dimension_m", 'direction', "lower", 'thresholdField', "size_threshold_percent") ...
    ];

selectedRow = decisionMatrix(decisionMatrix.shape == string(selectedShape), :);
summaryRows = {};

for metricIndex = 1:numel(metricDefinitions)
    metricDefinition = metricDefinitions(metricIndex);
    for comparisonIndex = 1:numel(comparisonShapes)
        comparisonShape = comparisonShapes(comparisonIndex);
        comparisonRow = decisionMatrix(decisionMatrix.shape == comparisonShape, :);
        if isempty(comparisonRow)
            continue;
        end

        selectedValue = selectedRow.(metricDefinition.field);
        comparisonValue = comparisonRow.(metricDefinition.field);
        percentDifference = calculate_percent_difference(selectedValue, comparisonValue, metricDefinition.direction);
        thresholdPercent = cfg.engineering_significance.(metricDefinition.thresholdField);
        category = classify_significance(percentDifference, thresholdPercent);
        interpretation = build_interpretation(metricDefinition.label, category, selectedShape, comparisonShape, percentDifference);

        summaryRows(end + 1, :) = { ...
            char(metricDefinition.label), ...
            char(selectedShape), ...
            char(comparisonShape), ...
            selectedValue, ...
            comparisonValue, ...
            percentDifference, ...
            char(category), ...
            char(interpretation)}; %#ok<AGROW>
    end
end

significanceSummary = cell2table(summaryRows, 'VariableNames', { ...
    'metric', 'selected_shape', 'comparison_shape', 'selected_value', ...
    'comparison_value', 'percent_difference', 'engineering_significance_category', 'interpretation'});

end

function percentDifference = calculate_percent_difference(selectedValue, comparisonValue, direction)
referenceValue = max(abs(comparisonValue), eps);

if strcmpi(direction, 'higher')
    percentDifference = 100 * (selectedValue - comparisonValue) / referenceValue;
else
    percentDifference = 100 * (comparisonValue - selectedValue) / referenceValue;
end

end

function category = classify_significance(percentDifference, thresholdPercent)
if percentDifference <= 0
    category = "negligible";
elseif percentDifference < 0.5 * thresholdPercent
    category = "negligible";
elseif percentDifference < thresholdPercent
    category = "marginal";
elseif percentDifference < 2 * thresholdPercent
    category = "moderate";
else
    category = "strong";
end

end

function interpretation = build_interpretation(metricLabel, category, selectedShape, comparisonShape, percentDifference)
metricText = strrep(char(metricLabel), '_', ' ');
switch category
    case 'negligible'
        effectText = 'difference is unlikely to change the design decision by itself';
    case 'marginal'
        effectText = 'difference may inform the decision but is not decisive by itself';
    case 'moderate'
        effectText = 'difference is large enough to influence the design decision';
    otherwise
        effectText = 'difference is strong and should materially influence the design decision';
end

interpretation = sprintf('For %s, %s vs %s shows %.1f%% improvement; this %s.', ...
    metricText, char(selectedShape), char(comparisonShape), percentDifference, effectText);
end