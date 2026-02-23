%% SETUP_PATHS  Add MATLAB workspace subdirectories to the path.
%   Run this script once per MATLAB session before executing any other
%   scripts in this workspace.

matlab_root = fileparts(fileparts(mfilename('fullpath')));

addpath(fullfile(matlab_root, 'model'));
addpath(fullfile(matlab_root, 'scripts'));
addpath(fullfile(matlab_root, 'data'));

fprintf('MATLAB path configured. Root: %s\n', matlab_root);
