function buoyantForce_N = calculate_buoyancy_force(envelopeVolume_m3, rhoAir_kg_m3, rhoHelium_kg_m3, gravity_m_s2)
%CALCULATE_BUOYANCY_FORCE Buoyant force from helium envelope volume.

buoyantForce_N = (rhoAir_kg_m3 - rhoHelium_kg_m3) * envelopeVolume_m3 * gravity_m_s2;

end
