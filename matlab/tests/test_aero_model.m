%% TEST_AERO_MODEL  Unit tests for aero_model function.

% Add model directory to path
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'model'));

params.rho  = 1.225;
params.S    = 1.0;
params.CL0  = 0.0;
params.CLa  = 2 * pi;  % thin airfoil theory
params.CD0  = 0.01;
params.k    = 0.05;

%% Test 1: Zero angle of attack
[FL, FD] = aero_model(10, 0, params);
assert(abs(FL) < 1e-9, 'Lift should be zero at zero AoA when CL0=0');
assert(FD > 0, 'Drag must be positive');
fprintf('Test 1 passed: zero AoA\n');

%% Test 2: Positive angle of attack produces positive lift
[FL2, ~] = aero_model(10, deg2rad(5), params);
assert(FL2 > 0, 'Lift must be positive for positive AoA');
fprintf('Test 2 passed: positive lift\n');

fprintf('All aero_model tests passed.\n');
