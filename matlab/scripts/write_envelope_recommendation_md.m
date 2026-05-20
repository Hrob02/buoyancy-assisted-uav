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
    fprintf(fileId, 'The envelope geometry analysis was treated as a deterministic engineering design-screening study. Candidate shapes were compared directly using geometry-derived metrics: surface-area-to-volume ratio, disturbance stability index, and maximum dimension. Differences between shapes were interpreted using engineering-significance thresholds rather than statistical hypothesis testing.\n\n');
    fprintf(fileId, 'The final recommendation was not selected by a weighted optimisation score. It was based on whether the shape was non-dominated, ranked best or near-best across the supported metrics, and remained robust across the sensitivity analysis.\n\n');

fprintf(fileId, '## Exclusion of unsupported practicality scoring\n\n');
fprintf(fileId, 'Manufacturability, availability, and mounting practicality were not included in the quantitative decision process because no specific manufacturing process, procurement pathway, or mounting mechanism was modelled. Including these factors numerically would introduce unsupported assumptions. Practical implementation considerations may still be discussed qualitatively but are not used to select the final shape.\n\n');

fprintf(fileId, '## Material-efficiency interpretation\n\n');
fprintf(fileId, 'Surface-area-to-volume ratio was used as the primary material-efficiency metric. For a fixed helium volume, a higher surface-area-to-volume ratio requires more envelope material, increasing the mass that must be supported by the helium lift. This reduces the net useful lift available to offset the UAV weight. Structural mass fraction was therefore not retained as a separate primary metric because it repeats this surface-area effect under the assumed constant surface-density model.\n\n');

fprintf(fileId, '## Inputs and assumptions\n\n');
fprintf(fileId, '- Reference system mass: %.1f g\n', cfg.system.reference_mass_g);
fprintf(fileId, '- Target buoyancy ratio: %.2f\n', cfg.system.target_buoyancy_ratio);
fprintf(fileId, '- Air density: %.3f kg/m^3\n', cfg.environment.rho_air_kg_m3);
fprintf(fileId, '- Helium density: %.3f kg/m^3\n', cfg.environment.rho_helium_kg_m3);
fprintf(fileId, '- Reference surface density: %.3f kg/m^2\n\n', cfg.envelope.sigma_ref_kg_m2);

fprintf(fileId, '## Engineering significance thresholds\n\n');
fprintf(fileId, '- Material efficiency threshold: %.1f%%\n', cfg.engineering_significance.material_efficiency_threshold_percent);
fprintf(fileId, '- Disturbance threshold: %.1f%%\n', cfg.engineering_significance.disturbance_threshold_percent);
fprintf(fileId, '- Size threshold: %.1f%%\n\n', cfg.engineering_significance.size_threshold_percent);

fprintf(fileId, '## Primary metric set\n\n');
fprintf(fileId, '- surface_area_to_volume_1_m: primary material-efficiency metric\n');
fprintf(fileId, '- disturbance_stability_index: primary disturbance metric\n');
fprintf(fileId, '- max_dimension_m: size-envelope metric\n');
fprintf(fileId, '- projected_area_xy_m2, projected_area_xz_m2, projected_area_yz_m2: transparency metrics used by disturbance calculations\n\n');


end

function write_recommendation_markdown(cfg, analysis)
filePath = fullfile(cfg.paths.results_dir, 'envelope_shape_recommendation.md');
fileId = fopen(filePath, 'w');
assert(fileId ~= -1, 'EnvelopeGeometry:FileOpenFailed', 'Unable to open recommendation markdown for writing.');
cleaner = onCleanup(@() fclose(fileId)); %#ok<NASGU>

selectedRow = analysis.decision_matrix(analysis.decision_matrix.shape == analysis.selected_shape, :);
selectedShapeChar = char(analysis.selected_shape);

fprintf(fileId, '# Envelope Shape Recommendation\n\n');
fprintf(fileId, '## Purpose of the analysis\n\n');

    fprintf(fileId, 'This analysis screens helium envelope geometries for a small UAV by comparing candidate shapes at equal required buoyant lift. The comparison is deterministic and intended to support engineering design selection, not to make statistical claims from repeated physical measurements.\n\n');
    fprintf(fileId, '## Comparison method\n\n');
    fprintf(fileId, 'The envelope geometry analysis was treated as a deterministic engineering design-screening study. Candidate shapes were compared directly using geometry-derived metrics: surface-area-to-volume ratio, disturbance stability index, and maximum dimension. Differences between shapes were interpreted using engineering-significance thresholds rather than statistical hypothesis testing.\n\n');

fprintf(fileId, '## Parameters used\n\n');
fprintf(fileId, '- Reference system mass: %.1f g\n', cfg.system.reference_mass_g);
fprintf(fileId, '- Target buoyancy ratio: %.2f\n', cfg.system.target_buoyancy_ratio);
fprintf(fileId, '- Reference surface density: %.3f kg/m^2\n', cfg.envelope.sigma_ref_kg_m2);
fprintf(fileId, '- Candidate shapes: %s\n\n', strjoin(cellstr(string({cfg.shapes.display_name})), ', '));

fprintf(fileId, '## Equations used\n\n');
fprintf(fileId, '- Required helium volume: V_required = (m_system * BR_target) / (rho_air - rho_helium)\n');
fprintf(fileId, '- Estimated envelope material mass: m_envelope_est = sigma_ref * S\n');
fprintf(fileId, '- Estimated net lift after envelope mass: L_net_est = F_buoyant - m_envelope_est * g\n\n');

fprintf(fileId, '## Sensitivity robustness\n\n');
fprintf(fileId, '%s\n\n', analysis.selected_shape_robustness_note);

fprintf(fileId, '## Pareto result\n\n');
fprintf(fileId, '%s\n\n', analysis.pareto_result_text);

fprintf(fileId, '## Final selected shape\n\n');
fprintf(fileId, 'The selected envelope geometry is **%s**.\n\n', selectedShapeChar);

fprintf(fileId, '## Why it was selected\n\n');
fprintf(fileId, '- It satisfies required-volume and size-constraint checks in the deterministic screening model.\n');
fprintf(fileId, '- It is not Pareto-dominated under the selected material-efficiency, disturbance, and size-envelope metrics.\n');
fprintf(fileId, '- It is best or near-best across the primary metrics using separate per-metric ranks (SA/V rank %.1f, disturbance rank %.1f, max-dimension rank %.1f).\n', ...
    selectedRow.rank_SA_V, selectedRow.rank_disturbance, selectedRow.rank_max_dimension);
fprintf(fileId, '- It remained non-Pareto-dominated in %.1f%% of sensitivity cases.\n', analysis.selected_shape_non_pareto_percent);
fprintf(fileId, '- The final recommendation was not selected by a weighted optimisation score. It was based on whether the shape was non-dominated, ranked best or near-best across the supported metrics, and remained robust across the sensitivity analysis.\n\n');

fprintf(fileId, '## Limitations\n\n');
fprintf(fileId, '- The disturbance index is a geometry-based screening proxy, not a CFD solution.\n');
fprintf(fileId, '- Estimated envelope material mass and net lift are derived from an assumed reference surface density and should not be interpreted as measured prototype values.\n');
fprintf(fileId, '- Practical implementation considerations can be discussed qualitatively, but they are not quantitatively ranked unless explicit manufacturing, procurement, and mounting models are defined.\n\n');

fprintf(fileId, '## Recommended validation steps\n\n');
fprintf(fileId, '1. Measure actual envelope film areal density and update the derived material-mass estimate.\n');
fprintf(fileId, '2. Validate the disturbance ranking with CFD or controlled flow testing for the leading candidates.\n');
fprintf(fileId, '3. Check packaging, integration, and tethering constraints on a representative UAV mock-up before freezing the shape choice.\n');
end
