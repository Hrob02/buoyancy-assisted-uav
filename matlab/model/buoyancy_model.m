function F_b = buoyancy_model(V_envelope, rho_air, rho_gas)
% BUOYANCY_MODEL  Compute net buoyancy force from gas envelope.
%
%   F_b = buoyancy_model(V_envelope, rho_air, rho_gas)
%
%   Inputs:
%     V_envelope - envelope volume [m^3]
%     rho_air    - ambient air density [kg/m^3]
%     rho_gas    - lifting gas density [kg/m^3]
%
%   Output:
%     F_b - net buoyancy force [N] (positive = upward)

    g   = 9.81;                                    % gravitational acceleration [m/s^2]
    F_b = (rho_air - rho_gas) * V_envelope * g;
end
