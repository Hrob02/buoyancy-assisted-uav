function cfg = config_duty_cycle_parameters()
%CONFIG_DUTY_CYCLE_PARAMETERS Configuration for Crazyflie duty-cycle analysis.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

cfg.paths.repo_root = repoRoot;
cfg.paths.results_dir = fullfile(repoRoot, 'matlab', 'results', 'duty_cycle');
cfg.paths.figures_dir = fullfile(repoRoot, 'matlab', 'figures', 'duty_cycle');

% Crazyflie and battery evidence-supported baseline values.
cfg.vehicle.mass_airframe_kg = 0.029;
cfg.vehicle.max_payload_kg = 0.015;
cfg.vehicle.battery_mass_kg = 0.0071;
cfg.vehicle.baseline_flight_time_min = 7.0;

cfg.battery.capacity_Ah = 0.250;
cfg.battery.nominal_voltage_V = 3.7;
cfg.battery.max_discharge_C = 15.0;
cfg.battery.usable_energy_fraction = 0.90;

cfg.environment.gravity_m_s2 = 9.81;
cfg.environment.rho_air_kg_m3 = 1.225;
cfg.environment.rho_helium_kg_m3 = 0.1786;

cfg.rotor.prop_diameter_m = 0.047;
cfg.rotor.number_of_rotors = 4;

% Third-order thrust-vs-voltage relation (per rotor) from assumed fit.
% This is kept explicit as an assumption until bench thrust data is added.
cfg.motor.thrust_poly_per_rotor_N_vs_V = [0.0025, -0.0200, 0.1000, -0.0800];

% Sweep definitions.
cfg.sweep.sweep_mode = "diagnostic_buoyancy";
cfg.sweep.include_ideal_neutral_reference = true;
cfg.sweep.include_ideal_reference_in_threshold = false;
cfg.sweep.diagnostic_buoyancy_ratio = 0.40:0.01:0.99;
cfg.sweep.high_buoyancy_ratio = 0.70:0.01:0.99;
cfg.sweep.near_neutral_buoyancy_ratio = 0.85:0.005:0.995;
cfg.sweep.broad_buoyancy_ratio = 0.00:0.025:0.995;
cfg.sweep.custom_buoyancy_ratio = cfg.sweep.high_buoyancy_ratio;

cfg.sweep.T_on_s_diagnostic_buoyancy = 0.10:0.10:1.00;
cfg.sweep.T_off_s_diagnostic_buoyancy = 0.10:0.10:5.00;

cfg.sweep.T_on_s_high_buoyancy = 0.10:0.10:1.00;
cfg.sweep.T_off_s_high_buoyancy = 0.10:0.10:5.00;

cfg.sweep.T_on_s_near_neutral = 0.05:0.05:1.00;
cfg.sweep.T_off_s_near_neutral = 0.10:0.10:5.00;

cfg.sweep.T_on_s_broad = 0.10:0.10:1.00;
cfg.sweep.T_off_s_broad = 0.10:0.10:5.00;

cfg.sweep.T_on_s_custom = cfg.sweep.T_on_s_high_buoyancy;
cfg.sweep.T_off_s_custom = cfg.sweep.T_off_s_high_buoyancy;

cfg.minimum_off_fraction_for_primary_results = 0.0;
cfg.sweep.startup_energy_cases = struct( ...
    'name', {'low', 'medium', 'high'}, ...
    'value_J', {0.01, 0.05, 0.10}, ...
    'evidence_or_assumption', {'assumption', 'assumption', 'assumption'});
cfg.sweep.efficiency_cases = struct( ...
    'name', {'conservative', 'nominal', 'optimistic'}, ...
    'eta_total', {0.50, 0.65, 0.75}, ...
    'evidence_or_assumption', {'assumption', 'assumption', 'assumption'});

cfg.sim.altitude_tolerance_m = 0.25;
cfg.sim.off_thrust_fraction = 0.0;
cfg.sim.electronics_idle_power_W = 0.35;

% Optional payload sweep can be introduced later; this run uses max payload.
cfg.sim.payload_kg = cfg.vehicle.max_payload_kg;

end
