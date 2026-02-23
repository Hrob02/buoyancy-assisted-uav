%% TEST_BUOYANCY_MODEL  Unit tests for buoyancy_model function.

addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'model'));

%% Test 1: Positive buoyancy when gas is lighter than air
F_b = buoyancy_model(1.0, 1.225, 0.164);
assert(F_b > 0, 'Buoyancy must be positive when gas is lighter than air');
fprintf('Test 1 passed: positive buoyancy\n');

%% Test 2: Zero buoyancy when densities are equal
F_b_zero = buoyancy_model(1.0, 1.225, 1.225);
assert(abs(F_b_zero) < 1e-9, 'Buoyancy must be zero when densities are equal');
fprintf('Test 2 passed: zero buoyancy\n');

fprintf('All buoyancy_model tests passed.\n');
