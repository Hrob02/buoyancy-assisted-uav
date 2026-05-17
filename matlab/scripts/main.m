%% MAIN
% Top-level entry point for the buoyancy-assisted UAV MATLAB workflow.

run('setup_paths.m');
fprintf('=== Buoyancy-Assisted UAV Modelling Pipeline ===\n');

fprintf('\nRunning envelope geometry design-screening analysis...\n');
run_envelope_geometry_analysis();

fprintf('\nPipeline complete.\n');