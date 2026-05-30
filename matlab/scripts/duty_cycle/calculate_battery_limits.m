function battery = calculate_battery_limits(cfg)
%CALCULATE_BATTERY_LIMITS Compute derived battery limits and usable energy.

battery.capacity_Ah = cfg.battery.capacity_Ah;
battery.nominal_voltage_V = cfg.battery.nominal_voltage_V;
battery.max_discharge_C = cfg.battery.max_discharge_C;

battery.E_bat_Wh = battery.capacity_Ah * battery.nominal_voltage_V;
battery.E_bat_J = battery.E_bat_Wh * 3600.0;
battery.I_max_A = battery.capacity_Ah * battery.max_discharge_C;
battery.P_bat_max_W = battery.nominal_voltage_V * battery.I_max_A;
battery.E_usable_J = cfg.battery.usable_energy_fraction * battery.E_bat_J;

end
