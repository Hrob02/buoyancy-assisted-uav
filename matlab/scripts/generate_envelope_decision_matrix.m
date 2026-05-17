function [decisionMatrix, analysisMeta] = generate_envelope_decision_matrix(cfg, mass_g, buoyancyRatio, surfaceDensity_kg_m2)
%GENERATE_ENVELOPE_DECISION_MATRIX Build the baseline shape comparison table.

shapes = cfg.shapes;
shapeCount = numel(shapes);
requiredVolume_m3 = calculate_required_volume(mass_g, buoyancyRatio, cfg);
gravity_m_s2 = cfg.environment.gravity_m_s2;
buoyantForce_N = (cfg.environment.rho_air_kg_m3 - cfg.environment.rho_helium_kg_m3) * ...
    gravity_m_s2 * requiredVolume_m3;

rows = repmat(struct(), shapeCount, 1);

for index = 1:shapeCount
    shape = shapes(index);
    dimensions = calculate_shape_dimensions(requiredVolume_m3, shape);
    surfaceArea_m2 = calculate_shape_surface_area(shape, dimensions);
    projectedAreas = calculate_projected_areas(shape, dimensions);
    disturbance = calculate_disturbance_index(shape, dimensions);

    estimatedEnvelopeMaterialMass_kg = surfaceDensity_kg_m2 * surfaceArea_m2;
    estimatedNetLiftAfterEnvelopeMass_N = buoyantForce_N - estimatedEnvelopeMaterialMass_kg * gravity_m_s2;
    estimatedNetLiftAfterEnvelopeMass_g = estimatedNetLiftAfterEnvelopeMass_N / gravity_m_s2 * 1000;

    rows(index).shape = string(shape.display_name);
    rows(index).required_volume_L = requiredVolume_m3 * 1000;
    rows(index).length_m = dimensions.length_m;
    rows(index).width_m = dimensions.width_m;
    rows(index).height_m = dimensions.height_m;
    rows(index).surface_area_m2 = surfaceArea_m2;
    rows(index).surface_area_to_volume_1_m = surfaceArea_m2 / requiredVolume_m3;
    rows(index).estimated_envelope_material_mass_kg = estimatedEnvelopeMaterialMass_kg;
    rows(index).estimated_net_lift_after_envelope_mass_g = estimatedNetLiftAfterEnvelopeMass_g;
    rows(index).disturbance_stability_index = disturbance.disturbance_stability_index;
    rows(index).spatial_footprint_m2 = projectedAreas.spatial_footprint_m2;
    rows(index).max_dimension_m = projectedAreas.max_dimension_m;
    rows(index).manufacturability_score = shape.manufacturability_score;
    rows(index).availability_score = shape.availability_score;
    rows(index).practical_score_source = string(shape.practical_score_source);
    rows(index).meets_required_volume = true;
    rows(index).meets_size_limit = evaluate_size_limit(cfg, dimensions);
    rows(index).estimated_net_lift_after_envelope_mass_N_internal = estimatedNetLiftAfterEnvelopeMass_N;
end

decisionMatrix = struct2table(rows);

decisionMatrix.normalised_material_efficiency = min_max_normalise(decisionMatrix.surface_area_to_volume_1_m);
decisionMatrix.normalised_disturbance = min_max_normalise(decisionMatrix.disturbance_stability_index);

normalisedFootprint = min_max_normalise(decisionMatrix.spatial_footprint_m2);
normalisedMaxDimension = min_max_normalise(decisionMatrix.max_dimension_m);
decisionMatrix.normalised_spatial_compactness = mean([normalisedFootprint, normalisedMaxDimension], 2);

normalisedManufacturability = min_max_normalise(decisionMatrix.manufacturability_score);
normalisedAvailability = min_max_normalise(decisionMatrix.availability_score);
decisionMatrix.normalised_practicality = mean([normalisedManufacturability, normalisedAvailability], 2);

decisionMatrix.weighted_total_score = ...
    cfg.weights.material_efficiency * decisionMatrix.normalised_material_efficiency + ...
    cfg.weights.disturbance_response * decisionMatrix.normalised_disturbance + ...
    cfg.weights.spatial_compactness * decisionMatrix.normalised_spatial_compactness + ...
    cfg.weights.practicality * decisionMatrix.normalised_practicality;

decisionMatrix.practicality_acceptability_internal = ...
    max([decisionMatrix.manufacturability_score, decisionMatrix.availability_score], [], 2) <= ...
    cfg.practicality.acceptable_score_max;

[~, order] = sort(decisionMatrix.weighted_total_score, 'ascend');
rank = zeros(height(decisionMatrix), 1);
rank(order) = 1:height(decisionMatrix);
decisionMatrix.rank = rank;
decisionMatrix.recommendation_note = repmat("Candidate under review", height(decisionMatrix), 1);

analysisMeta.required_volume_m3 = requiredVolume_m3;
analysisMeta.buoyant_force_N = buoyantForce_N;
analysisMeta.surface_density_kg_m2 = surfaceDensity_kg_m2;
analysisMeta.mass_g = mass_g;
analysisMeta.buoyancy_ratio = buoyancyRatio;

end

function normalisedValues = min_max_normalise(values)
minimumValue = min(values);
maximumValue = max(values);

if abs(maximumValue - minimumValue) < 1.0e-12
    normalisedValues = zeros(size(values));
else
    normalisedValues = (values - minimumValue) ./ (maximumValue - minimumValue);
end
end

function meetsSizeLimit = evaluate_size_limit(cfg, dimensions)
if ~cfg.constraints.apply_size_limits
    meetsSizeLimit = true;
    return;
end

meetsSizeLimit = dimensions.length_m <= cfg.constraints.max_length_m && ...
    dimensions.width_m <= cfg.constraints.max_width_m && ...
    dimensions.height_m <= cfg.constraints.max_height_m && ...
    max([dimensions.length_m, dimensions.width_m, dimensions.height_m]) <= cfg.constraints.max_dimension_m;
end