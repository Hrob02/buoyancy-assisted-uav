function requiredVolume_m3 = calculate_required_volume(mass_g, buoyancyRatio, cfg)
%CALCULATE_REQUIRED_VOLUME Compute helium volume required for target buoyancy ratio.

mass_kg = mass_g ./ 1000;
rhoDelta_kg_m3 = cfg.environment.rho_air_kg_m3 - cfg.environment.rho_helium_kg_m3;

if rhoDelta_kg_m3 <= 0
    error('EnvelopeGeometry:InvalidDensity', ...
        'Air density must exceed helium density to produce buoyant lift.');
end

requiredVolume_m3 = (mass_kg .* buoyancyRatio) ./ rhoDelta_kg_m3;

end