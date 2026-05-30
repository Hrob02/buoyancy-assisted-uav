%% RUN_BUOYANCY_MEASUREMENT_ANALYSIS
% Purpose:
%   Interactive workflow for processing foil-balloon buoyancy measurement
%   experiments for thesis methodology section 3.3.1.
%
% Inputs requested from the user:
%   - Number of balloon sizes tested.
%   - One overall tare mass for the full experiment (optional).
%   - Per balloon: label, stated diameter from packet, optional measured
%     half-circumference, optional brand/material, number of trials.
%   - Per trial: scale reading and optional notes.
%
% Equations used:
%   - C_measured = 2 * C_half_measured
%   - d_measured = C_measured / pi
%   - d_measured = d_packet (fallback when circumference not measured)
%   - V = (4/3) * pi * r^3
%   - F_lift = m_lift * g
%   - F_predicted = (rho_air - rho_helium) * g * V
%
% Outputs generated:
%   - Trial-level table CSV.
%   - Balloon-size summary table CSV.
%   - Processed MAT file containing trial/summary tables and metadata.
%   - Publication-ready figures saved as PNG.
%
% Units used:
%   - Length in m, volume in m^3, mass in g (and kg internally), force in N.
%
% Output location:
%   - matlab/results/buoyancy_measurement/
%   - matlab/figures/buoyancy_measurement/

clc;
close all;

%% Resolve output paths
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    error('BuoyancyMeasurement:PathResolution', ...
        'Could not resolve script path. Run this file directly from MATLAB.');
end

scriptDir = fileparts(scriptPath);
matlabRoot = fileparts(fileparts(scriptDir));
repoRoot = fileparts(matlabRoot);

resultsDir = fullfile(repoRoot, 'matlab', 'results', 'buoyancy_measurement');
figuresDir = fullfile(repoRoot, 'matlab', 'figures', 'buoyancy_measurement');

ensure_output_directory(resultsDir);
ensure_output_directory(figuresDir);

%% Set assumed model constants
fprintf('=== Buoyancy Measurement Analysis ===\n');
fprintf('This workflow processes foil-balloon lift measurements.\n');
fprintf('Using assumed room-condition constants (not experimentally measured in this setup).\n\n');

rhoAir = 1.225;
rhoHelium = 0.164;
gravity = 9.81;

fprintf('Assumed constants: rho_air=%.4f kg/m^3, rho_helium=%.4f kg/m^3, g=%.4f m/s^2\n\n', ...
    rhoAir, rhoHelium, gravity);

%% Collect experiment inputs interactively
numBalloonSizes = prompt_positive_integer('Number of balloon sizes tested: ');
tareMassOverall_g = prompt_optional_nonnegative_number( ...
    'Overall tare mass for experiment [g] (optional, Enter to skip): ');

trialRows = cell(0, 1);
balloonMetadata = struct('BalloonLabel', strings(0, 1), ...
    'NominalDiameter_m', [], ...
    'Brand', strings(0, 1), ...
    'MaterialType', strings(0, 1), ...
    'NumberOfTrials', []);

for balloonIndex = 1:numBalloonSizes
    fprintf('\n--- Balloon %d of %d ---\n', balloonIndex, numBalloonSizes);

    balloonLabel = prompt_text_value(sprintf('Balloon label/name (default "Balloon %d"): ', balloonIndex));
    if strlength(balloonLabel) == 0
        balloonLabel = sprintf('Balloon %d', balloonIndex);
    end

    nominalDiameter_m = prompt_positive_number( ...
        'Stated balloon diameter from packet [m] (used for all trials of this balloon): ');
    measuredHalfCircumference_m = prompt_optional_positive_number( ...
        ['Measured HALF circumference [m] (optional; measured around the widest part, ' ...
        'press Enter to skip): ']);

    if isnan(measuredHalfCircumference_m)
        measuredDiameterFromCircumference_m = NaN;
        measuredCircumference_m = NaN;
    else
        measuredCircumference_m = 2.0 * measuredHalfCircumference_m;
        measuredDiameterFromCircumference_m = measuredCircumference_m / pi;
    end

    brandName = prompt_text_value('Balloon brand/product name (optional): ');
    materialType = prompt_text_value('Balloon material/type (optional): ');
    numberOfTrials = prompt_positive_integer('Number of trials for this balloon: ');

    balloonMetadata.BalloonLabel(end + 1, 1) = string(balloonLabel); %#ok<SAGROW>
    balloonMetadata.NominalDiameter_m(end + 1, 1) = nominalDiameter_m; %#ok<SAGROW>
    balloonMetadata.Brand(end + 1, 1) = string(brandName); %#ok<SAGROW>
    balloonMetadata.MaterialType(end + 1, 1) = string(materialType); %#ok<SAGROW>
    balloonMetadata.NumberOfTrials(end + 1, 1) = numberOfTrials; %#ok<SAGROW>

    for trialIndex = 1:numberOfTrials
        fprintf('\nBalloon "%s" - Trial %d of %d\n', balloonLabel, trialIndex, numberOfTrials);

        tareMass_g = tareMassOverall_g;

        if isfinite(measuredDiameterFromCircumference_m) && measuredDiameterFromCircumference_m > 0
            measuredDiameter_m = measuredDiameterFromCircumference_m;
            diameterSource = "measured_half_circumference_once_per_balloon";
        else
            measuredDiameter_m = nominalDiameter_m;
            diameterSource = "packet_stated_once_per_balloon";
        end

        scaleReading_g = prompt_scale_reading('Scale reading [g] (negative values indicate upward lift): ');

        [measuredLift_g, measuredLift_N] = calculate_lift_from_scale_reading(scaleReading_g, gravity);

        [estimatedVolume_m3, radius_m] = calculate_balloon_volume_from_diameter(measuredDiameter_m);
        [predictedLift_g, predictedLift_N] = calculate_predicted_lift(estimatedVolume_m3, rhoAir, rhoHelium, gravity);

        difference_g = measuredLift_g - predictedLift_g;
        if abs(predictedLift_g) < eps
            percentDifference = NaN;
        else
            percentDifference = (difference_g / predictedLift_g) * 100.0;
        end

        notesText = prompt_text_value('Notes (optional): ');

        trialRows{end + 1, 1} = struct( ...
            'BalloonLabel', string(balloonLabel), ...
            'NominalDiameter_m', nominalDiameter_m, ...
            'TrialNumber', trialIndex, ...
            'TareMass_g', tareMass_g, ...
            'MeasuredHalfCircumference_m', measuredHalfCircumference_m, ...
            'MeasuredCircumference_m', measuredCircumference_m, ...
            'MeasuredDiameter_m', measuredDiameter_m, ...
            'EstimatedVolume_m3', estimatedVolume_m3, ...
            'ScaleReading_g', scaleReading_g, ...
            'MeasuredLift_g', measuredLift_g, ...
            'MeasuredLift_N', measuredLift_N, ...
            'PredictedLift_g', predictedLift_g, ...
            'PredictedLift_N', predictedLift_N, ...
            'Difference_g', difference_g, ...
            'PercentDifference', percentDifference, ...
            'Notes', string(notesText), ...
            'DiameterSource', diameterSource, ...
            'Radius_m', radius_m); %#ok<SAGROW>
    end
end

%% Build output tables
if isempty(trialRows)
    error('BuoyancyMeasurement:NoData', 'No trial data was entered.');
end

trialStruct = vertcat(trialRows{:});
trialTable = struct2table(trialStruct);

trialColumnOrder = { ...
    'BalloonLabel', 'NominalDiameter_m', 'TrialNumber', 'TareMass_g', ...
    'MeasuredHalfCircumference_m', 'MeasuredCircumference_m', ...
    'MeasuredDiameter_m', 'EstimatedVolume_m3', ...
    'ScaleReading_g', 'MeasuredLift_g', 'MeasuredLift_N', ...
    'PredictedLift_g', 'PredictedLift_N', 'Difference_g', ...
    'PercentDifference', 'DiameterSource', 'Notes'};
trialTable = trialTable(:, trialColumnOrder);

summaryTable = create_buoyancy_summary_table(trialTable);

%% Save outputs
trialCsvPath = fullfile(resultsDir, 'buoyancy_measurement_trial_results.csv');
summaryCsvPath = fullfile(resultsDir, 'buoyancy_measurement_summary_results.csv');
matPath = fullfile(resultsDir, 'buoyancy_measurement_processed_data.mat');

writetable(trialTable, trialCsvPath);
writetable(summaryTable, summaryCsvPath);

processedData = struct();
processedData.constants = struct( ...
    'rho_air_kg_m3', rhoAir, ...
    'rho_helium_kg_m3', rhoHelium, ...
    'gravity_m_s2', gravity);
processedData.balloon_metadata = struct2table(balloonMetadata);
processedData.trial_table = trialTable;
processedData.summary_table = summaryTable;
processedData.generated_on = datetime('now');

save(matPath, 'processedData', 'trialTable', 'summaryTable');

figurePaths = plot_buoyancy_measurement_results(trialTable, summaryTable, figuresDir);

%% Completion message
fprintf('\n=== Buoyancy Measurement Analysis Complete ===\n');
fprintf('Trial-level CSV: %s\n', trialCsvPath);
fprintf('Summary CSV: %s\n', summaryCsvPath);
fprintf('Processed MAT: %s\n', matPath);
fprintf('Figures saved in: %s\n', figuresDir);
for i = 1:numel(figurePaths)
    fprintf('  - %s\n', figurePaths{i});
end
fprintf(['\nNote: linear fits are provided for interpretation and extrapolation guidance. ' ...
    'Extrapolation beyond tested balloon volumes is not experimentally validated.\n']);

function value = prompt_positive_number(promptText)
%PROMPT_POSITIVE_NUMBER Prompt repeatedly until a positive numeric scalar is entered.
while true
    raw = input(promptText, 's');
    value = str2double(strtrim(raw));
    if isfinite(value) && isscalar(value) && value > 0
        return;
    end
    fprintf('Invalid input. Enter a positive numeric value.\n');
end
end

function value = prompt_number(promptText)
%PROMPT_NUMBER Prompt repeatedly until a numeric scalar is entered.
while true
    raw = input(promptText, 's');
    value = str2double(strtrim(raw));
    if isfinite(value) && isscalar(value)
        return;
    end
    fprintf('Invalid input. Enter a numeric value.\n');
end
end

function value = prompt_optional_number(promptText)
%PROMPT_OPTIONAL_NUMBER Prompt for numeric scalar; allow blank and return NaN.
while true
    raw = input(promptText, 's');
    raw = strtrim(raw);
    if isempty(raw)
        value = NaN;
        return;
    end

    value = str2double(raw);
    if isfinite(value) && isscalar(value)
        return;
    end
    fprintf('Invalid input. Enter a numeric value or press Enter to skip.\n');
end
end

function value = prompt_optional_nonnegative_number(promptText)
%PROMPT_OPTIONAL_NONNEGATIVE_NUMBER Prompt optional number constrained to >= 0.
while true
    value = prompt_optional_number(promptText);
    if isnan(value) || value >= 0
        return;
    end
    fprintf('Invalid input. Enter a nonnegative value or press Enter to skip.\n');
end
end

function value = prompt_optional_positive_number(promptText)
%PROMPT_OPTIONAL_POSITIVE_NUMBER Prompt optional number constrained to > 0.
while true
    value = prompt_optional_number(promptText);
    if isnan(value) || value > 0
        return;
    end
    fprintf('Invalid input. Enter a positive value or press Enter to skip.\n');
end
end

function value = prompt_positive_integer(promptText)
%PROMPT_POSITIVE_INTEGER Prompt repeatedly until a positive integer is entered.
while true
    raw = input(promptText, 's');
    value = str2double(strtrim(raw));
    if isfinite(value) && isscalar(value) && value > 0 && abs(value - round(value)) < eps
        value = round(value);
        return;
    end
    fprintf('Invalid input. Enter a positive whole number.\n');
end
end

function textValue = prompt_text_value(promptText)
%PROMPT_TEXT_VALUE Read free text from user; blank text is allowed.
raw = input(promptText, 's');
textValue = string(strtrim(raw));
end

function answer = prompt_yes_no(promptText)
%PROMPT_YES_NO Prompt until user enters y/yes or n/no.
while true
    raw = lower(strtrim(input(promptText, 's')));
    if any(strcmp(raw, {'y', 'yes'}))
        answer = true;
        return;
    end
    if any(strcmp(raw, {'n', 'no'}))
        answer = false;
        return;
    end
    fprintf('Invalid input. Please enter y or n.\n');
end
end

function scaleReading_g = prompt_scale_reading(promptText)
%PROMPT_SCALE_READING Prompt for scale reading and confirm positive values.
while true
    scaleReading_g = prompt_number(promptText);
    if scaleReading_g <= 0
        return;
    end

    usePositiveReading = prompt_yes_no( ...
        'Scale reading is positive. Treat this as lift magnitude anyway? [y/n]: ');
    if usePositiveReading
        return;
    end

    fprintf('Please re-enter the scale reading.\n');
end
end

function [volume_m3, radius_m] = calculate_balloon_volume_from_diameter(diameter_m)
%CALCULATE_BALLOON_VOLUME_FROM_DIAMETER Compute spherical radius and volume.
radius_m = diameter_m / 2.0;
volume_m3 = (4.0 / 3.0) * pi * (radius_m ^ 3);
end

function [liftMass_g, liftForce_N] = calculate_lift_from_scale_reading(scaleReading_g, gravity_m_s2)
%CALCULATE_LIFT_FROM_SCALE_READING Convert scale reading to lift mass and force.
liftMass_g = abs(scaleReading_g);
liftForce_N = (liftMass_g / 1000.0) * gravity_m_s2;
end

function [predictedLift_g, predictedLift_N] = calculate_predicted_lift(volume_m3, rhoAir_kg_m3, rhoHelium_kg_m3, gravity_m_s2)
%CALCULATE_PREDICTED_LIFT Compute Archimedes-predicted net lift.
predictedLift_N = (rhoAir_kg_m3 - rhoHelium_kg_m3) * gravity_m_s2 * volume_m3;
predictedLift_g = (predictedLift_N / gravity_m_s2) * 1000.0;
end

function summaryTable = create_buoyancy_summary_table(trialTable)
%CREATE_BUOYANCY_SUMMARY_TABLE Aggregate trial data by balloon label.
[groupIds, groupBalloonLabel, groupNominalDiameter] = findgroups( ...
    trialTable.BalloonLabel, trialTable.NominalDiameter_m);

numberOfTrials = splitapply(@numel, trialTable.TrialNumber, groupIds);
meanMeasuredDiameter = splitapply(@(x) mean(x, 'omitnan'), trialTable.MeasuredDiameter_m, groupIds);
stdMeasuredDiameter = splitapply(@(x) std(x, 'omitnan'), trialTable.MeasuredDiameter_m, groupIds);
meanEstimatedVolume = splitapply(@(x) mean(x, 'omitnan'), trialTable.EstimatedVolume_m3, groupIds);
stdEstimatedVolume = splitapply(@(x) std(x, 'omitnan'), trialTable.EstimatedVolume_m3, groupIds);
meanMeasuredLift_g = splitapply(@(x) mean(x, 'omitnan'), trialTable.MeasuredLift_g, groupIds);
stdMeasuredLift_g = splitapply(@(x) std(x, 'omitnan'), trialTable.MeasuredLift_g, groupIds);
meanMeasuredLift_N = splitapply(@(x) mean(x, 'omitnan'), trialTable.MeasuredLift_N, groupIds);
stdMeasuredLift_N = splitapply(@(x) std(x, 'omitnan'), trialTable.MeasuredLift_N, groupIds);
meanPredictedLift_g = splitapply(@(x) mean(x, 'omitnan'), trialTable.PredictedLift_g, groupIds);
meanPredictedLift_N = splitapply(@(x) mean(x, 'omitnan'), trialTable.PredictedLift_N, groupIds);
meanDifference_g = splitapply(@(x) mean(x, 'omitnan'), trialTable.Difference_g, groupIds);
meanPercentDifference = splitapply(@(x) mean(x, 'omitnan'), trialTable.PercentDifference, groupIds);

summaryTable = table( ...
    groupBalloonLabel, groupNominalDiameter, numberOfTrials, ...
    meanMeasuredDiameter, stdMeasuredDiameter, ...
    meanEstimatedVolume, stdEstimatedVolume, ...
    meanMeasuredLift_g, stdMeasuredLift_g, ...
    meanMeasuredLift_N, stdMeasuredLift_N, ...
    meanPredictedLift_g, meanPredictedLift_N, ...
    meanDifference_g, meanPercentDifference, ...
    'VariableNames', { ...
    'BalloonLabel', 'NominalDiameter_m', 'NumberOfTrials', ...
    'MeanMeasuredDiameter_m', 'StdMeasuredDiameter_m', ...
    'MeanEstimatedVolume_m3', 'StdEstimatedVolume_m3', ...
    'MeanMeasuredLift_g', 'StdMeasuredLift_g', ...
    'MeanMeasuredLift_N', 'StdMeasuredLift_N', ...
    'MeanPredictedLift_g', 'MeanPredictedLift_N', ...
    'MeanDifference_g', 'MeanPercentDifference'});

summaryTable = sortrows(summaryTable, {'NominalDiameter_m', 'BalloonLabel'});
end

function figurePaths = plot_buoyancy_measurement_results(trialTable, summaryTable, outputFolder)
%PLOT_BUOYANCY_MEASUREMENT_RESULTS Generate and save report-ready figures.
figurePaths = {};

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

xVolume = trialTable.EstimatedVolume_m3;
yLiftN = trialTable.MeasuredLift_N;
yLiftG = trialTable.MeasuredLift_g;
xPredictedG = trialTable.PredictedLift_g;

% 1) Volume vs measured lift force (N).
fig1 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 980 620]);
ax1 = axes(fig1);
hold(ax1, 'on');
scatter(ax1, xVolume, yLiftN, 58, 'o', 'MarkerFaceColor', [0.16 0.45 0.70], ...
    'MarkerEdgeColor', [0.05 0.05 0.05], 'DisplayName', 'Measured trials');

[fitY_N, equationTextN, r2TextN] = fit_line_for_plot(xVolume, yLiftN);
if ~isempty(fitY_N)
    [xSorted, sortIdx] = sort(xVolume);
    plot(ax1, xSorted, fitY_N(sortIdx), '-', 'Color', [0.85 0.33 0.10], ...
        'LineWidth', 1.8, 'DisplayName', 'Linear fit');
end

xlabel(ax1, 'Estimated volume [m^3]');
ylabel(ax1, 'Measured lift force [N]');
title(ax1, 'Measured lift force vs estimated balloon volume');
subtitle(ax1, {'Linear fit shown for Archimedes-trend interpretation', ...
    'Use extrapolation beyond tested volume range with caution'});
grid(ax1, 'on');
legend(ax1, 'Location', 'best');

if ~isempty(equationTextN)
    text(ax1, 0.03, 0.95, sprintf('%s\n%s', equationTextN, r2TextN), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', [1 1 1], 'Margin', 8);
end

figurePaths = [figurePaths; save_figure_pair(fig1, outputFolder, 'buoyancy_volume_vs_measured_lift_force')]; %#ok<AGROW>
close(fig1);

% 2) Volume vs measured lift mass (g) with group means.
fig2 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 980 620]);
ax2 = axes(fig2);
hold(ax2, 'on');
scatter(ax2, xVolume, yLiftG, 52, '^', 'MarkerFaceColor', [0.12 0.62 0.42], ...
    'MarkerEdgeColor', [0.05 0.05 0.05], 'DisplayName', 'Measured trials');

scatter(ax2, summaryTable.MeanEstimatedVolume_m3, summaryTable.MeanMeasuredLift_g, 100, 'd', ...
    'MarkerFaceColor', [0.93 0.69 0.13], 'MarkerEdgeColor', [0.05 0.05 0.05], ...
    'DisplayName', 'Mean by balloon size');

[fitY_G, equationTextG, r2TextG] = fit_line_for_plot(xVolume, yLiftG);
if ~isempty(fitY_G)
    [xSorted, sortIdx] = sort(xVolume);
    plot(ax2, xSorted, fitY_G(sortIdx), '-', 'Color', [0.49 0.18 0.56], ...
        'LineWidth', 1.8, 'DisplayName', 'Linear fit');
end

xlabel(ax2, 'Estimated volume [m^3]');
ylabel(ax2, 'Measured lift [g]');
title(ax2, 'Measured lift mass vs estimated balloon volume');
grid(ax2, 'on');
legend(ax2, 'Location', 'best');

if ~isempty(equationTextG)
    text(ax2, 0.03, 0.95, sprintf('%s\n%s', equationTextG, r2TextG), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', [1 1 1], 'Margin', 8);
end

figurePaths = [figurePaths; save_figure_pair(fig2, outputFolder, 'buoyancy_volume_vs_measured_lift_mass')]; %#ok<AGROW>
close(fig2);

% 3) Predicted vs measured lift (g) with 1:1 line.
fig3 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 860 620]);
ax3 = axes(fig3);
hold(ax3, 'on');
scatter(ax3, xPredictedG, yLiftG, 58, 'o', 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerEdgeColor', [0.05 0.05 0.05], 'DisplayName', 'Trials');

combinedValues = [xPredictedG; yLiftG];
maxAxis = max(combinedValues);
if ~isfinite(maxAxis) || maxAxis <= 0
    maxAxis = 1;
end
maxAxis = maxAxis * 1.05;
minAxis = 0;

plot(ax3, [minAxis maxAxis], [minAxis maxAxis], '--k', 'LineWidth', 1.4, ...
    'DisplayName', '1:1 reference');

xlabel(ax3, 'Predicted lift [g]');
ylabel(ax3, 'Measured lift [g]');
title(ax3, 'Predicted vs measured balloon lift');
grid(ax3, 'on');
legend(ax3, 'Location', 'best');
axis(ax3, 'equal');
xlim(ax3, [minAxis maxAxis]);
ylim(ax3, [minAxis maxAxis]);

figurePaths = [figurePaths; save_figure_pair(fig3, outputFolder, 'buoyancy_predicted_vs_measured_lift')]; %#ok<AGROW>
close(fig3);

% 4) Balloon-size summary bar chart with std error bars.
fig4 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 980 620]);
ax4 = axes(fig4);
barValues = summaryTable.MeanMeasuredLift_g;
barErrors = summaryTable.StdMeasuredLift_g;

b = bar(ax4, barValues, 'FaceColor', [0.20 0.52 0.72], 'EdgeColor', 'none'); %#ok<NASGU>
hold(ax4, 'on');
errorbar(ax4, 1:numel(barValues), barValues, barErrors, 'k.', 'LineWidth', 1.4, 'CapSize', 12);
hold(ax4, 'off');

xticks(ax4, 1:height(summaryTable));
xticklabels(ax4, cellstr(summaryTable.BalloonLabel));
xtickangle(ax4, 15);
ylabel(ax4, 'Mean measured lift [g]');
title(ax4, 'Balloon size summary of measured lift');
grid(ax4, 'on');

figurePaths = [figurePaths; save_figure_pair(fig4, outputFolder, 'buoyancy_balloon_size_summary_bar')]; %#ok<AGROW>
close(fig4);

% 5) Residual/error plot.
fig5 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 980 620]);
ax5 = axes(fig5);
residual_g = trialTable.MeasuredLift_g - trialTable.PredictedLift_g;
scatter(ax5, xVolume, residual_g, 55, 's', 'MarkerFaceColor', [0.75 0.32 0.20], ...
    'MarkerEdgeColor', [0.05 0.05 0.05]);
hold(ax5, 'on');
yline(ax5, 0, '--k', 'LineWidth', 1.2);
hold(ax5, 'off');

xlabel(ax5, 'Estimated volume [m^3]');
ylabel(ax5, 'Measured - predicted lift [g]');
title(ax5, 'Residual error vs estimated balloon volume');
subtitle(ax5, 'Positive residual means measured lift exceeded prediction');
grid(ax5, 'on');

figurePaths = [figurePaths; save_figure_pair(fig5, outputFolder, 'buoyancy_residual_error_vs_volume')]; %#ok<AGROW>
close(fig5);
end

function [fitY, equationText, r2Text] = fit_line_for_plot(x, y)
%FIT_LINE_FOR_PLOT Fit y = a*x + b and return equation/R^2 text.
fitY = [];
equationText = '';
r2Text = '';

validMask = isfinite(x) & isfinite(y);
xFit = x(validMask);
yFit = y(validMask);

if numel(xFit) < 2
    return;
end

if abs(max(xFit) - min(xFit)) < eps
    return;
end

coefficients = polyfit(xFit, yFit, 1);
fitY = polyval(coefficients, x);

yFitPred = polyval(coefficients, xFit);
ssRes = sum((yFit - yFitPred) .^ 2);
ssTot = sum((yFit - mean(yFit)) .^ 2);
if ssTot < eps
    rSquared = NaN;
else
    rSquared = 1.0 - (ssRes / ssTot);
end

equationText = sprintf('y = %.4g x + %.4g', coefficients(1), coefficients(2));
r2Text = sprintf('R^2 = %.4f', rSquared);
end

function savedPaths = save_figure_pair(figHandle, outputFolder, fileStem)
%SAVE_FIGURE_PAIR Save a figure as PNG.
pngPath = fullfile(outputFolder, strcat(fileStem, '.png'));

exportgraphics(figHandle, pngPath, 'Resolution', 220);

savedPaths = {pngPath};
end

function ensure_output_directory(folderPath)
%ENSURE_OUTPUT_DIRECTORY Create folder if it does not already exist.
if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end
end
