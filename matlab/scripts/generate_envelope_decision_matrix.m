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
    rows(index).max_dimension_m = projectedAreas.max_dimension_m;
    rows(index).bounding_box_volume_m3 = dimensions.length_m * dimensions.width_m * dimensions.height_m;
    rows(index).surface_area_m2 = surfaceArea_m2;
    rows(index).surface_area_to_volume_1_m = surfaceArea_m2 / requiredVolume_m3;
    rows(index).estimated_envelope_material_mass_kg = estimatedEnvelopeMaterialMass_kg;
    rows(index).estimated_net_lift_after_envelope_mass_g = estimatedNetLiftAfterEnvelopeMass_g;
    rows(index).projected_area_xy_m2 = projectedAreas.area_xy_m2;
    rows(index).projected_area_xz_m2 = projectedAreas.area_xz_m2;
    rows(index).projected_area_yz_m2 = projectedAreas.area_yz_m2;
    rows(index).drag_coefficient_x = shape.cd_xyz(1);
    rows(index).drag_coefficient_y = shape.cd_xyz(2);
    rows(index).drag_coefficient_z = shape.cd_xyz(3);
    rows(index).disturbance_stability_index = disturbance.disturbance_stability_index;
    rows(index).meets_required_volume = true;
    rows(index).meets_size_limit = evaluate_size_limit(cfg, dimensions);
    rows(index).estimated_net_lift_after_envelope_mass_N_internal = estimatedNetLiftAfterEnvelopeMass_N;
end

decisionMatrix = struct2table(rows);

% Compute lower-is-better metric ranks for each candidate.
decisionMatrix.rank_SA_V = rank_lower_better(decisionMatrix.surface_area_to_volume_1_m);
decisionMatrix.rank_disturbance = rank_lower_better(decisionMatrix.disturbance_stability_index);
decisionMatrix.rank_max_dimension = rank_lower_better(decisionMatrix.max_dimension_m);
decisionMatrix.recommendation_note = repmat("Candidate under review", height(decisionMatrix), 1);

analysisMeta.required_volume_m3 = requiredVolume_m3;
analysisMeta.buoyant_force_N = buoyantForce_N;
analysisMeta.surface_density_kg_m2 = surfaceDensity_kg_m2;
analysisMeta.mass_g = mass_g;
analysisMeta.buoyancy_ratio = buoyancyRatio;

end

function ranks = rank_lower_better(values)
if exist('tiedrank', 'file') == 2
    ranks = tiedrank(values);
    return;
end

% Fallback average-rank implementation for tied values.
[sortedValues, sortIndex] = sort(values, 'ascend');
ranks = zeros(size(values));
position = 1;
while position <= numel(sortedValues)
    tieEnd = position;
    while tieEnd < numel(sortedValues) && sortedValues(tieEnd + 1) == sortedValues(position)
        tieEnd = tieEnd + 1;
    end
    averageRank = (position + tieEnd) / 2;
    ranks(sortIndex(position:tieEnd)) = averageRank;
    position = tieEnd + 1;
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