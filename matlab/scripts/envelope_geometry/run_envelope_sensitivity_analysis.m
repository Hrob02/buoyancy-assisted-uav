function [sensitivityResults, rankingRobustness] = run_envelope_sensitivity_analysis(cfg)
%RUN_ENVELOPE_SENSITIVITY_ANALYSIS Sweep mass, buoyancy ratio, and surface density.

caseCounter = 0;
shapeCount = numel(cfg.shapes);
totalCases = numel(cfg.sensitivity.mass_g) * numel(cfg.sensitivity.buoyancy_ratio) * ...
    numel(cfg.sensitivity.surface_density_kg_m2) * shapeCount;

resultRows(totalCases, 1) = struct();

for massIndex = 1:numel(cfg.sensitivity.mass_g)
    mass_g = cfg.sensitivity.mass_g(massIndex);
    for ratioIndex = 1:numel(cfg.sensitivity.buoyancy_ratio)
        buoyancyRatio = cfg.sensitivity.buoyancy_ratio(ratioIndex);
        for densityIndex = 1:numel(cfg.sensitivity.surface_density_kg_m2)
            surfaceDensity_kg_m2 = cfg.sensitivity.surface_density_kg_m2(densityIndex);
            [decisionMatrix, ~] = generate_envelope_decision_matrix(cfg, mass_g, buoyancyRatio, surfaceDensity_kg_m2);
            paretoTable = compute_pareto_flags(decisionMatrix);

            for rowIndex = 1:height(decisionMatrix)
                caseCounter = caseCounter + 1;
                resultRows(caseCounter).mass_g = mass_g;
                resultRows(caseCounter).buoyancy_ratio = buoyancyRatio;
                resultRows(caseCounter).surface_density_kg_m2 = surfaceDensity_kg_m2;
                resultRows(caseCounter).shape = decisionMatrix.shape(rowIndex);
                resultRows(caseCounter).required_volume_L = decisionMatrix.required_volume_L(rowIndex);
                resultRows(caseCounter).surface_area_to_volume_1_m = decisionMatrix.surface_area_to_volume_1_m(rowIndex);
                resultRows(caseCounter).disturbance_stability_index = decisionMatrix.disturbance_stability_index(rowIndex);
                resultRows(caseCounter).max_dimension_m = decisionMatrix.max_dimension_m(rowIndex);
                resultRows(caseCounter).rank_SA_V = decisionMatrix.rank_SA_V(rowIndex);
                resultRows(caseCounter).rank_disturbance = decisionMatrix.rank_disturbance(rowIndex);
                resultRows(caseCounter).rank_max_dimension = decisionMatrix.rank_max_dimension(rowIndex);
                resultRows(caseCounter).is_pareto_dominated = paretoTable.is_pareto_dominated(rowIndex);
            end
        end
    end
end

sensitivityResults = struct2table(resultRows(1:caseCounter));

uniqueShapes = string({cfg.shapes.display_name})';
robustnessRows(numel(uniqueShapes), 1) = struct();
totalSweepCases = numel(cfg.sensitivity.mass_g) * numel(cfg.sensitivity.buoyancy_ratio) * ...
    numel(cfg.sensitivity.surface_density_kg_m2);

for shapeIndex = 1:numel(uniqueShapes)
    shapeName = uniqueShapes(shapeIndex);
    shapeMask = sensitivityResults.shape == shapeName;
    ranksSAV = sensitivityResults.rank_SA_V(shapeMask);
    ranksDisturbance = sensitivityResults.rank_disturbance(shapeMask);
    ranksMaxDimension = sensitivityResults.rank_max_dimension(shapeMask);
    nonDominatedMask = ~sensitivityResults.is_pareto_dominated(shapeMask);

    robustnessRows(shapeIndex).shape = shapeName;
    robustnessRows(shapeIndex).percentage_ranked_first_SA_V = 100 * sum(ranksSAV == 1) / totalSweepCases;
    robustnessRows(shapeIndex).percentage_ranked_first_disturbance = 100 * sum(ranksDisturbance == 1) / totalSweepCases;
    robustnessRows(shapeIndex).percentage_ranked_first_max_dimension = 100 * sum(ranksMaxDimension == 1) / totalSweepCases;
    robustnessRows(shapeIndex).percentage_non_pareto_dominated = 100 * sum(nonDominatedMask) / totalSweepCases;
    robustnessRows(shapeIndex).average_rank_SA_V = mean(ranksSAV);
    robustnessRows(shapeIndex).average_rank_disturbance = mean(ranksDisturbance);
    robustnessRows(shapeIndex).average_rank_max_dimension = mean(ranksMaxDimension);
    robustnessRows(shapeIndex).robustness_note = sprintf('%s ranked first for SA/V in %.1f%% of sensitivity cases and remained non-Pareto-dominated in %.1f%% of cases.', ...
        char(shapeName), robustnessRows(shapeIndex).percentage_ranked_first_SA_V, robustnessRows(shapeIndex).percentage_non_pareto_dominated);
end

rankingRobustness = sortrows(struct2table(robustnessRows), ...
    {'percentage_non_pareto_dominated', 'average_rank_SA_V', 'average_rank_disturbance'}, ...
    {'descend', 'ascend', 'ascend'});

end

function paretoTable = compute_pareto_flags(decisionMatrix)
metricMatrix = [ ...
    decisionMatrix.surface_area_to_volume_1_m, ...
    decisionMatrix.disturbance_stability_index, ...
    decisionMatrix.max_dimension_m];

shapeCount = height(decisionMatrix);
dominated = false(shapeCount, 1);

for rowIndex = 1:shapeCount
    for comparisonIndex = 1:shapeCount
        if rowIndex == comparisonIndex
            continue;
        end

        comparisonBetterOrEqual = all(metricMatrix(comparisonIndex, :) <= metricMatrix(rowIndex, :));
        comparisonStrictlyBetter = any(metricMatrix(comparisonIndex, :) < metricMatrix(rowIndex, :));
        if comparisonBetterOrEqual && comparisonStrictlyBetter
            dominated(rowIndex) = true;
            break;
        end
    end
end

paretoTable = table(decisionMatrix.shape, dominated, ...
    'VariableNames', {'shape', 'is_pareto_dominated'});

end