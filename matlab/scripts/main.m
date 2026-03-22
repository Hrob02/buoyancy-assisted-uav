%% MAIN
% Top-level entry point for the buoyancy-assisted UAV MATLAB workflow.

run('setup_paths.m');
fprintf('=== Buoyancy-Assisted UAV Modelling Pipeline ===\n');

fprintf('\nRunning helium envelope trade study...\n');
run('envelope_trade_study.m');

fprintf('\nPipeline complete.\n');