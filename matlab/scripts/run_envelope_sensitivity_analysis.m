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

            for rowIndex = 1:height(decisionMatrix)
                caseCounter = caseCounter + 1;
                resultRows(caseCounter).mass_g = mass_g;
                resultRows(caseCounter).buoyancy_ratio = buoyancyRatio;
                resultRows(caseCounter).surface_density_kg_m2 = surfaceDensity_kg_m2;
                resultRows(caseCounter).shape = decisionMatrix.shape(rowIndex);
                resultRows(caseCounter).required_volume_L = decisionMatrix.required_volume_L(rowIndex);
                resultRows(caseCounter).surface_area_to_volume_1_m = decisionMatrix.surface_area_to_volume_1_m(rowIndex);
                resultRows(caseCounter).estimated_envelope_material_mass_kg = ...
                    decisionMatrix.estimated_envelope_material_mass_kg(rowIndex);
                resultRows(caseCounter).estimated_net_lift_after_envelope_mass_g = ...
                    decisionMatrix.estimated_net_lift_after_envelope_mass_g(rowIndex);
                resultRows(caseCounter).disturbance_stability_index = decisionMatrix.disturbance_stability_index(rowIndex);
                resultRows(caseCounter).weighted_total_score = decisionMatrix.weighted_total_score(rowIndex);
                resultRows(caseCounter).rank = decisionMatrix.rank(rowIndex);
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
    ranks = sensitivityResults.rank(shapeMask);

    robustnessRows(shapeIndex).shape = shapeName;
    robustnessRows(shapeIndex).number_of_sweep_cases_ranked_first = sum(ranks == 1);
    robustnessRows(shapeIndex).percentage_of_sweep_cases_ranked_first = ...
        100 * sum(ranks == 1) / totalSweepCases;
    robustnessRows(shapeIndex).number_of_sweep_cases_ranked_second = sum(ranks == 2);
    robustnessRows(shapeIndex).percentage_of_sweep_cases_ranked_second = ...
        100 * sum(ranks == 2) / totalSweepCases;
    robustnessRows(shapeIndex).average_rank = mean(ranks);
    robustnessRows(shapeIndex).worst_rank = max(ranks);
    robustnessRows(shapeIndex).best_rank = min(ranks);
end

rankingRobustness = sortrows(struct2table(robustnessRows), {'average_rank', 'percentage_of_sweep_cases_ranked_first'}, {'ascend', 'descend'});

end