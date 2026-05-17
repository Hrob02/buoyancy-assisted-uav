function significanceSummary = calculate_engineering_significance(cfg, decisionMatrix, selectedShape, nextBestShape)
%CALCULATE_ENGINEERING_SIGNIFICANCE Summarise engineering-significance comparisons.

comparisonShapes = [string(nextBestShape), "Cuboid"];
comparisonShapes = unique(comparisonShapes, 'stable');

metricDefinitions = [ ...
    struct('field', "surface_area_to_volume_1_m", 'label', "surface_area_to_volume_ratio", 'type', "primary material-efficiency metric", 'direction', "lower", 'thresholdField', "material_efficiency_threshold_percent", 'interpretation', "A lower surface-area-to-volume ratio reduces the material required to contain the same helium volume. This reduces the envelope mass penalty and increases the net buoyant lift available to support the UAV."), ...
    struct('field', "estimated_envelope_material_mass_kg", 'label', "estimated_envelope_material_mass_kg", 'type', "derived material-mass estimate", 'direction', "lower", 'thresholdField', "material_efficiency_threshold_percent", 'interpretation', "This is a derived estimate based on the assumed reference surface density. It is used to interpret the material-mass impact of SA/V, not as a measured prototype mass."), ...
    struct('field', "estimated_net_lift_after_envelope_mass_g", 'label', "estimated_net_lift_after_envelope_mass_g", 'type', "derived useful-lift estimate", 'direction', "higher", 'thresholdField', "material_efficiency_threshold_percent", 'interpretation', "This value estimates how much buoyant lift remains available to support the UAV after accounting for assumed envelope material mass. It should be interpreted as a relative comparison only unless validated using measured balloon mass."), ...
    struct('field', "disturbance_stability_index", 'label', "disturbance_stability_index", 'type', "primary disturbance metric", 'direction', "lower", 'thresholdField', "disturbance_threshold_percent", 'interpretation', "Lower disturbance stability index indicates lower directional disturbance exposure and a more robust disturbance-response geometry."), ...
    struct('field', "max_dimension_m", 'label', "max_dimension_m", 'type', "size-envelope metric", 'direction', "lower", 'thresholdField', "size_threshold_percent", 'interpretation', "Lower maximum dimension indicates a smaller geometric size envelope at equal required helium volume."), ...
    struct('field', "weighted_total_score", 'label', "weighted_total_score", 'type', "decision-screening metric", 'direction', "lower", 'thresholdField', "score_difference_threshold_percent", 'interpretation', "Lower weighted score indicates a better combined geometry-derived design-screening balance across material efficiency, disturbance response, and size constraint.") ...
    ];

selectedRow = decisionMatrix(decisionMatrix.shape == string(selectedShape), :);
summaryRows = {};

for metricIndex = 1:numel(metricDefinitions)
    metricDefinition = metricDefinitions(metricIndex);
    if ~ismember(metricDefinition.label, ["surface_area_to_volume_ratio", "estimated_envelope_material_mass_kg", ...
            "estimated_net_lift_after_envelope_mass_g", "disturbance_stability_index", ...
            "max_dimension_m", "weighted_total_score"]) %#ok<ISMEMB>
        continue;
    end

    for comparisonIndex = 1:numel(comparisonShapes)
        comparisonShape = comparisonShapes(comparisonIndex);
        comparisonRow = decisionMatrix(decisionMatrix.shape == comparisonShape, :);
        if isempty(comparisonRow)
            continue;
        end

        selectedValue = selectedRow.(metricDefinition.field);
        comparisonValue = comparisonRow.(metricDefinition.field);
        percentImprovement = calculate_percent_improvement(selectedValue, comparisonValue, metricDefinition.direction);
        thresholdPercent = cfg.engineering_significance.(metricDefinition.thresholdField);
        category = classify_significance(percentImprovement, thresholdPercent);

        summaryRows(end + 1, :) = { ...
            char(metricDefinition.label), ...
            char(metricDefinition.type), ...
            char(selectedShape), ...
            char(comparisonShape), ...
            selectedValue, ...
            comparisonValue, ...
            percentImprovement, ...
            char(category), ...
            char(metricDefinition.interpretation)}; %#ok<AGROW>
    end
end

significanceSummary = cell2table(summaryRows, 'VariableNames', { ...
    'metric', 'metric_type', 'selected_shape', 'comparison_shape', 'selected_value', ...
    'comparison_value', 'percent_improvement', 'engineering_significance_category', 'practical_interpretation'});

end

function percentImprovement = calculate_percent_improvement(selectedValue, comparisonValue, direction)
referenceValue = max(abs(comparisonValue), eps);

if strcmpi(direction, 'higher')
    percentImprovement = 100 * (selectedValue - comparisonValue) / referenceValue;
else
    percentImprovement = 100 * (comparisonValue - selectedValue) / referenceValue;
end

end

function category = classify_significance(percentImprovement, thresholdPercent)
if percentImprovement <= 0
    category = "negligible";
elseif percentImprovement < 0.5 * thresholdPercent
    category = "negligible";
elseif percentImprovement < thresholdPercent
    category = "marginal";
elseif percentImprovement < 2 * thresholdPercent
    category = "moderate";
else
    category = "strong";
end

end