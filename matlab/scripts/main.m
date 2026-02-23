%% MAIN  Top-level entry point for the buoyancy-assisted UAV modelling pipeline.
%   Runs aerodynamic, buoyancy, and energy models and saves results.

run('setup_paths.m');

fprintf('=== Buoyancy-Assisted UAV Modelling Pipeline ===\n');

%% --- Parameters ---
params.rho  = 1.225;    % air density [kg/m^3]
params.S    = 0.25;     % reference wing area [m^2]
params.CL0  = 0.3;
params.CLa  = 5.7;
params.CD0  = 0.02;
params.k    = 0.05;

params.eta_motor = 0.80;
params.E_bat     = 200;  % [Wh]

V_envelope = 0.5;        % [m^3] — placeholder
rho_gas    = 0.164;      % helium density at sea level [kg/m^3]

%% --- Aerodynamics ---
V     = 10;              % airspeed [m/s]
alpha = deg2rad(5);      % angle of attack [rad]
[F_lift, F_drag] = aero_model(V, alpha, params);
fprintf('Lift: %.2f N  |  Drag: %.2f N\n', F_lift, F_drag);

%% --- Buoyancy ---
F_b = buoyancy_model(V_envelope, params.rho, rho_gas);
fprintf('Buoyancy: %.2f N\n', F_b);

%% --- Energy ---
m_total  = 2.0;          % total vehicle mass [kg]
g        = 9.81;
F_thrust = m_total * g - F_b;
[P_total, endurance] = energy_model(F_thrust, params);
fprintf('Power: %.1f W  |  Endurance: %.2f h\n', P_total, endurance);

fprintf('Pipeline complete.\n');
