function caseResult = simulate_duty_cycle_case(cfg, battery, continuousCase, T_on_s, T_off_s, startupEnergy_J)
%SIMULATE_DUTY_CYCLE_CASE Simulate one duty-cycle thrust case.

T_cycle_s = T_on_s + T_off_s;
on_fraction = T_on_s / max(T_cycle_s, eps);
off_fraction = T_off_s / max(T_cycle_s, eps);

passes_short_break_definition = ...
    (off_fraction >= cfg.thresholds.short_break_min_off_fraction) && ...
    (T_off_s >= cfg.thresholds.short_break_min_T_off_s);
passes_moderate_duty_definition = ...
    (off_fraction >= cfg.thresholds.moderate_min_off_fraction) && ...
    (T_off_s >= cfg.thresholds.moderate_min_T_off_s);
passes_strong_duty_definition = ...
    (off_fraction >= cfg.thresholds.strong_min_off_fraction) && ...
    (T_off_s >= cfg.thresholds.strong_min_T_off_s);

if off_fraction < 0.25
    duty_cycle_type = "short_break_pulsing";
elseif off_fraction < 0.50
    duty_cycle_type = "moderate_duty_cycle";
else
    duty_cycle_type = "strong_duty_cycle";
end

F_off_N = cfg.sim.off_thrust_fraction * continuousCase.F_required_N;

[~, P_off_propulsion_W] = calculate_hover_power(F_off_N, cfg.environment.rho_air_kg_m3, continuousCase.A_total_m2, continuousCase.eta_total);

a_off_m_s2 = (continuousCase.buoyant_force_N + F_off_N - continuousCase.weight_N) / continuousCase.mass_total_kg;
if a_off_m_s2 < 0.0
    drop_off_m = 0.5 * abs(a_off_m_s2) * T_off_s^2;
else
    drop_off_m = 0.0;
end

a_recovery_required_m_s2 = 2.0 * drop_off_m / max(T_on_s^2, eps);
F_on_required_N = max(continuousCase.F_required_N + continuousCase.mass_total_kg * a_recovery_required_m_s2, 0.0);

[~, P_on_propulsion_W] = calculate_hover_power(F_on_required_N, cfg.environment.rho_air_kg_m3, continuousCase.A_total_m2, continuousCase.eta_total);
P_electronics_W = continuousCase.P_electronics_W;

E_cont_cycle_J = continuousCase.P_cont_total_W * T_cycle_s;
E_duty_propulsion_cycle_J = P_on_propulsion_W * T_on_s + P_off_propulsion_W * T_off_s + startupEnergy_J;
P_duty_propulsion_avg_W = E_duty_propulsion_cycle_J / max(T_cycle_s, eps);
P_duty_total_W = P_duty_propulsion_avg_W + P_electronics_W;
E_duty_cycle_J = P_duty_total_W * T_cycle_s;

I_on_required_A = (P_on_propulsion_W + P_electronics_W) / max(battery.nominal_voltage_V, eps);

% Endurance is derived directly from average power and is therefore not treated as an independent assessment metric.
if continuousCase.P_cont_total_W > 0.0
    derived_endurance_continuous_min = battery.E_usable_J / continuousCase.P_cont_total_W / 60.0;
else
    derived_endurance_continuous_min = inf;
end

if P_duty_total_W > 0.0
    derived_endurance_duty_min = battery.E_usable_J / P_duty_total_W / 60.0;
else
    derived_endurance_duty_min = inf;
end

if continuousCase.P_cont_propulsion_W > 0.0
    propulsion_power_reduction_percent = 100.0 * (continuousCase.P_cont_propulsion_W - P_duty_propulsion_avg_W) / continuousCase.P_cont_propulsion_W;
else
    propulsion_power_reduction_percent = 0.0;
end

if continuousCase.P_cont_total_W > 0.0
    total_power_reduction_percent = 100.0 * (continuousCase.P_cont_total_W - P_duty_total_W) / continuousCase.P_cont_total_W;
else
    total_power_reduction_percent = 0.0;
end

if isfinite(derived_endurance_continuous_min) && derived_endurance_continuous_min > 0.0
    derived_endurance_improvement_percent = 100.0 * (derived_endurance_duty_min - derived_endurance_continuous_min) / derived_endurance_continuous_min;
else
    derived_endurance_improvement_percent = 0.0;
end

% Voltage required for requested per-rotor thrust using cubic fit inversion.
perRotorThrust_N = F_on_required_N / cfg.rotor.number_of_rotors;
polyCoeff = cfg.motor.thrust_poly_per_rotor_N_vs_V;
rootsV = roots([polyCoeff(1), polyCoeff(2), polyCoeff(3), polyCoeff(4) - perRotorThrust_N]);
realRootsV = real(rootsV(abs(imag(rootsV)) < 1e-8));
realRootsV = realRootsV(realRootsV > 0.0);
if isempty(realRootsV)
    requiredMotorVoltage_V = nan;
else
    requiredMotorVoltage_V = min(realRootsV);
end

failureReasons = {};
failedChecks = {};

altitude_tolerance_m = cfg.sim.altitude_tolerance_m;
altitude_margin_m = altitude_tolerance_m - drop_off_m;
altitude_pass = drop_off_m <= altitude_tolerance_m;

battery_power_pass = (P_on_propulsion_W + P_electronics_W) <= battery.P_bat_max_W;
battery_current_pass = I_on_required_A <= battery.I_max_A;
thrust_pass = F_on_required_N <= continuousCase.F_thrust_max_N;
voltage_pass = ~isnan(requiredMotorVoltage_V) && (requiredMotorVoltage_V <= cfg.battery.nominal_voltage_V);
power_reduction_pass = P_duty_total_W < continuousCase.P_cont_total_W;

physical_constraints_pass = altitude_pass && battery_power_pass && battery_current_pass && thrust_pass && voltage_pass;
isFeasible = physical_constraints_pass && power_reduction_pass;
feasible_short_break = isFeasible && passes_short_break_definition;
feasible_moderate_duty = isFeasible && passes_moderate_duty_definition;
feasible_strong_duty = isFeasible && passes_strong_duty_definition;

infeasible_average_power = ~power_reduction_pass;
infeasible_altitude_tolerance = ~altitude_pass;
infeasible_battery_limit = ~(battery_power_pass && battery_current_pass);
infeasible_thrust_capability = ~thrust_pass;

if ~power_reduction_pass
    failedChecks{end + 1} = 'average_power_not_lower_than_continuous'; %#ok<AGROW>
    failureReasons{end + 1} = 'average_power_not_lower_than_continuous'; %#ok<AGROW>
end
if ~altitude_pass
    failedChecks{end + 1} = 'altitude_drop_exceeds_tolerance'; %#ok<AGROW>
    failureReasons{end + 1} = 'altitude_drop_exceeds_tolerance'; %#ok<AGROW>
end
if ~battery_power_pass
    failedChecks{end + 1} = 'burst_power_exceeds_battery_limit'; %#ok<AGROW>
    failureReasons{end + 1} = 'burst_power_exceeds_battery_limit'; %#ok<AGROW>
end
if ~battery_current_pass
    failedChecks{end + 1} = 'burst_current_exceeds_battery_limit'; %#ok<AGROW>
    failureReasons{end + 1} = 'burst_current_exceeds_battery_limit'; %#ok<AGROW>
end
if ~thrust_pass
    failedChecks{end + 1} = 'required_thrust_exceeds_crazyflie_capability'; %#ok<AGROW>
    failureReasons{end + 1} = 'required_thrust_exceeds_crazyflie_capability'; %#ok<AGROW>
end
if ~voltage_pass
    failedChecks{end + 1} = 'required_motor_voltage_above_nominal_or_invalid'; %#ok<AGROW>
end
if ~isnan(requiredMotorVoltage_V) && requiredMotorVoltage_V > cfg.battery.nominal_voltage_V
    failureReasons{end + 1} = 'required_motor_voltage_above_nominal'; %#ok<AGROW>
end
if continuousCase.buoyancy_ratio > 1.0
    failureReasons{end + 1} = 'positively_buoyant_flag'; %#ok<AGROW>
end
if continuousCase.F_required_N <= 0.0
    failureReasons{end + 1} = 'no_positive_lift_required_clamped_to_zero'; %#ok<AGROW>
end

failedCheckCount = numel(failedChecks);
if isFeasible
    failureReason = '';
    failedChecksList = '';
    primaryFailureReason = '';
else
    failureReason = strjoin(failureReasons, ';');
    failedChecksList = strjoin(failedChecks, ';');
    if ~altitude_pass
        primaryFailureReason = 'altitude_drop_exceeds_tolerance';
    elseif ~thrust_pass
        primaryFailureReason = 'required_thrust_exceeds_crazyflie_capability';
    elseif ~(battery_power_pass && battery_current_pass)
        primaryFailureReason = 'battery_power_or_current_exceeded';
    elseif ~voltage_pass
        primaryFailureReason = 'required_motor_voltage_above_nominal_or_invalid';
    elseif ~power_reduction_pass
        primaryFailureReason = 'average_power_not_lower_than_continuous';
    else
        primaryFailureReason = char(failureReasons{1});
    end
end

caseResult = struct();
caseResult.buoyancy_ratio = continuousCase.buoyancy_ratio;
caseResult.T_on_s = T_on_s;
caseResult.T_off_s = T_off_s;
caseResult.T_cycle_s = T_cycle_s;
caseResult.on_fraction = on_fraction;
caseResult.off_fraction = off_fraction;
caseResult.duty_cycle_type = duty_cycle_type;
caseResult.startup_energy_J = startupEnergy_J;
caseResult.P_electronics_W = P_electronics_W;
caseResult.P_cont_propulsion_W = continuousCase.P_cont_propulsion_W;
caseResult.P_cont_total_W = continuousCase.P_cont_total_W;
caseResult.P_duty_propulsion_avg_W = P_duty_propulsion_avg_W;
caseResult.P_duty_total_W = P_duty_total_W;
caseResult.E_cont_cycle_J = E_cont_cycle_J;
caseResult.E_duty_cycle_J = E_duty_cycle_J;
caseResult.propulsion_power_reduction_percent = propulsion_power_reduction_percent;
caseResult.total_power_reduction_percent = total_power_reduction_percent;
caseResult.derived_endurance_continuous_min = derived_endurance_continuous_min;
caseResult.derived_endurance_duty_min = derived_endurance_duty_min;
caseResult.derived_endurance_improvement_percent = derived_endurance_improvement_percent;
caseResult.altitude_drop_m = drop_off_m;
caseResult.altitude_tolerance_m = altitude_tolerance_m;
caseResult.altitude_margin_m = altitude_margin_m;
caseResult.F_on_required_N = F_on_required_N;
caseResult.P_on_required_W = P_on_propulsion_W + P_electronics_W;
caseResult.I_on_required_A = I_on_required_A;
caseResult.altitude_pass = altitude_pass;
caseResult.battery_power_pass = battery_power_pass;
caseResult.battery_current_pass = battery_current_pass;
caseResult.thrust_pass = thrust_pass;
caseResult.voltage_pass = voltage_pass;
caseResult.power_reduction_pass = power_reduction_pass;
caseResult.physical_constraints_pass = physical_constraints_pass;
caseResult.feasible = isFeasible;
caseResult.passes_short_break_definition = passes_short_break_definition;
caseResult.passes_moderate_duty_definition = passes_moderate_duty_definition;
caseResult.passes_strong_duty_definition = passes_strong_duty_definition;
caseResult.feasible_short_break = feasible_short_break;
caseResult.feasible_moderate_duty = feasible_moderate_duty;
caseResult.feasible_strong_duty = feasible_strong_duty;
caseResult.failure_reason = string(failureReason);
caseResult.failed_checks_list = string(failedChecksList);
caseResult.eta_case = continuousCase.eta_case;
caseResult.eta_total = continuousCase.eta_total;
caseResult.infeasible_average_power = infeasible_average_power;
caseResult.infeasible_altitude_tolerance = infeasible_altitude_tolerance;
caseResult.infeasible_battery_limit = infeasible_battery_limit;
caseResult.infeasible_thrust_capability = infeasible_thrust_capability;
caseResult.primary_failure_reason = string(primaryFailureReason);
caseResult.is_idealized_neutral_reference = abs(continuousCase.buoyancy_ratio - 1.0) < 1e-12;
caseResult.failed_check_count = failedCheckCount;

% Backward-compatible aliases used by earlier reporting code.
caseResult.P_continuous_W = caseResult.P_cont_total_W;
caseResult.P_avg_duty_W = caseResult.P_duty_total_W;
caseResult.power_reduction_percent = caseResult.total_power_reduction_percent;
caseResult.endurance_continuous_min = caseResult.derived_endurance_continuous_min;
caseResult.endurance_duty_min = caseResult.derived_endurance_duty_min;
caseResult.endurance_improvement_percent = caseResult.derived_endurance_improvement_percent;

% Practical engineering significance assessment.
if total_power_reduction_percent < cfg.practical_significance.negligible_threshold_percent
    practical_significance_category = "negligible";
elseif total_power_reduction_percent < cfg.practical_significance.marginal_threshold_percent
    practical_significance_category = "marginal";
elseif total_power_reduction_percent < cfg.practical_significance.moderate_threshold_percent
    practical_significance_category = "moderate";
else
    practical_significance_category = "strong";
end

passes_practical_followup_threshold = isFeasible && (total_power_reduction_percent >= cfg.practical_significance.minimum_followup_threshold_percent);

caseResult.practical_significance_category = string(practical_significance_category);
caseResult.passes_practical_followup_threshold = passes_practical_followup_threshold;

end
