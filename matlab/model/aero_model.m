function [F_lift, F_drag] = aero_model(V, alpha, params)
% AERO_MODEL  Compute aerodynamic lift and drag forces.
%
%   [F_lift, F_drag] = aero_model(V, alpha, params)
%
%   Inputs:
%     V      - airspeed [m/s]
%     alpha  - angle of attack [rad]
%     params - struct with fields:
%                rho  : air density [kg/m^3]
%                S    : reference wing area [m^2]
%                CL0  : zero-alpha lift coefficient [-]
%                CLa  : lift curve slope [1/rad]
%                CD0  : zero-lift drag coefficient [-]
%                k    : induced drag factor [-]
%
%   Outputs:
%     F_lift - lift force [N]
%     F_drag - drag force [N]
%
%   Reference: Placeholder — replace with project-specific model.

    q     = 0.5 * params.rho * V^2;       % dynamic pressure [Pa]
    CL    = params.CL0 + params.CLa * alpha;
    CD    = params.CD0 + params.k * CL^2;

    F_lift = q * params.S * CL;
    F_drag = q * params.S * CD;
end
