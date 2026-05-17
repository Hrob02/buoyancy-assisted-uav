function write_envelope_recommendation_md(cfg, analysis)
%WRITE_ENVELOPE_RECOMMENDATION_MD Write report-facing markdown outputs.

write_assumptions_markdown(cfg, analysis);
write_recommendation_markdown(cfg, analysis);

end

function write_assumptions_markdown(cfg, analysis)
filePath = fullfile(cfg.paths.results_dir, 'envelope_geometry_assumptions.md');
fileId = fopen(filePath, 'w');
assert(fileId ~= -1, 'EnvelopeGeometry:FileOpenFailed', 'Unable to open assumptions markdown for writing.');
cleaner = onCleanup(@() fclose(fileId)); %#ok<NASGU>

fprintf(fileId, '# Envelope Geometry Assumptions\n\n');
fprintf(fileId, '## Analysis framing\n\n');
fprintf(fileId, 'This analysis is a deterministic engineering design-screening study for helium-assisted UAV envelope selection. Equal required buoyant lift is enforced by first computing the helium volume required from system mass and target buoyancy ratio, then comparing candidate shapes at that same required helium volume.\n\n');
fprintf(fileId, 'The final envelope selection is treated as an engineering design decision rather than a statistical claim. The selected shape is justified by metric ranking, engineering significance, Pareto dominance, sensitivity robustness, and practical implementation constraints.\n\n');
fprintf(fileId, 'ANOVA is included as a screening tool only. The primary decision is based on engineering significance because the simulation outputs are deterministic model results, not repeated physical measurements.\n\n');

fprintf(fileId, '## Material-efficiency interpretation\n\n');
fprintf(fileId, 'Surface-area-to-volume ratio was used as the primary material-efficiency metric. For a fixed helium volume, a higher surface-area-to-volume ratio requires more envelope material, increasing the mass that must be supported by the helium lift. This reduces the net useful lift available to offset the UAV weight. Structural mass fraction was therefore not retained as a separate primary metric because it repeats this surface-area effect under the assumed constant surface-density model.\n\n');
fprintf(fileId, 'Surface-area-to-volume ratio is the primary material-efficiency metric. For a fixed required helium volume, a higher surface-area-to-volume ratio means more envelope material is required. This increases the mass that must be supported by the buoyant lift, reducing the net lift available to offset the UAV weight. Therefore, lower surface-area-to-volume ratio is preferred.\n\n');
fprintf(fileId, 'Structural mass fraction was not retained as an independent primary metric because it is directly derived from surface area under the constant reference surface-density assumption. Its design implication is captured through surface-area-to-volume ratio: shapes with higher SA/V require more material for the same helium volume, which reduces the net useful buoyant lift available to support the UAV.\n\n');

fprintf(fileId, '## Inputs and assumptions\n\n');
fprintf(fileId, '- Reference system mass: %.1f g\n', cfg.system.reference_mass_g);
fprintf(fileId, '- Target buoyancy ratio: %.2f\n', cfg.system.target_buoyancy_ratio);
fprintf(fileId, '- Air density: %.3f kg/m^3\n', cfg.environment.rho_air_kg_m3);
fprintf(fileId, '- Helium density: %.3f kg/m^3\n', cfg.environment.rho_helium_kg_m3);
fprintf(fileId, '- Reference surface density: %.3f kg/m^2\n\n', cfg.envelope.sigma_ref_kg_m2);

fprintf(fileId, '## Engineering significance thresholds\n\n');
fprintf(fileId, '- Material efficiency threshold: %.1f%%\n', cfg.engineering_significance.material_efficiency_threshold_percent);
fprintf(fileId, '- Disturbance threshold: %.1f%%\n', cfg.engineering_significance.disturbance_threshold_percent);
fprintf(fileId, '- Footprint threshold: %.1f%%\n', cfg.engineering_significance.footprint_threshold_percent);
fprintf(fileId, '- Score difference threshold: %.1f%%\n\n', cfg.engineering_significance.score_difference_threshold_percent);

fprintf(fileId, '## Practical score assumptions\n\n');
fprintf(fileId, 'Practical implementation scores are qualitative inputs for design screening only. Lower scores are better.\n\n');
for shapeIndex = 1:numel(cfg.shapes)
    shape = cfg.shapes(shapeIndex);
    fprintf(fileId, '- %s: manufacturability score %d, availability score %d, source: %s\n', ...
    char(shape.display_name), shape.manufacturability_score, shape.availability_score, char(shape.practical_score_source));
end

fprintf(fileId, '\n## Metric classification\n\n');
fprintf(fileId, '- surface_area_to_volume_ratio: primary material-efficiency metric\n');
fprintf(fileId, '- estimated_envelope_material_mass: derived material-mass estimate\n');
fprintf(fileId, '- estimated_net_lift_after_envelope_mass: derived useful-lift estimate\n');
fprintf(fileId, '- disturbance_stability_index: primary disturbance metric\n');
fprintf(fileId, '- spatial_footprint: practical metric\n');
fprintf(fileId, '- maximum_dimension: practical metric\n');
fprintf(fileId, '- manufacturability_score: practical metric\n');
fprintf(fileId, '- availability_score: practical metric\n\n');

fprintf(fileId, '## Supplementary statistical note\n\n');
fprintf(fileId, '%s\n', analysis.supplementary_anova_note);
end

function write_recommendation_markdown(cfg, analysis)
filePath = fullfile(cfg.paths.results_dir, 'envelope_shape_recommendation.md');
fileId = fopen(filePath, 'w');
assert(fileId ~= -1, 'EnvelopeGeometry:FileOpenFailed', 'Unable to open recommendation markdown for writing.');
cleaner = onCleanup(@() fclose(fileId)); %#ok<NASGU>

selectedRow = analysis.decision_matrix(analysis.decision_matrix.shape == analysis.selected_shape, :);
comparisonToCuboid = analysis.engineering_significance_summary(strcmp(analysis.engineering_significance_summary.comparison_shape, 'Cuboid') & ...
    strcmp(analysis.engineering_significance_summary.metric, 'weighted_total_score'), :);
selectedShapeChar = char(analysis.selected_shape);

fprintf(fileId, '# Envelope Shape Recommendation\n\n');
fprintf(fileId, '## Purpose of the analysis\n\n');
fprintf(fileId, 'This analysis screens helium envelope geometries for a small UAV by comparing candidate shapes at equal required buoyant lift. The comparison is deterministic and intended to support engineering design selection, not to make statistical claims from repeated physical measurements.\n\n');

fprintf(fileId, '## Comparison with the Macias and Lee method\n\n');
fprintf(fileId, 'Macias and Lee (2022) compared cuboid and spherical envelopes under a fixed dimensional constraint. This repository instead defines the required helium volume from system mass and target buoyancy ratio, then compares candidate shapes at that equal required volume. This framing isolates geometry-dependent penalties and benefits when the required buoyant lift is fixed by the UAV mission need.\n\n');

fprintf(fileId, '## Parameters used\n\n');
fprintf(fileId, '- Reference system mass: %.1f g\n', cfg.system.reference_mass_g);
fprintf(fileId, '- Target buoyancy ratio: %.2f\n', cfg.system.target_buoyancy_ratio);
fprintf(fileId, '- Reference surface density: %.3f kg/m^2\n', cfg.envelope.sigma_ref_kg_m2);
fprintf(fileId, '- Candidate shapes: %s\n\n', strjoin(cellstr(string({cfg.shapes.display_name})), ', '));

fprintf(fileId, '## Equations used\n\n');
fprintf(fileId, '- Required helium volume: V_required = (m_system * BR_target) / (rho_air - rho_helium)\n');
fprintf(fileId, '- Estimated envelope material mass: m_envelope_est = sigma_ref * S\n');
fprintf(fileId, '- Estimated net lift after envelope mass: L_net_est = F_buoyant - m_envelope_est * g\n');
fprintf(fileId, '- Weighted decision score: w_material * normalised_SA_V + w_disturbance * normalised_disturbance + w_spatial * normalised_spatial + w_practicality * normalised_practicality\n\n');

fprintf(fileId, '## Primary metrics\n\n');
fprintf(fileId, 'Surface-area-to-volume ratio was used as the primary material-efficiency metric. For a fixed helium volume, a higher surface-area-to-volume ratio requires more envelope material, increasing the mass that must be supported by the helium lift. This reduces the net useful lift available to offset the UAV weight. Structural mass fraction was therefore not retained as a separate primary metric because it repeats this surface-area effect under the assumed constant surface-density model.\n\n');
fprintf(fileId, 'ANOVA is included as a screening tool only. The primary decision is based on engineering significance because the simulation outputs are deterministic model results, not repeated physical measurements.\n\n');

fprintf(fileId, '## Sensitivity analysis result\n\n');
fprintf(fileId, 'Across the mass, buoyancy-ratio, and surface-density sweep, %s ranked first in %.1f%% of cases and had an average rank of %.2f. This addresses whether the preferred shape remains competitive across reasonable modelling assumptions rather than only at a single nominal point.\n\n', ...
    selectedShapeChar, analysis.selected_shape_rank_first_percent, analysis.selected_shape_average_rank);

fprintf(fileId, '## Pareto result\n\n');
fprintf(fileId, '%s\n\n', analysis.pareto_result_text);

fprintf(fileId, '## Final selected shape\n\n');
fprintf(fileId, 'The selected envelope geometry is **%s**.\n\n', selectedShapeChar);

fprintf(fileId, '## Why it was selected\n\n');
fprintf(fileId, '- It satisfies the required helium volume at the baseline design point.\n');
fprintf(fileId, '- It is not Pareto-dominated under the selected material-efficiency, disturbance, compactness, and manufacturability metrics.\n');
fprintf(fileId, '- It achieves a weighted decision score of %.4f with rank %d.\n', selectedRow.weighted_total_score, selectedRow.rank);
fprintf(fileId, '- It remains robust in the sensitivity sweep.\n');
fprintf(fileId, '- Its manufacturability and availability assumptions do not create a higher practical implementation barrier than the near-best alternatives.\n');
if ~isempty(comparisonToCuboid)
    fprintf(fileId, '- Relative to the cuboid, the weighted decision score improves by %.1f%%.\n', comparisonToCuboid.percent_improvement(1));
end
fprintf(fileId, '\n');

fprintf(fileId, '## Limitations\n\n');
fprintf(fileId, '- The disturbance index is a geometry-based screening proxy, not a CFD solution.\n');
fprintf(fileId, '- Estimated envelope material mass and net lift are derived from an assumed reference surface density and should not be interpreted as measured prototype values.\n');
fprintf(fileId, '- Practical implementation scores are assumptions intended to keep procurement and manufacturing realism visible during concept selection.\n\n');

fprintf(fileId, '## Recommended validation steps\n\n');
fprintf(fileId, '1. Measure actual envelope film areal density and update the derived material-mass estimate.\n');
fprintf(fileId, '2. Validate the disturbance ranking with CFD or controlled flow testing for the leading candidates.\n');
fprintf(fileId, '3. Check packaging, integration, and tethering constraints on a representative UAV mock-up before freezing the shape choice.\n');
end