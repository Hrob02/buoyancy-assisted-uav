function continuousCase = simulate_continuous_hover_case(cfg, battery, buoyancyRatio, etaCase)
%SIMULATE_CONTINUOUS_HOVER_CASE Continuous hover with buoyancy assistance.

massTotal_kg = cfg.vehicle.mass_airframe_kg + cfg.vehicle.battery_mass_kg + cfg.sim.payload_kg;
gravity_m_s2 = cfg.environment.gravity_m_s2;
rhoAir_kg_m3 = cfg.environment.rho_air_kg_m3;
rhoHelium_kg_m3 = cfg.environment.rho_helium_kg_m3;

weight_N = massTotal_kg * gravity_m_s2;
envelopeVolume_m3 = (buoyancyRatio * weight_N) / ((rhoAir_kg_m3 - rhoHelium_kg_m3) * gravity_m_s2);
buoyantForce_N = calculate_buoyancy_force(envelopeVolume_m3, rhoAir_kg_m3, rhoHelium_kg_m3, gravity_m_s2);

remainingLift_N = max(weight_N - buoyantForce_N, 0.0);

rotorRadius_m = cfg.rotor.prop_diameter_m / 2.0;
A_single_m2 = pi * rotorRadius_m^2;
A_total_m2 = cfg.rotor.number_of_rotors * A_single_m2;

[powerIdeal_W, powerElectrical_W] = calculate_hover_power(remainingLift_N, rhoAir_kg_m3, A_total_m2, etaCase.eta_total);
P_electronics_W = cfg.sim.electronics_idle_power_W;
P_cont_propulsion_W = powerElectrical_W;
P_cont_total_W = P_cont_propulsion_W + P_electronics_W;

if P_cont_total_W > 0.0
    derivedEnduranceContinuous_min = battery.E_usable_J / P_cont_total_W / 60.0;
else
    derivedEnduranceContinuous_min = inf;
end

thrustMaxPerRotor_N = polyval(cfg.motor.thrust_poly_per_rotor_N_vs_V, cfg.battery.nominal_voltage_V);
thrustMaxTotal_N = cfg.rotor.number_of_rotors * max(thrustMaxPerRotor_N, 0.0);

continuousCase = struct();
continuousCase.buoyancy_ratio = buoyancyRatio;
continuousCase.eta_case = string(etaCase.name);
continuousCase.eta_total = etaCase.eta_total;
continuousCase.mass_total_kg = massTotal_kg;
continuousCase.weight_N = weight_N;
continuousCase.envelope_volume_m3 = envelopeVolume_m3;
continuousCase.buoyant_force_N = buoyantForce_N;
continuousCase.F_required_N = remainingLift_N;
continuousCase.A_total_m2 = A_total_m2;
continuousCase.P_hover_ideal_W = powerIdeal_W;
continuousCase.P_electronics_W = P_electronics_W;
continuousCase.P_cont_propulsion_W = P_cont_propulsion_W;
continuousCase.P_cont_total_W = P_cont_total_W;
continuousCase.derived_endurance_continuous_min = derivedEnduranceContinuous_min;
continuousCase.F_thrust_max_N = thrustMaxTotal_N;

% Backward-compatible alias used by older scripts.
continuousCase.P_continuous_W = P_cont_total_W;
continuousCase.endurance_continuous_min = continuousCase.derived_endurance_continuous_min;

end
