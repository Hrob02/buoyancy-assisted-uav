function [P_total, endurance] = energy_model(F_thrust, params)
% ENERGY_MODEL  Estimate total power and flight endurance.
%
%   [P_total, endurance] = energy_model(F_thrust, params)
%
%   Inputs:
%     F_thrust - required thrust force [N]
%     params   - struct with fields:
%                  eta_motor : motor + ESC efficiency [-]
%                  E_bat     : battery energy capacity [Wh]
%
%   Outputs:
%     P_total   - total electrical power draw [W]
%     endurance - estimated flight time [h]

    % Ideal hover power (actuator disk theory placeholder)
    rho    = 1.225;        % sea-level air density [kg/m^3]
    A_disk = 0.05;         % rotor disk area [m^2] — placeholder

    P_ideal   = F_thrust * sqrt(F_thrust / (2 * rho * A_disk));
    P_total   = P_ideal / params.eta_motor;
    endurance = params.E_bat / P_total;              % hours
end
