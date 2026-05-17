function summaryTable = run_duty_cycle_sweep(cfg, battery, continuousTable)
%RUN_DUTY_CYCLE_SWEEP Evaluate all requested duty-cycle combinations.

numCases = height(continuousTable) * numel(cfg.sweep.T_on_s) * numel(cfg.sweep.T_off_s) * numel(cfg.sweep.startup_energy_cases);

case_id = zeros(numCases, 1);
buoyancy_ratio = zeros(numCases, 1);
T_on_s = zeros(numCases, 1);
T_off_s = zeros(numCases, 1);
T_cycle_s = zeros(numCases, 1);
on_fraction = zeros(numCases, 1);
off_fraction = zeros(numCases, 1);
duty_cycle_type = strings(numCases, 1);
startup_energy_J = zeros(numCases, 1);
P_electronics_W = zeros(numCases, 1);
P_cont_propulsion_W = zeros(numCases, 1);
P_cont_total_W = zeros(numCases, 1);
P_duty_propulsion_avg_W = zeros(numCases, 1);
P_duty_total_W = zeros(numCases, 1);
E_cont_cycle_J = zeros(numCases, 1);
E_duty_cycle_J = zeros(numCases, 1);
propulsion_power_reduction_percent = zeros(numCases, 1);
total_power_reduction_percent = zeros(numCases, 1);
derived_endurance_continuous_min = zeros(numCases, 1);
derived_endurance_duty_min = zeros(numCases, 1);
derived_endurance_improvement_percent = zeros(numCases, 1);
altitude_drop_m = zeros(numCases, 1);
altitude_tolerance_m = zeros(numCases, 1);
altitude_margin_m = zeros(numCases, 1);
F_on_required_N = zeros(numCases, 1);
P_on_required_W = zeros(numCases, 1);
I_on_required_A = zeros(numCases, 1);
altitude_pass = false(numCases, 1);
battery_power_pass = false(numCases, 1);
battery_current_pass = false(numCases, 1);
thrust_pass = false(numCases, 1);
voltage_pass = false(numCases, 1);
power_reduction_pass = false(numCases, 1);
physical_constraints_pass = false(numCases, 1);
feasible = false(numCases, 1);
passes_short_break_definition = false(numCases, 1);
passes_moderate_duty_definition = false(numCases, 1);
passes_strong_duty_definition = false(numCases, 1);
feasible_short_break = false(numCases, 1);
feasible_moderate_duty = false(numCases, 1);
feasible_strong_duty = false(numCases, 1);
failure_reason = strings(numCases, 1);
failed_checks_list = strings(numCases, 1);
eta_case = strings(numCases, 1);
eta_total = zeros(numCases, 1);
sweep_mode = strings(numCases, 1);
is_idealized_neutral_reference = false(numCases, 1);
infeasible_average_power = false(numCases, 1);
infeasible_altitude_tolerance = false(numCases, 1);
infeasible_battery_limit = false(numCases, 1);
infeasible_thrust_capability = false(numCases, 1);
primary_failure_reason = strings(numCases, 1);
failed_check_count = zeros(numCases, 1);

idx = 0;
for c = 1:height(continuousTable)
    cont = table2struct(continuousTable(c, :));
    for startupIdx = 1:numel(cfg.sweep.startup_energy_cases)
        startupEnergy_J_case = cfg.sweep.startup_energy_cases(startupIdx).value_J;
        for tonIdx = 1:numel(cfg.sweep.T_on_s)
            for toffIdx = 1:numel(cfg.sweep.T_off_s)
                idx = idx + 1;

                result = simulate_duty_cycle_case( ...
                    cfg, battery, cont, cfg.sweep.T_on_s(tonIdx), cfg.sweep.T_off_s(toffIdx), startupEnergy_J_case);

                case_id(idx) = idx;
                buoyancy_ratio(idx) = result.buoyancy_ratio;
                T_on_s(idx) = result.T_on_s;
                T_off_s(idx) = result.T_off_s;
                T_cycle_s(idx) = result.T_cycle_s;
                on_fraction(idx) = result.on_fraction;
                off_fraction(idx) = result.off_fraction;
                duty_cycle_type(idx) = result.duty_cycle_type;
                startup_energy_J(idx) = result.startup_energy_J;
                P_electronics_W(idx) = result.P_electronics_W;
                P_cont_propulsion_W(idx) = result.P_cont_propulsion_W;
                P_cont_total_W(idx) = result.P_cont_total_W;
                P_duty_propulsion_avg_W(idx) = result.P_duty_propulsion_avg_W;
                P_duty_total_W(idx) = result.P_duty_total_W;
                E_cont_cycle_J(idx) = result.E_cont_cycle_J;
                E_duty_cycle_J(idx) = result.E_duty_cycle_J;
                propulsion_power_reduction_percent(idx) = result.propulsion_power_reduction_percent;
                total_power_reduction_percent(idx) = result.total_power_reduction_percent;
                derived_endurance_continuous_min(idx) = result.derived_endurance_continuous_min;
                derived_endurance_duty_min(idx) = result.derived_endurance_duty_min;
                derived_endurance_improvement_percent(idx) = result.derived_endurance_improvement_percent;
                altitude_drop_m(idx) = result.altitude_drop_m;
                altitude_tolerance_m(idx) = result.altitude_tolerance_m;
                altitude_margin_m(idx) = result.altitude_margin_m;
                F_on_required_N(idx) = result.F_on_required_N;
                P_on_required_W(idx) = result.P_on_required_W;
                I_on_required_A(idx) = result.I_on_required_A;
                altitude_pass(idx) = result.altitude_pass;
                battery_power_pass(idx) = result.battery_power_pass;
                battery_current_pass(idx) = result.battery_current_pass;
                thrust_pass(idx) = result.thrust_pass;
                voltage_pass(idx) = result.voltage_pass;
                power_reduction_pass(idx) = result.power_reduction_pass;
                physical_constraints_pass(idx) = result.physical_constraints_pass;
                feasible(idx) = result.feasible;
                passes_short_break_definition(idx) = result.passes_short_break_definition;
                passes_moderate_duty_definition(idx) = result.passes_moderate_duty_definition;
                passes_strong_duty_definition(idx) = result.passes_strong_duty_definition;
                feasible_short_break(idx) = result.feasible_short_break;
                feasible_moderate_duty(idx) = result.feasible_moderate_duty;
                feasible_strong_duty(idx) = result.feasible_strong_duty;
                failure_reason(idx) = result.failure_reason;
                failed_checks_list(idx) = result.failed_checks_list;
                eta_case(idx) = result.eta_case;
                eta_total(idx) = result.eta_total;
                sweep_mode(idx) = string(cfg.sweep.active_mode_label);
                is_idealized_neutral_reference(idx) = result.is_idealized_neutral_reference;
                infeasible_average_power(idx) = result.infeasible_average_power;
                infeasible_altitude_tolerance(idx) = result.infeasible_altitude_tolerance;
                infeasible_battery_limit(idx) = result.infeasible_battery_limit;
                infeasible_thrust_capability(idx) = result.infeasible_thrust_capability;
                primary_failure_reason(idx) = result.primary_failure_reason;
                failed_check_count(idx) = result.failed_check_count;
            end
        end
    end
end

summaryTable = table( ...
    case_id, buoyancy_ratio, T_on_s, T_off_s, T_cycle_s, on_fraction, off_fraction, duty_cycle_type, startup_energy_J, ...
    P_electronics_W, P_cont_propulsion_W, P_cont_total_W, P_duty_propulsion_avg_W, P_duty_total_W, ...
    E_cont_cycle_J, E_duty_cycle_J, propulsion_power_reduction_percent, total_power_reduction_percent, ...
    derived_endurance_continuous_min, derived_endurance_duty_min, ...
    derived_endurance_improvement_percent, altitude_drop_m, altitude_tolerance_m, altitude_margin_m, ...
    F_on_required_N, P_on_required_W, I_on_required_A, ...
    altitude_pass, battery_power_pass, battery_current_pass, thrust_pass, voltage_pass, ...
    power_reduction_pass, physical_constraints_pass, feasible, ...
    passes_short_break_definition, passes_moderate_duty_definition, passes_strong_duty_definition, ...
    feasible_short_break, feasible_moderate_duty, feasible_strong_duty, ...
    failure_reason, failed_checks_list, eta_case, eta_total, ...
    sweep_mode, is_idealized_neutral_reference, infeasible_average_power, ...
    infeasible_altitude_tolerance, infeasible_battery_limit, infeasible_thrust_capability, ...
    primary_failure_reason, failed_check_count);

validate_feasibility_consistency(summaryTable);

end

function validate_feasibility_consistency(summaryTable)
expectedFeasible = summaryTable.altitude_pass & summaryTable.battery_power_pass & ...
    summaryTable.battery_current_pass & summaryTable.thrust_pass & ...
    summaryTable.voltage_pass & summaryTable.power_reduction_pass;
feasibleMismatch = summaryTable.case_id(summaryTable.feasible ~= expectedFeasible);
if ~isempty(feasibleMismatch)
    fprintf(2, 'Feasibility assertion failed. Case IDs: %s\n', mat2str(feasibleMismatch'));
end
assert(all(summaryTable.feasible == expectedFeasible), ...
    'Feasibility assertion failed: feasible column does not match required pass conditions.');

expectedAltitudePass = summaryTable.altitude_drop_m <= (summaryTable.altitude_tolerance_m + 1e-12);
altitudeMismatch = summaryTable.case_id(summaryTable.altitude_pass ~= expectedAltitudePass);
if ~isempty(altitudeMismatch)
    fprintf(2, 'Altitude-pass assertion failed. Case IDs: %s\n', mat2str(altitudeMismatch'));
end
assert(all(summaryTable.altitude_pass == expectedAltitudePass), ...
    'Altitude-pass assertion failed: altitude_pass does not match altitude threshold comparison.');

violAltitude = summaryTable.case_id(summaryTable.feasible & ~summaryTable.altitude_pass);
violBatteryPower = summaryTable.case_id(summaryTable.feasible & ~summaryTable.battery_power_pass);
violBatteryCurrent = summaryTable.case_id(summaryTable.feasible & ~summaryTable.battery_current_pass);
violThrust = summaryTable.case_id(summaryTable.feasible & ~summaryTable.thrust_pass);
violVoltage = summaryTable.case_id(summaryTable.feasible & ~summaryTable.voltage_pass);
violPowerReduction = summaryTable.case_id(summaryTable.feasible & ~summaryTable.power_reduction_pass);

allViol = unique([violAltitude; violBatteryPower; violBatteryCurrent; violThrust; violVoltage; violPowerReduction]);
if ~isempty(allViol)
    fprintf(2, 'Feasibility validation failed. Case IDs: %s\n', mat2str(allViol'));
    if ~isempty(violAltitude), fprintf(2, '  altitude_pass violations: %s\n', mat2str(violAltitude')); end
    if ~isempty(violBatteryPower), fprintf(2, '  battery_power_pass violations: %s\n', mat2str(violBatteryPower')); end
    if ~isempty(violBatteryCurrent), fprintf(2, '  battery_current_pass violations: %s\n', mat2str(violBatteryCurrent')); end
    if ~isempty(violThrust), fprintf(2, '  thrust_pass violations: %s\n', mat2str(violThrust')); end
    if ~isempty(violVoltage), fprintf(2, '  voltage_pass violations: %s\n', mat2str(violVoltage')); end
    if ~isempty(violPowerReduction), fprintf(2, '  power_reduction_pass violations: %s\n', mat2str(violPowerReduction')); end
    error('Invalid feasibility state detected: one or more feasible cases failed required checks.');
end

end
