function [powerIdeal_W, powerElectrical_W] = calculate_hover_power(requiredLift_N, rhoAir_kg_m3, rotorDiskArea_m2, etaTotal)
%CALCULATE_HOVER_POWER Actuator-disk hover power estimate.

requiredLift_N = max(requiredLift_N, 0.0);
if requiredLift_N <= 0.0
    powerIdeal_W = 0.0;
    powerElectrical_W = 0.0;
    return;
end

powerIdeal_W = (requiredLift_N^(3/2)) / sqrt(2.0 * rhoAir_kg_m3 * rotorDiskArea_m2);
powerElectrical_W = powerIdeal_W / max(etaTotal, eps);

end
