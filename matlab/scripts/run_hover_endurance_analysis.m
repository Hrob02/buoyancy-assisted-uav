%% RUN_HOVER_ENDURANCE_ANALYSIS
% Purpose:
%   Interactive workflow for processing Crazyflie hover endurance
%   experiments comparing baseline unassisted and helium-assisted setups.
%
% Inputs requested from the user:
%   - Baseline unassisted: assembly mass, number of trials, optional notes.
%   - Assisted: measured balloon lift, assembly mass, number of trials,
%     optional notes.
%   - Per trial: battery metadata (optional), hover duration, stop condition,
%     validity flag, optional trial notes.
%
% Equations used:
%   - W_assembly = m_assembly * g
%   - F_lift = m_lift * g
%   - BR_physical = F_lift / W_assembly
%   - Delta_t_percent = 100 * (mean_assisted - mean_baseline) / mean_baseline
%
% Outputs generated:
%   - Trial-level CSV table.
%   - Configuration summary CSV table.
%   - Endurance comparison CSV table.
%   - Validity and warning summary CSV table.
%   - Statistical analysis summary CSV table.
%   - Thesis-ready PNG figures.
%   - Text summary report.
%
% Units used:
%   - Mass in g (kg internally where needed), force in N, time in s and min,
%     battery in percent.
%
% Output location:
%   - matlab/results/hover_endurance/
%   - matlab/figures/hover_endurance/

clc;
close all;

%% Resolve output path
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    error('HoverEndurance:PathResolution', ...
        'Could not resolve script path. Run this file directly from MATLAB.');
end

scriptDir = fileparts(scriptPath);
matlabRoot = fileparts(scriptDir);
repoRoot = fileparts(matlabRoot);
resultsDir = fullfile(repoRoot, 'matlab', 'results', 'hover_endurance');
ensure_output_directory(resultsDir);
figuresDir = fullfile(repoRoot, 'matlab', 'figures', 'hover_endurance');
ensure_output_directory(figuresDir);
clear_output_directory(resultsDir);
clear_output_directory(figuresDir);

%% Define constants and fixed experiment setup
uavModel = "Crazyflie 2.1+";
gravity_m_s2 = 9.81;

configurationLabels = ["Baseline unassisted"; "Assisted"];

fprintf('=== Hover Endurance Analysis ===\n');
fprintf('UAV model: %s\n', uavModel);
fprintf('Configurations are fixed: Baseline unassisted and Assisted.\n');
fprintf('Trial data source: crazyflie/trial_results/*_hover_trial.csv\n');
fprintf('Gravity constant: g = %.2f m/s^2\n\n', gravity_m_s2);

%% Collect experiment data from flight-script outputs
trialResultsCsvDir = fullfile(repoRoot, 'crazyflie', 'trial_results');
trialRows = collect_trial_rows_from_flight_csvs(trialResultsCsvDir, uavModel, gravity_m_s2);

if isempty(trialRows)
    error('HoverEndurance:NoData', ...
        'No usable trial data found in crazyflie/trial_results. Expected *_hover_trial.csv files.');
end

%% Build and save trial-level table
trialTable = struct2table(vertcat(trialRows{:}));
trialTable = trialTable(:, { ...
    'ConfigurationLabel', 'UAVModel', 'IsBaseline', 'TrialNumber', 'BatteryID', ...
    'InitialBattery_percent', 'FinalBattery_percent', ...
    'BatteryUsed_percent', 'HoverSecondsPerBatteryPercent', ...
    'AssemblyMass_g', 'AssemblyWeight_N', ...
    'MeasuredBalloonLift_g', 'MeasuredBalloonLift_N', 'BR_physical', ...
    'HoverDuration_s', 'HoverDuration_min', 'StopCondition', 'IsValid', ...
    'ConfigurationNotes', 'TrialNotes'});

trialCsvPath = fullfile(resultsDir, 'hover_endurance_trial_results.csv');
writetable(trialTable, trialCsvPath);

%% Build configuration summary and comparison tables
summaryTable = create_hover_endurance_summary_table(trialTable, configurationLabels, uavModel);
summaryCsvPath = fullfile(resultsDir, 'hover_endurance_summary_results.csv');
writetable(summaryTable, summaryCsvPath);

comparisonTable = create_hover_endurance_comparison_table(summaryTable);
comparisonCsvPath = fullfile(resultsDir, 'hover_endurance_comparison_summary.csv');
writetable(comparisonTable, comparisonCsvPath);

%% Analyze voltage drop rates from Crazyflie trial CSV files
[voltageDropTrialTable, voltageDropSummaryTable, voltageDropComparisonTable, voltageDropWarnings] = ...
    analyze_voltage_drop_from_trial_csvs(trialResultsCsvDir);

voltageDropTrialCsvPath = fullfile(resultsDir, 'hover_endurance_voltage_drop_trial_rates.csv');
writetable(voltageDropTrialTable, voltageDropTrialCsvPath);

voltageDropSummaryCsvPath = fullfile(resultsDir, 'hover_endurance_voltage_drop_summary.csv');
writetable(voltageDropSummaryTable, voltageDropSummaryCsvPath);

voltageDropComparisonCsvPath = fullfile(resultsDir, 'hover_endurance_voltage_drop_comparison.csv');
writetable(voltageDropComparisonTable, voltageDropComparisonCsvPath);

%% Evaluate validity and warnings
warningMessages = strings(0, 1);

if any(~trialTable.IsValid)
    warningMessages(end + 1, 1) = ...
        "Invalid trials were excluded from the main endurance comparison."; %#ok<SAGROW>
end

validRows = trialTable(trialTable.IsValid, :);
baselineValidRows = validRows(validRows.IsBaseline, :);
assistedValidRows = validRows(~validRows.IsBaseline, :);

baselineAllRows = trialTable(trialTable.IsBaseline, :);
assistedAllRows = trialTable(~trialTable.IsBaseline, :);

baselineStopConditions = normalize_stop_condition_set(baselineAllRows.StopCondition);
assistedStopConditions = normalize_stop_condition_set(assistedAllRows.StopCondition);

if ~isequal(baselineStopConditions, assistedStopConditions)
    warningMessages(end + 1, 1) = ...
        "Endurance comparison should be interpreted cautiously because stop conditions differed between configurations."; %#ok<SAGROW>
end

if has_non_battery_related_valid_stop(validRows.StopCondition)
    warningMessages(end + 1, 1) = ...
        "One or more valid trials ended due to non-battery-related conditions. Interpret endurance comparison cautiously."; %#ok<SAGROW>
end

baselineMeanInitial = summaryTable.MeanInitialBattery_percent(summaryTable.IsBaseline);
assistedMeanInitial = summaryTable.MeanInitialBattery_percent(~summaryTable.IsBaseline);
if isfinite(baselineMeanInitial) && isfinite(assistedMeanInitial)
    if abs(assistedMeanInitial - baselineMeanInitial) > 5.0
        warningMessages(end + 1, 1) = ...
            "Initial battery percentage differed between configurations and may affect endurance comparison."; %#ok<SAGROW>
    end
end

baselineMeanBatteryUsed = summaryTable.MeanBatteryUsed_percent(summaryTable.IsBaseline);
assistedMeanBatteryUsed = summaryTable.MeanBatteryUsed_percent(~summaryTable.IsBaseline);
if isfinite(baselineMeanBatteryUsed) && isfinite(assistedMeanBatteryUsed)
    if abs(assistedMeanBatteryUsed - baselineMeanBatteryUsed) > 5.0
        warningMessages(end + 1, 1) = ...
            "Battery usage differed between configurations. Hover duration should be interpreted alongside hover seconds per battery percent."; %#ok<SAGROW>
    end
end

baselineMeanFinal = summaryTable.MeanFinalBattery_percent(summaryTable.IsBaseline);
assistedMeanFinal = summaryTable.MeanFinalBattery_percent(~summaryTable.IsBaseline);
if isfinite(baselineMeanFinal) && isfinite(assistedMeanFinal)
    if abs(assistedMeanFinal - baselineMeanFinal) > 5.0
        warningMessages(end + 1, 1) = ...
            "Final battery percentage differed between configurations. Trials may not have ended at equivalent battery states."; %#ok<SAGROW>
    end
end

analysisTable = create_statistical_analysis_summary(baselineValidRows.HoverDuration_s, assistedValidRows.HoverDuration_s);
analysisPerformed = logical(analysisTable.WelchTTestPerformed(1));
if ~analysisPerformed
    warningMessages(end + 1, 1) = ...
        "Formal hypothesis testing was not performed because fewer than three valid trials were available in one or more comparison groups."; %#ok<SAGROW>
end

if ~isempty(voltageDropWarnings)
    warningMessages = unique([warningMessages; voltageDropWarnings], 'stable');
end

warningMessages = unique(warningMessages, 'stable');
analysisTable.NotesWarnings(1) = strjoin(warningMessages, " | ");

analysisCsvPath = fullfile(resultsDir, 'hover_endurance_analysis_summary.csv');
writetable(analysisTable, analysisCsvPath);

validityTable = create_validity_summary_table(trialTable, configurationLabels, warningMessages);
validityCsvPath = fullfile(resultsDir, 'hover_endurance_validity_summary.csv');
writetable(validityTable, validityCsvPath);

%% Create and save figures (PNG only)
figurePaths = plot_hover_endurance_results(trialTable, summaryTable, voltageDropTrialTable, figuresDir);

%% Write text report
reportPath = fullfile(resultsDir, 'hover_endurance_report_summary.txt');
write_hover_endurance_report_summary(reportPath, summaryTable, comparisonTable, ...
    voltageDropComparisonTable, analysisTable, warningMessages, uavModel, configurationLabels);

%% Print completion summary
fprintf('\n=== Hover Endurance Analysis Complete ===\n');
fprintf('Trial-level CSV: %s\n', trialCsvPath);
fprintf('Summary CSV: %s\n', summaryCsvPath);
fprintf('Comparison CSV: %s\n', comparisonCsvPath);
fprintf('Voltage-drop trial CSV: %s\n', voltageDropTrialCsvPath);
fprintf('Voltage-drop summary CSV: %s\n', voltageDropSummaryCsvPath);
fprintf('Voltage-drop comparison CSV: %s\n', voltageDropComparisonCsvPath);
fprintf('Validity CSV: %s\n', validityCsvPath);
fprintf('Analysis CSV: %s\n', analysisCsvPath);
fprintf('Report summary: %s\n', reportPath);
fprintf('Figures:\n');
for i = 1:numel(figurePaths)
    fprintf('  - %s\n', figurePaths{i});
end

if isempty(warningMessages)
    fprintf('\nWarnings: none\n');
else
    fprintf('\nWarnings:\n');
    for i = 1:numel(warningMessages)
        fprintf('  - %s\n', warningMessages(i));
    end
end

fprintf('\nPrimary result emphasis: measured endurance change relative to baseline and physical BR.\n');

%% Local helper functions
function [assemblyWeight_N, measuredBalloonLift_N, brPhysical] = ...
    calculate_trial_quantities(assemblyMass_g, measuredBalloonLift_g, gravity_m_s2, isBaseline)
%CALCULATE_TRIAL_QUANTITIES Compute derived force and physical BR metrics.
assemblyMass_kg = assemblyMass_g / 1000.0;
assemblyWeight_N = assemblyMass_kg * gravity_m_s2;

if isBaseline
    measuredBalloonLift_N = 0.0;
    brPhysical = 0.0;
else
    measuredBalloonLift_N = (measuredBalloonLift_g / 1000.0) * gravity_m_s2;
    if assemblyWeight_N > 0
        brPhysical = measuredBalloonLift_N / assemblyWeight_N;
    else
        brPhysical = NaN;
    end
end
end

function summaryTable = create_hover_endurance_summary_table(trialTable, configurationLabels, uavModel)
%CREATE_HOVER_ENDURANCE_SUMMARY_TABLE Build summary metrics using valid trials.
summaryRows = cell(numel(configurationLabels), 1);

for i = 1:numel(configurationLabels)
    configLabel = configurationLabels(i);
    allRows = trialTable(trialTable.ConfigurationLabel == configLabel, :);
    if isempty(allRows)
        validRows = allRows;
    else
        validRows = allRows(allRows.IsValid, :);
    end

    defaultIsBaseline = strcmpi(configLabel, "Baseline unassisted");
    isBaselineValue = defaultIsBaseline;
    if ~isempty(allRows)
        isBaselineValue = logical(allRows.IsBaseline(1));
    end

    configurationNotes = "";
    if ~isempty(allRows)
        configurationNotes = string(allRows.ConfigurationNotes(1));
    end

    durations = validRows.HoverDuration_s;
    [mean_s, std_s, se_s, cv_percent, min_s, max_s] = compute_duration_statistics(durations);

    summaryRows{i, 1} = struct( ...
        'ConfigurationLabel', string(configLabel), ...
        'UAVModel', string(uavModel), ...
        'IsBaseline', logical(isBaselineValue), ...
        'NumberOfTrials', height(allRows), ...
        'NumberOfValidTrials', height(validRows), ...
        'MeanHoverDuration_s', mean_s, ...
        'StdHoverDuration_s', std_s, ...
        'StandardErrorHoverDuration_s', se_s, ...
        'CoefficientOfVariationHover_percent', cv_percent, ...
        'MinHoverDuration_s', min_s, ...
        'MaxHoverDuration_s', max_s, ...
        'MeanHoverDuration_min', mean_s / 60.0, ...
        'StdHoverDuration_min', std_s / 60.0, ...
        'MeanAssemblyMass_g', mean_or_nan(validRows.AssemblyMass_g), ...
        'MeanAssemblyWeight_N', mean_or_nan(validRows.AssemblyWeight_N), ...
        'MeanMeasuredBalloonLift_g', mean_or_nan(validRows.MeasuredBalloonLift_g), ...
        'MeanMeasuredBalloonLift_N', mean_or_nan(validRows.MeasuredBalloonLift_N), ...
        'MeanPhysicalBR', mean_or_nan(validRows.BR_physical), ...
        'MeanInitialBattery_percent', mean_or_nan(validRows.InitialBattery_percent), ...
        'MeanFinalBattery_percent', mean_or_nan(validRows.FinalBattery_percent), ...
        'MeanBatteryUsed_percent', mean_or_nan(validRows.BatteryUsed_percent), ...
        'StdBatteryUsed_percent', std_or_nan(validRows.BatteryUsed_percent), ...
        'MeanHoverSecondsPerBatteryPercent', mean_or_nan(validRows.HoverSecondsPerBatteryPercent), ...
        'StdHoverSecondsPerBatteryPercent', std_or_nan(validRows.HoverSecondsPerBatteryPercent), ...
        'ConfigurationNotes', configurationNotes); %#ok<AGROW>
end

summaryTable = struct2table(vertcat(summaryRows{:}));
summaryTable = summaryTable(:, { ...
    'ConfigurationLabel', 'UAVModel', 'IsBaseline', ...
    'NumberOfTrials', 'NumberOfValidTrials', ...
    'MeanHoverDuration_s', 'StdHoverDuration_s', 'StandardErrorHoverDuration_s', ...
    'CoefficientOfVariationHover_percent', ...
    'MinHoverDuration_s', 'MaxHoverDuration_s', ...
    'MeanHoverDuration_min', 'StdHoverDuration_min', ...
    'MeanAssemblyMass_g', 'MeanAssemblyWeight_N', ...
    'MeanMeasuredBalloonLift_g', 'MeanMeasuredBalloonLift_N', ...
    'MeanPhysicalBR', 'MeanInitialBattery_percent', 'MeanFinalBattery_percent', ...
    'MeanBatteryUsed_percent', 'StdBatteryUsed_percent', ...
    'MeanHoverSecondsPerBatteryPercent', 'StdHoverSecondsPerBatteryPercent', ...
    'ConfigurationNotes'});
end

function comparisonTable = create_hover_endurance_comparison_table(summaryTable)
%CREATE_HOVER_ENDURANCE_COMPARISON_TABLE Build assisted-vs-baseline comparison.
baselineRow = summaryTable(summaryTable.IsBaseline, :);
assistedRow = summaryTable(~summaryTable.IsBaseline, :);

meanBaseline_s = baselineRow.MeanHoverDuration_s;
meanAssisted_s = assistedRow.MeanHoverDuration_s;

absoluteChange_s = meanAssisted_s - meanBaseline_s;
if isfinite(meanBaseline_s) && abs(meanBaseline_s) > eps
    percentChange = 100.0 * absoluteChange_s / meanBaseline_s;
else
    percentChange = NaN;
end

meanLift_g = assistedRow.MeanMeasuredBalloonLift_g;
meanBR = assistedRow.MeanPhysicalBR;
meanBaselineBatteryUsed_percent = baselineRow.MeanBatteryUsed_percent;
meanAssistedBatteryUsed_percent = assistedRow.MeanBatteryUsed_percent;
meanBaselineHoverSecondsPerBatteryPercent = baselineRow.MeanHoverSecondsPerBatteryPercent;
meanAssistedHoverSecondsPerBatteryPercent = assistedRow.MeanHoverSecondsPerBatteryPercent;

absoluteChangeSecondsPerBatteryPercent = ...
    meanAssistedHoverSecondsPerBatteryPercent - meanBaselineHoverSecondsPerBatteryPercent;
if isfinite(meanBaselineHoverSecondsPerBatteryPercent) && abs(meanBaselineHoverSecondsPerBatteryPercent) > eps
    percentageChangeSecondsPerBatteryPercent = ...
        100.0 * absoluteChangeSecondsPerBatteryPercent / meanBaselineHoverSecondsPerBatteryPercent;
else
    percentageChangeSecondsPerBatteryPercent = NaN;
end

if isfinite(meanLift_g) && abs(meanLift_g) > eps
    secondsPerGramLift = absoluteChange_s / meanLift_g;
else
    secondsPerGramLift = NaN;
end

if isfinite(meanBR) && abs(meanBR) > eps
    percentChangePerBR = percentChange / meanBR;
else
    percentChangePerBR = NaN;
end

comparisonTable = table( ...
    assistedRow.ConfigurationLabel, baselineRow.ConfigurationLabel, ...
    meanBaseline_s, meanAssisted_s, ...
    absoluteChange_s, percentChange, ...
    meanBaselineBatteryUsed_percent, meanAssistedBatteryUsed_percent, ...
    meanBaselineHoverSecondsPerBatteryPercent, meanAssistedHoverSecondsPerBatteryPercent, ...
    absoluteChangeSecondsPerBatteryPercent, percentageChangeSecondsPerBatteryPercent, ...
    meanLift_g, meanBR, ...
    secondsPerGramLift, percentChangePerBR, ...
    'VariableNames', { ...
    'AssistedConfigurationLabel', 'BaselineConfigurationLabel', ...
    'MeanBaselineHover_s', 'MeanAssistedHover_s', ...
    'AbsoluteEnduranceChange_s', 'PercentageEnduranceChange_percent', ...
    'MeanBaselineBatteryUsed_percent', 'MeanAssistedBatteryUsed_percent', ...
    'MeanBaselineHoverSecondsPerBatteryPercent', 'MeanAssistedHoverSecondsPerBatteryPercent', ...
    'AbsoluteChangeSecondsPerBatteryPercent', 'PercentageChangeSecondsPerBatteryPercent', ...
    'MeanMeasuredBalloonLift_g', 'MeanPhysicalBR', ...
    'SecondsPerGramLift', 'PercentEnduranceChangePerBR'});
end

function validityTable = create_validity_summary_table(trialTable, configurationLabels, warningMessages)
%CREATE_VALIDITY_SUMMARY_TABLE Build validity/stop-condition/warning CSV table.
rows = cell(0, 1);

totalTrials = height(trialTable);
validTrials = sum(trialTable.IsValid);
invalidTrials = totalTrials - validTrials;

rows{end + 1, 1} = build_validity_row("Totals", "All", "Total trials", totalTrials, ""); %#ok<SAGROW>
rows{end + 1, 1} = build_validity_row("Totals", "All", "Valid trials", validTrials, ""); %#ok<SAGROW>
rows{end + 1, 1} = build_validity_row("Totals", "All", "Invalid trials", invalidTrials, ""); %#ok<SAGROW>

for i = 1:numel(configurationLabels)
    configLabel = configurationLabels(i);
    cfgRows = trialTable(trialTable.ConfigurationLabel == configLabel, :);
    cfgValid = sum(cfgRows.IsValid);
    cfgInvalid = height(cfgRows) - cfgValid;

    rows{end + 1, 1} = build_validity_row("ConfigurationCounts", configLabel, "Total trials", height(cfgRows), ""); %#ok<SAGROW>
    rows{end + 1, 1} = build_validity_row("ConfigurationCounts", configLabel, "Valid trials", cfgValid, ""); %#ok<SAGROW>
    rows{end + 1, 1} = build_validity_row("ConfigurationCounts", configLabel, "Invalid trials", cfgInvalid, ""); %#ok<SAGROW>

    normalizedStops = normalize_stop_conditions(cfgRows.StopCondition);
    [uniqueStops, ~, groupIdx] = unique(normalizedStops);
    stopCounts = accumarray(groupIdx, 1);

    for stopIdx = 1:numel(uniqueStops)
        itemLabel = sprintf('Stop condition count: %s', uniqueStops(stopIdx));
        rows{end + 1, 1} = build_validity_row("StopConditionCounts", configLabel, itemLabel, stopCounts(stopIdx), ""); %#ok<SAGROW>
    end
end

if isempty(warningMessages)
    rows{end + 1, 1} = build_validity_row("Warnings", "All", "Warning", NaN, "None"); %#ok<SAGROW>
else
    for i = 1:numel(warningMessages)
        rows{end + 1, 1} = build_validity_row("Warnings", "All", "Warning", NaN, warningMessages(i)); %#ok<SAGROW>
    end
end

validityTable = struct2table(vertcat(rows{:}));
end

function row = build_validity_row(sectionLabel, configurationLabel, itemLabel, valueNumber, notesText)
%BUILD_VALIDITY_ROW Build one row for validity summary output.
row = struct( ...
    'Section', string(sectionLabel), ...
    'ConfigurationLabel', string(configurationLabel), ...
    'Item', string(itemLabel), ...
    'Value', valueNumber, ...
    'Notes', string(notesText));
end

function analysisTable = create_statistical_analysis_summary(baselineDurations_s, assistedDurations_s)
%CREATE_STATISTICAL_ANALYSIS_SUMMARY Compute Welch t-test when sample size allows.

nBaseline = numel(baselineDurations_s);
nAssisted = numel(assistedDurations_s);

performed = false;
reason = "";
tStatistic = NaN;
degreesFreedom = NaN;
pValue = NaN;
meanDifference_s = NaN;
ciLower_s = NaN;
ciUpper_s = NaN;

if nBaseline >= 3 && nAssisted >= 3
    performed = true;
    [~, pValue, ci, stats] = ttest2(assistedDurations_s, baselineDurations_s, 'Vartype', 'unequal');
    tStatistic = stats.tstat;
    degreesFreedom = stats.df;
    meanDifference_s = mean(assistedDurations_s, 'omitnan') - mean(baselineDurations_s, 'omitnan');
    ciLower_s = ci(1);
    ciUpper_s = ci(2);
else
    reason = "Formal hypothesis testing was not performed because fewer than three valid trials were available in one or more comparison groups.";
end

analysisTable = table( ...
    performed, reason, ...
    tStatistic, degreesFreedom, pValue, ...
    meanDifference_s, ciLower_s, ciUpper_s, ...
    "", ...
    'VariableNames', { ...
    'WelchTTestPerformed', ...
    'ReasonNotPerformed', ...
    'TStatistic', ...
    'DegreesOfFreedom', ...
    'PValue', ...
    'MeanDifference_s', ...
    'ConfidenceIntervalLower_s', ...
    'ConfidenceIntervalUpper_s', ...
    'NotesWarnings'});
end

function figurePaths = plot_hover_endurance_results(trialTable, summaryTable, voltageDropTrialTable, outputFolder)
%PLOT_HOVER_ENDURANCE_RESULTS Generate selected hover-endurance figures.
figurePaths = {};

baselineLabel = summaryTable.ConfigurationLabel(summaryTable.IsBaseline);
assistedLabel = summaryTable.ConfigurationLabel(~summaryTable.IsBaseline);

baselineMean_s = summaryTable.MeanHoverDuration_s(summaryTable.IsBaseline);
assistedMean_s = summaryTable.MeanHoverDuration_s(~summaryTable.IsBaseline);

%% Figure 1: Trial hover-duration scatter with invalid marker style
fig1 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 960 560]);
ax1 = axes(fig1);
hold(ax1, 'on');

baselineRows = trialTable(trialTable.IsBaseline, :);
assistedRows = trialTable(~trialTable.IsBaseline, :);

plot_trial_scatter_group(ax1, baselineRows, 1, [0.12 0.45 0.70]);
plot_trial_scatter_group(ax1, assistedRows, 2, [0.20 0.60 0.32]);

plot(ax1, 1, baselineMean_s, 'kd', 'MarkerFaceColor', [1 1 1], 'MarkerSize', 9, 'DisplayName', 'Valid-trial mean');
plot(ax1, 2, assistedMean_s, 'kd', 'MarkerFaceColor', [1 1 1], 'MarkerSize', 9, 'HandleVisibility', 'off');

set(ax1, 'XTick', 1:2, 'XTickLabel', cellstr([baselineLabel; assistedLabel]));
xlim(ax1, [0.5, 2.5]);
ylabel(ax1, 'Hover duration [s]');
xlabel(ax1, 'Configuration');
title(ax1, 'Trial Hover Duration by Configuration');
grid(ax1, 'on');
legend(ax1, 'Location', 'best');
ylim(ax1, nonnegative_axis_limits(trialTable.HoverDuration_s, 0.15));

path1 = fullfile(outputFolder, 'hover_duration_trial_scatter.png');
exportgraphics(fig1, path1, 'Resolution', 220);
figurePaths{end + 1, 1} = path1; %#ok<AGROW>
close(fig1);

%% Figure 2: Trial voltage-drop-rate scatter by configuration
fig2 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 960 560]);
ax2 = axes(fig2);

if isempty(voltageDropTrialTable)
    axis(ax2, 'off');
    text(ax2, 0.5, 0.5, 'No voltage-drop trial data available.', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 12);
else
    hold(ax2, 'on');

    baselineVoltageRows = voltageDropTrialTable(voltageDropTrialTable.ConfigurationLabel == "Baseline unassisted", :);
    assistedVoltageRows = voltageDropTrialTable(voltageDropTrialTable.ConfigurationLabel == "Assisted", :);

    if ~isempty(baselineVoltageRows)
        jitterBaseline = linspace(-0.08, 0.08, height(baselineVoltageRows));
        scatter(ax2, 1 + jitterBaseline(:), baselineVoltageRows.VoltageDropRate_V_per_s, 48, 'o', ...
            'MarkerFaceColor', [0.12 0.45 0.70], 'MarkerEdgeColor', [0.05 0.05 0.05], ...
            'DisplayName', 'Baseline trial rates');
        plot(ax2, 1, mean_or_nan(baselineVoltageRows.VoltageDropRate_V_per_s), 'kd', ...
            'MarkerFaceColor', [1 1 1], 'MarkerSize', 9, 'DisplayName', 'Group mean');
    end

    if ~isempty(assistedVoltageRows)
        jitterAssisted = linspace(-0.08, 0.08, height(assistedVoltageRows));
        scatter(ax2, 2 + jitterAssisted(:), assistedVoltageRows.VoltageDropRate_V_per_s, 48, 'o', ...
            'MarkerFaceColor', [0.20 0.60 0.32], 'MarkerEdgeColor', [0.05 0.05 0.05], ...
            'DisplayName', 'Assisted trial rates');
        plot(ax2, 2, mean_or_nan(assistedVoltageRows.VoltageDropRate_V_per_s), 'kd', ...
            'MarkerFaceColor', [1 1 1], 'MarkerSize', 9, 'HandleVisibility', 'off');
    end

    set(ax2, 'XTick', 1:2, 'XTickLabel', {'Baseline unassisted', 'Assisted'});
    xlim(ax2, [0.5, 2.5]);
    ylabel(ax2, 'Voltage drop rate [V/s]');
    xlabel(ax2, 'Configuration');
    title(ax2, 'Trial Voltage Drop Rate by Configuration');
    grid(ax2, 'on');
    legend(ax2, 'Location', 'best');

    yValues = voltageDropTrialTable.VoltageDropRate_V_per_s;
    finiteY = yValues(isfinite(yValues));
    if isempty(finiteY)
        ylim(ax2, [0 1]);
    else
        yMin = min(finiteY);
        yMax = max(finiteY);
        if abs(yMax - yMin) < eps
            yPad = max(0.1 * max(abs(yMax), 1e-3), 1e-4);
            ylim(ax2, [yMin - yPad, yMax + yPad]);
        else
            yPad = 0.15 * (yMax - yMin);
            ylim(ax2, [yMin - yPad, yMax + yPad]);
        end
    end
end

path2 = fullfile(outputFolder, 'voltage_drop_rate_trial_scatter.png');
exportgraphics(fig2, path2, 'Resolution', 220);
figurePaths{end + 1, 1} = path2; %#ok<AGROW>
close(fig2);
end

function [trialRateTable, summaryTable, comparisonTable, warningMessages] = analyze_voltage_drop_from_trial_csvs(trialResultsDir)
%ANALYZE_VOLTAGE_DROP_FROM_TRIAL_CSVS Compute voltage drop rates from trial CSV files.
warningMessages = strings(0, 1);

trialRows = cell(0, 1);
supportedLabels = ["Baseline unassisted"; "Assisted"];

if ~exist(trialResultsDir, 'dir')
    warningMessages(end + 1, 1) = ...
        "Voltage-drop analysis could not find crazyflie/trial_results directory."; %#ok<SAGROW>
    [trialRateTable, summaryTable, comparisonTable] = ...
        build_empty_voltage_drop_tables(trialResultsDir, supportedLabels);
    return;
end

csvFiles = dir(fullfile(trialResultsDir, '*_hover_trial.csv'));
if isempty(csvFiles)
    warningMessages(end + 1, 1) = ...
        "Voltage-drop analysis found no *_hover_trial.csv files."; %#ok<SAGROW>
    [trialRateTable, summaryTable, comparisonTable] = ...
        build_empty_voltage_drop_tables(trialResultsDir, supportedLabels);
    return;
end

for fileIndex = 1:numel(csvFiles)
    fileName = string(csvFiles(fileIndex).name);
    filePath = fullfile(csvFiles(fileIndex).folder, csvFiles(fileIndex).name);

    [isClassified, configurationLabel] = classify_voltage_drop_file(fileName);
    if ~isClassified
        continue;
    end

    try
        trialTable = readtable(filePath, 'VariableNamingRule', 'preserve');
    catch
        warningMessages(end + 1, 1) = ...
            "Voltage-drop analysis skipped an unreadable CSV: " + fileName; %#ok<SAGROW>
        continue;
    end

    if ~all(ismember({'time_s', 'vbat'}, trialTable.Properties.VariableNames))
        warningMessages(end + 1, 1) = ...
            "Voltage-drop analysis skipped a CSV missing time_s or vbat: " + fileName; %#ok<SAGROW>
        continue;
    end

    [time_s, vbat_V] = parse_time_voltage_columns(trialTable.time_s, trialTable.vbat);
    finiteMask = isfinite(time_s) & isfinite(vbat_V);
    time_s = time_s(finiteMask);
    vbat_V = vbat_V(finiteMask);

    if numel(time_s) < 2
        warningMessages(end + 1, 1) = ...
            "Voltage-drop analysis skipped CSV with fewer than two valid samples: " + fileName; %#ok<SAGROW>
        continue;
    end

    [time_s, sortIdx] = sort(time_s);
    vbat_V = vbat_V(sortIdx);

    duration_s = time_s(end) - time_s(1);
    if ~isfinite(duration_s) || duration_s <= 0
        warningMessages(end + 1, 1) = ...
            "Voltage-drop analysis skipped CSV with non-positive duration: " + fileName; %#ok<SAGROW>
        continue;
    end

    startVoltage_V = vbat_V(1);
    endVoltage_V = vbat_V(end);
    voltageDrop_V = startVoltage_V - endVoltage_V;
    voltageDropRate_V_per_s = voltageDrop_V / duration_s;

    trialRows{end + 1, 1} = struct( ...
        'ConfigurationLabel', configurationLabel, ...
        'FileName', fileName, ...
        'Duration_s', duration_s, ...
        'StartVoltage_V', startVoltage_V, ...
        'EndVoltage_V', endVoltage_V, ...
        'VoltageDrop_V', voltageDrop_V, ...
        'VoltageDropRate_V_per_s', voltageDropRate_V_per_s); %#ok<SAGROW>
end

if isempty(trialRows)
    warningMessages(end + 1, 1) = ...
        "Voltage-drop analysis did not find usable trial CSV files for assisted vs unassisted."; %#ok<SAGROW>
    [trialRateTable, summaryTable, comparisonTable] = ...
        build_empty_voltage_drop_tables(trialResultsDir, supportedLabels);
    return;
end

trialRateTable = struct2table(vertcat(trialRows{:}));
trialRateTable = trialRateTable(:, { ...
    'ConfigurationLabel', 'FileName', 'Duration_s', ...
    'StartVoltage_V', 'EndVoltage_V', 'VoltageDrop_V', 'VoltageDropRate_V_per_s'});

trialRateTable.IsOutlier = false(height(trialRateTable), 1);
trialRateTable.IncludedInComparison = true(height(trialRateTable), 1);

for i = 1:numel(supportedLabels)
    label = supportedLabels(i);
    labelMask = trialRateTable.ConfigurationLabel == label;
    labelRates = trialRateTable.VoltageDropRate_V_per_s(labelMask);
    outlierMaskLocal = detect_iqr_outliers(labelRates);

    labelIndices = find(labelMask);
    if ~isempty(labelIndices)
        outlierIndices = labelIndices(outlierMaskLocal);
        trialRateTable.IsOutlier(outlierIndices) = true;
        trialRateTable.IncludedInComparison(outlierIndices) = false;
    end
end

summaryRows = cell(numel(supportedLabels), 1);
for i = 1:numel(supportedLabels)
    label = supportedLabels(i);
    rows = trialRateTable(trialRateTable.ConfigurationLabel == label, :);
    includedRows = rows(rows.IncludedInComparison, :);

    summaryRows{i, 1} = struct( ...
        'ConfigurationLabel', label, ...
        'NumberOfCsvTrials', height(rows), ...
        'NumberOfOutliersRemoved', sum(rows.IsOutlier), ...
        'NumberIncludedInComparison', height(includedRows), ...
        'MeanVoltageDropRate_V_per_s', mean_or_nan(includedRows.VoltageDropRate_V_per_s), ...
        'StdVoltageDropRate_V_per_s', std_or_nan(includedRows.VoltageDropRate_V_per_s), ...
        'MeanStartVoltage_V', mean_or_nan(rows.StartVoltage_V), ...
        'MeanEndVoltage_V', mean_or_nan(rows.EndVoltage_V), ...
        'MeanTrialDuration_s', mean_or_nan(rows.Duration_s), ...
        'SourceDirectory', string(trialResultsDir)); %#ok<AGROW>
end

summaryTable = struct2table(vertcat(summaryRows{:}));
summaryTable = summaryTable(:, { ...
    'ConfigurationLabel', 'NumberOfCsvTrials', ...
    'NumberOfOutliersRemoved', 'NumberIncludedInComparison', ...
    'MeanVoltageDropRate_V_per_s', 'StdVoltageDropRate_V_per_s', ...
    'MeanStartVoltage_V', 'MeanEndVoltage_V', 'MeanTrialDuration_s', ...
    'SourceDirectory'});

baselineSummary = summaryTable(summaryTable.ConfigurationLabel == "Baseline unassisted", :);
assistedSummary = summaryTable(summaryTable.ConfigurationLabel == "Assisted", :);

baselineIncludedRates = trialRateTable.VoltageDropRate_V_per_s( ...
    trialRateTable.ConfigurationLabel == "Baseline unassisted" & trialRateTable.IncludedInComparison);
assistedIncludedRates = trialRateTable.VoltageDropRate_V_per_s( ...
    trialRateTable.ConfigurationLabel == "Assisted" & trialRateTable.IncludedInComparison);

meanBaselineRate = baselineSummary.MeanVoltageDropRate_V_per_s;
meanAssistedRate = assistedSummary.MeanVoltageDropRate_V_per_s;
absoluteRateChange = meanAssistedRate - meanBaselineRate;

if isfinite(meanBaselineRate) && abs(meanBaselineRate) > eps
    percentageRateChange = 100.0 * absoluteRateChange / meanBaselineRate;
else
    percentageRateChange = NaN;
end

[voltageDropTestPerformed, voltageDropTestReason, voltageDropTStatistic, ...
    voltageDropDegreesFreedom, voltageDropPValue, voltageDropCiLower, voltageDropCiUpper] = ...
    compute_welch_ttest_summary(assistedIncludedRates, baselineIncludedRates);

comparisonTable = table( ...
    baselineSummary.NumberOfCsvTrials, ...
    assistedSummary.NumberOfCsvTrials, ...
    baselineSummary.NumberOfOutliersRemoved, ...
    assistedSummary.NumberOfOutliersRemoved, ...
    baselineSummary.NumberIncludedInComparison, ...
    assistedSummary.NumberIncludedInComparison, ...
    meanBaselineRate, ...
    meanAssistedRate, ...
    absoluteRateChange, ...
    percentageRateChange, ...
    voltageDropTestPerformed, ...
    voltageDropTestReason, ...
    voltageDropTStatistic, ...
    voltageDropDegreesFreedom, ...
    voltageDropPValue, ...
    voltageDropCiLower, ...
    voltageDropCiUpper, ...
    string(trialResultsDir), ...
    'VariableNames', { ...
    'BaselineTrialCount', ...
    'AssistedTrialCount', ...
    'BaselineOutliersRemoved', ...
    'AssistedOutliersRemoved', ...
    'BaselineIncludedTrialCount', ...
    'AssistedIncludedTrialCount', ...
    'MeanBaselineVoltageDrop_V_per_s', ...
    'MeanAssistedVoltageDrop_V_per_s', ...
    'AbsoluteVoltageDropChange_V_per_s', ...
    'PercentageVoltageDropChange_percent', ...
    'WelchTTestPerformed', ...
    'ReasonNotPerformed', ...
    'TStatistic', ...
    'DegreesOfFreedom', ...
    'PValue', ...
    'ConfidenceIntervalLower_V_per_s', ...
    'ConfidenceIntervalUpper_V_per_s', ...
    'SourceDirectory'});

if baselineSummary.NumberOfCsvTrials < 1 || assistedSummary.NumberOfCsvTrials < 1
    warningMessages(end + 1, 1) = ...
        "Voltage-drop comparison is incomplete because baseline or assisted CSV trials are missing."; %#ok<SAGROW>
end

if baselineSummary.NumberOfOutliersRemoved > 0 || assistedSummary.NumberOfOutliersRemoved > 0
    warningMessages(end + 1, 1) = ...
        "Voltage-drop comparison removed IQR-based outliers before computing summary statistics and significance."; %#ok<SAGROW>
end

if ~voltageDropTestPerformed
    warningMessages(end + 1, 1) = ...
        "Voltage-drop significance testing was not performed because fewer than three non-outlier trials remained in one or more groups."; %#ok<SAGROW>
end

warningMessages = unique(warningMessages, 'stable');
end

function outlierMask = detect_iqr_outliers(values)
%DETECT_IQR_OUTLIERS Detect outliers using the 1.5*IQR rule.
values = values(:);
finiteMask = isfinite(values);
outlierMask = false(size(values));

finiteValues = values(finiteMask);
if numel(finiteValues) < 4
    return;
end

q1 = prctile(finiteValues, 25);
q3 = prctile(finiteValues, 75);
iqrValue = q3 - q1;

if ~isfinite(iqrValue) || iqrValue <= 0
    return;
end

lowerBound = q1 - 1.5 * iqrValue;
upperBound = q3 + 1.5 * iqrValue;
outlierMask(finiteMask) = finiteValues < lowerBound | finiteValues > upperBound;
end

function [performed, reason, tStatistic, degreesFreedom, pValue, ciLower, ciUpper] = ...
    compute_welch_ttest_summary(sampleA, sampleB)
%COMPUTE_WELCH_TTEST_SUMMARY Compute Welch t-test summary for two samples.
sampleA = sampleA(isfinite(sampleA));
sampleB = sampleB(isfinite(sampleB));

performed = false;
reason = "";
tStatistic = NaN;
degreesFreedom = NaN;
pValue = NaN;
ciLower = NaN;
ciUpper = NaN;

if numel(sampleA) < 3 || numel(sampleB) < 3
    reason = "Fewer than three non-outlier trials were available in one or more groups.";
    return;
end

performed = true;
[~, pValue, ci, stats] = ttest2(sampleA, sampleB, 'Vartype', 'unequal');
tStatistic = stats.tstat;
degreesFreedom = stats.df;
ciLower = ci(1);
ciUpper = ci(2);
end

function [isClassified, configurationLabel] = classify_voltage_drop_file(fileName)
%CLASSIFY_VOLTAGE_DROP_FILE Classify CSV as baseline-unassisted or assisted.
nameLower = lower(fileName);

if contains(nameLower, "baseline") || contains(nameLower, "unassisted")
    isClassified = true;
    configurationLabel = "Baseline unassisted";
    return;
end

if contains(nameLower, "balloon_assisted") || contains(nameLower, "assisted")
    isClassified = true;
    configurationLabel = "Assisted";
    return;
end

isClassified = false;
configurationLabel = "";
end

function [time_s, vbat_V] = parse_time_voltage_columns(timeColumnRaw, voltageColumnRaw)
%PARSE_TIME_VOLTAGE_COLUMNS Convert numeric/string table columns to doubles.
if isnumeric(timeColumnRaw)
    time_s = timeColumnRaw;
else
    time_s = str2double(string(timeColumnRaw));
end

if isnumeric(voltageColumnRaw)
    vbat_V = voltageColumnRaw;
else
    vbat_V = str2double(string(voltageColumnRaw));
end

time_s = time_s(:);
vbat_V = vbat_V(:);
end

function [trialRateTable, summaryTable, comparisonTable] = build_empty_voltage_drop_tables(trialResultsDir, supportedLabels)
%BUILD_EMPTY_VOLTAGE_DROP_TABLES Build empty-shaped tables for unavailable data.
trialRateTable = table( ...
    strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    'VariableNames', { ...
    'ConfigurationLabel', 'FileName', 'Duration_s', ...
    'StartVoltage_V', 'EndVoltage_V', 'VoltageDrop_V', 'VoltageDropRate_V_per_s'});

summaryTable = table( ...
    supportedLabels, zeros(numel(supportedLabels), 1), ...
    NaN(numel(supportedLabels), 1), NaN(numel(supportedLabels), 1), ...
    NaN(numel(supportedLabels), 1), NaN(numel(supportedLabels), 1), NaN(numel(supportedLabels), 1), ...
    repmat(string(trialResultsDir), numel(supportedLabels), 1), ...
    'VariableNames', { ...
    'ConfigurationLabel', 'NumberOfCsvTrials', ...
    'MeanVoltageDropRate_V_per_s', 'StdVoltageDropRate_V_per_s', ...
    'MeanStartVoltage_V', 'MeanEndVoltage_V', 'MeanTrialDuration_s', ...
    'SourceDirectory'});

comparisonTable = table( ...
    0, 0, NaN, NaN, NaN, NaN, string(trialResultsDir), ...
    'VariableNames', { ...
    'BaselineTrialCount', ...
    'AssistedTrialCount', ...
    'MeanBaselineVoltageDrop_V_per_s', ...
    'MeanAssistedVoltageDrop_V_per_s', ...
    'AbsoluteVoltageDropChange_V_per_s', ...
    'PercentageVoltageDropChange_percent', ...
    'SourceDirectory'});
end

function write_hover_endurance_report_summary(reportPath, summaryTable, comparisonTable, voltageDropComparisonTable, analysisTable, warningMessages, uavModel, configurationLabels)
%WRITE_HOVER_ENDURANCE_REPORT_SUMMARY Write text summary for thesis reporting.
baselineRow = summaryTable(summaryTable.IsBaseline, :);
assistedRow = summaryTable(~summaryTable.IsBaseline, :);
comparisonRow = comparisonTable(1, :);
voltageDropComparisonRow = voltageDropComparisonTable(1, :);
analysisRow = analysisTable(1, :);

lineBreak = sprintf('\n');
reportText = "";

reportText = reportText + "Hover Endurance Results Summary" + lineBreak;
reportText = reportText + "===============================" + lineBreak + lineBreak;
reportText = reportText + sprintf('UAV model: %s', uavModel) + lineBreak;
reportText = reportText + sprintf('Configurations: %s and %s', configurationLabels(1), configurationLabels(2)) + lineBreak + lineBreak;

reportText = reportText + "Configuration summary" + lineBreak;
reportText = reportText + sprintf('- %s: mean hover duration = %.2f s, std = %.2f s, valid trials = %d', ...
    baselineRow.ConfigurationLabel, baselineRow.MeanHoverDuration_s, baselineRow.StdHoverDuration_s, baselineRow.NumberOfValidTrials) + lineBreak;
reportText = reportText + sprintf('- %s: mean hover duration = %.2f s, std = %.2f s, valid trials = %d', ...
    assistedRow.ConfigurationLabel, assistedRow.MeanHoverDuration_s, assistedRow.StdHoverDuration_s, assistedRow.NumberOfValidTrials) + lineBreak + lineBreak;

reportText = reportText + "Assisted configuration" + lineBreak;
reportText = reportText + sprintf('- Mean measured balloon lift = %.2f g', assistedRow.MeanMeasuredBalloonLift_g) + lineBreak;
reportText = reportText + sprintf('- Mean physical BR = %.4f', assistedRow.MeanPhysicalBR) + lineBreak + lineBreak;

reportText = reportText + "Endurance comparison" + lineBreak;
reportText = reportText + sprintf('- Assisted hover duration changed by %.2f s relative to baseline.', comparisonRow.AbsoluteEnduranceChange_s) + lineBreak;
reportText = reportText + sprintf('- Percentage endurance change = %.2f%%', comparisonRow.PercentageEnduranceChange_percent) + lineBreak + lineBreak;

reportText = reportText + "Voltage drop comparison from trial CSV files" + lineBreak;
reportText = reportText + sprintf('- Baseline trials used: %d', voltageDropComparisonRow.BaselineTrialCount) + lineBreak;
reportText = reportText + sprintf('- Assisted trials used: %d', voltageDropComparisonRow.AssistedTrialCount) + lineBreak;
reportText = reportText + sprintf('- Baseline outliers removed: %d', voltageDropComparisonRow.BaselineOutliersRemoved) + lineBreak;
reportText = reportText + sprintf('- Assisted outliers removed: %d', voltageDropComparisonRow.AssistedOutliersRemoved) + lineBreak;
reportText = reportText + sprintf('- Baseline non-outlier trials compared: %d', voltageDropComparisonRow.BaselineIncludedTrialCount) + lineBreak;
reportText = reportText + sprintf('- Assisted non-outlier trials compared: %d', voltageDropComparisonRow.AssistedIncludedTrialCount) + lineBreak;
if isfinite(voltageDropComparisonRow.MeanBaselineVoltageDrop_V_per_s)
    reportText = reportText + sprintf('- Mean baseline voltage drop rate = %.6f V/s', voltageDropComparisonRow.MeanBaselineVoltageDrop_V_per_s) + lineBreak;
else
    reportText = reportText + "- Mean baseline voltage drop rate = unavailable" + lineBreak;
end

if isfinite(voltageDropComparisonRow.MeanAssistedVoltageDrop_V_per_s)
    reportText = reportText + sprintf('- Mean assisted voltage drop rate = %.6f V/s', voltageDropComparisonRow.MeanAssistedVoltageDrop_V_per_s) + lineBreak;
else
    reportText = reportText + "- Mean assisted voltage drop rate = unavailable" + lineBreak;
end

if isfinite(voltageDropComparisonRow.AbsoluteVoltageDropChange_V_per_s)
    reportText = reportText + sprintf('- Assisted-baseline voltage drop rate change = %.6f V/s', voltageDropComparisonRow.AbsoluteVoltageDropChange_V_per_s) + lineBreak;
else
    reportText = reportText + "- Assisted-baseline voltage drop rate change = unavailable" + lineBreak;
end

if isfinite(voltageDropComparisonRow.PercentageVoltageDropChange_percent)
    reportText = reportText + sprintf('- Percentage voltage drop rate change = %.2f%%', voltageDropComparisonRow.PercentageVoltageDropChange_percent) + lineBreak;
else
    reportText = reportText + "- Percentage voltage drop rate change = unavailable" + lineBreak;
end

if voltageDropComparisonRow.WelchTTestPerformed
    reportText = reportText + sprintf('- Voltage-drop Welch t-test: t(%.2f)=%.4f, p=%.4g', ...
        voltageDropComparisonRow.DegreesOfFreedom, voltageDropComparisonRow.TStatistic, voltageDropComparisonRow.PValue) + lineBreak;
    reportText = reportText + sprintf('- 95%% CI for assisted-baseline voltage drop rate difference: [%.6f, %.6f] V/s', ...
        voltageDropComparisonRow.ConfidenceIntervalLower_V_per_s, voltageDropComparisonRow.ConfidenceIntervalUpper_V_per_s) + lineBreak;
else
    reportText = reportText + sprintf('- Voltage-drop Welch t-test not performed: %s', voltageDropComparisonRow.ReasonNotPerformed) + lineBreak;
end
reportText = reportText + lineBreak;

reportText = reportText + "Statistical analysis" + lineBreak;
if analysisRow.WelchTTestPerformed
    reportText = reportText + "- Welch two-sample t-test was performed." + lineBreak;
    reportText = reportText + sprintf('- t(%.2f)=%.4f, p=%.4g', ...
        analysisRow.DegreesOfFreedom, analysisRow.TStatistic, analysisRow.PValue) + lineBreak;
    reportText = reportText + sprintf('- Mean difference (assisted-baseline) = %.2f s, 95%% CI [%.2f, %.2f] s', ...
        analysisRow.MeanDifference_s, analysisRow.ConfidenceIntervalLower_s, analysisRow.ConfidenceIntervalUpper_s) + lineBreak;
else
    reportText = reportText + "- Welch two-sample t-test was not performed." + lineBreak;
    reportText = reportText + sprintf('- Reason if not performed: %s', analysisRow.ReasonNotPerformed) + lineBreak;
end

reportText = reportText + lineBreak + "Warnings" + lineBreak;
if isempty(warningMessages)
    reportText = reportText + "- None." + lineBreak;
else
    for i = 1:numel(warningMessages)
        reportText = reportText + sprintf('- %s', warningMessages(i)) + lineBreak;
    end
end

reportText = reportText + lineBreak + "Results sentence" + lineBreak;
reportText = reportText + sprintf(['- Relative to baseline, the assisted Crazyflie 2.1+ configuration showed an average hover ' ...
    'endurance change of %.2f s (%.2f%%) at a mean physical buoyancy ratio of %.4f.'], ...
    comparisonRow.AbsoluteEnduranceChange_s, comparisonRow.PercentageEnduranceChange_percent, assistedRow.MeanPhysicalBR) + lineBreak;

fid = fopen(reportPath, 'w');
if fid < 0
    error('HoverEndurance:ReportWriteFailed', 'Could not open report file for writing: %s', reportPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', reportText);
end

function stopConditions = normalize_stop_condition_set(stopConditionSeries)
%NORMALIZE_STOP_CONDITION_SET Normalize and sort unique stop condition labels.
stopConditions = unique(normalize_stop_conditions(stopConditionSeries));
stopConditions = sort(stopConditions);
end

function normalized = normalize_stop_conditions(stopConditionSeries)
%NORMALIZE_STOP_CONDITIONS Lowercase/trim stop-condition strings.
normalized = lower(strtrim(string(stopConditionSeries)));
normalized(normalized == "") = "unspecified";
end

function tf = has_non_battery_related_valid_stop(stopConditionSeries)
%HAS_NON_BATTERY_RELATED_VALID_STOP Detect cautionary non-battery stop outcomes.
normalized = normalize_stop_conditions(stopConditionSeries);
keywords = ["collision", "setup failure", "attachment issue", "loss of controlled hover"];

tf = false;
for i = 1:numel(keywords)
    if any(contains(normalized, keywords(i)))
        tf = true;
        return;
    end
end
end

function [mean_s, std_s, se_s, cv_percent, min_s, max_s] = compute_duration_statistics(durationValues_s)
%COMPUTE_DURATION_STATISTICS Compute summary stats from valid hover durations.
if isempty(durationValues_s)
    mean_s = NaN;
    std_s = NaN;
    se_s = NaN;
    cv_percent = NaN;
    min_s = NaN;
    max_s = NaN;
    return;
end

mean_s = mean(durationValues_s, 'omitnan');
std_s = std(durationValues_s, 'omitnan');
min_s = min(durationValues_s);
max_s = max(durationValues_s);

if numel(durationValues_s) >= 1
    se_s = std_s / sqrt(numel(durationValues_s));
else
    se_s = NaN;
end

if isfinite(mean_s) && abs(mean_s) > eps
    cv_percent = 100.0 * std_s / mean_s;
else
    cv_percent = NaN;
end
end

function value = mean_or_nan(x)
%MEAN_OR_NAN Return mean with omitnan, or NaN if no finite values exist.
if isempty(x) || all(~isfinite(x))
    value = NaN;
else
    value = mean(x, 'omitnan');
end
end

function value = std_or_nan(x)
%STD_OR_NAN Return std with omitnan, or NaN if no finite values exist.
if isempty(x) || all(~isfinite(x))
    value = NaN;
else
    value = std(x, 'omitnan');
end
end

function ensure_output_directory(folderPath)
%ENSURE_OUTPUT_DIRECTORY Create folder if it does not already exist.
if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end
end

function clear_output_directory(folderPath)
%CLEAR_OUTPUT_DIRECTORY Remove existing generated files before a new run.
if exist(folderPath, 'dir')
    rmdir(folderPath, 's');
end
mkdir(folderPath);
end

function limits = nonnegative_axis_limits(values, paddingFraction)
%NONNEGATIVE_AXIS_LIMITS Compute [0, upper] limits with breathing room.
finiteValues = values(isfinite(values));
if isempty(finiteValues)
    limits = [0 1];
    return;
end

upperValue = max(finiteValues);
if upperValue <= 0
    limits = [0 1];
    return;
end

upperBound = upperValue * (1 + paddingFraction);
if upperBound <= upperValue
    upperBound = upperValue + 1;
end
limits = [0 upperBound];
end

function plot_trial_scatter_group(ax, groupRows, xCenter, colorValue)
%PLOT_TRIAL_SCATTER_GROUP Plot valid/invalid trials for one configuration.
if isempty(groupRows)
    return;
end

jitter = linspace(-0.08, 0.08, height(groupRows));
xValues = xCenter + jitter(:);

validMask = groupRows.IsValid;
invalidMask = ~groupRows.IsValid;

if any(validMask)
    scatter(ax, xValues(validMask), groupRows.HoverDuration_s(validMask), 48, 'o', ...
        'MarkerFaceColor', colorValue, 'MarkerEdgeColor', [0.05 0.05 0.05], ...
        'DisplayName', sprintf('%s valid trials', groupRows.ConfigurationLabel(find(validMask, 1, 'first'))));
end
if any(invalidMask)
    scatter(ax, xValues(invalidMask), groupRows.HoverDuration_s(invalidMask), 58, 'x', ...
        'MarkerEdgeColor', [0.75 0.15 0.15], 'LineWidth', 1.2, ...
        'DisplayName', sprintf('%s invalid trials', groupRows.ConfigurationLabel(find(invalidMask, 1, 'first'))));
end
end

function trialRows = collect_trial_rows_from_flight_csvs(trialResultsDir, uavModel, gravity_m_s2)
%COLLECT_TRIAL_ROWS_FROM_FLIGHT_CSVS Build trial rows from hover trial CSV/TXT outputs.
trialRows = cell(0, 1);

if ~exist(trialResultsDir, 'dir')
    return;
end

csvFiles = dir(fullfile(trialResultsDir, '*_hover_trial.csv'));
if isempty(csvFiles)
    return;
end

trialCountByLabel = containers.Map({'Baseline unassisted', 'Assisted'}, {0, 0});

for fileIndex = 1:numel(csvFiles)
    fileName = string(csvFiles(fileIndex).name);
    filePath = fullfile(csvFiles(fileIndex).folder, csvFiles(fileIndex).name);

    [isClassified, configurationLabel] = classify_voltage_drop_file(fileName);
    if ~isClassified
        continue;
    end

    isBaseline = configurationLabel == "Baseline unassisted";

    try
        csvTable = readtable(filePath, 'VariableNamingRule', 'preserve');
    catch
        continue;
    end

    if ~all(ismember({'time_s', 'vbat'}, csvTable.Properties.VariableNames))
        continue;
    end

    [time_s, vbat_V] = parse_time_voltage_columns(csvTable.time_s, csvTable.vbat);
    validMask = isfinite(time_s) & isfinite(vbat_V);
    time_s = time_s(validMask);

    if numel(time_s) < 2
        continue;
    end

    time_s = sort(time_s);
    hoverDuration_s = time_s(end) - time_s(1);
    if ~isfinite(hoverDuration_s) || hoverDuration_s <= 0
        continue;
    end

    summaryPath = strrep(filePath, '_hover_trial.csv', '_summary.txt');
    [stopCondition, summaryNotes] = parse_trial_summary_file(summaryPath);
    if strlength(stopCondition) == 0
        stopCondition = "from_flight_script";
    end

    isValid = true;

    trialCountByLabel(char(configurationLabel)) = trialCountByLabel(char(configurationLabel)) + 1;
    trialNumber = trialCountByLabel(char(configurationLabel));

    assemblyMass_g = NaN;
    measuredBalloonLift_g = 0.0;
    if ~isBaseline
        measuredBalloonLift_g = NaN;
    end

    [assemblyWeight_N, measuredBalloonLift_N, brPhysical] = ...
        calculate_trial_quantities(assemblyMass_g, measuredBalloonLift_g, gravity_m_s2, isBaseline);

    configNotes = "Collected automatically from flight-script trial outputs.";
    if strlength(summaryNotes) > 0
        configNotes = configNotes + " " + summaryNotes;
    end

    trialRows{end + 1, 1} = struct( ...
        'ConfigurationLabel', string(configurationLabel), ...
        'UAVModel', string(uavModel), ...
        'IsBaseline', logical(isBaseline), ...
        'TrialNumber', trialNumber, ...
        'BatteryID', "", ...
        'InitialBattery_percent', NaN, ...
        'FinalBattery_percent', NaN, ...
        'AssemblyMass_g', assemblyMass_g, ...
        'AssemblyWeight_N', assemblyWeight_N, ...
        'MeasuredBalloonLift_g', measuredBalloonLift_g, ...
        'MeasuredBalloonLift_N', measuredBalloonLift_N, ...
        'BR_physical', brPhysical, ...
        'HoverDuration_s', hoverDuration_s, ...
        'HoverDuration_min', hoverDuration_s / 60.0, ...
        'BatteryUsed_percent', NaN, ...
        'HoverSecondsPerBatteryPercent', NaN, ...
        'StopCondition', string(stopCondition), ...
        'IsValid', logical(isValid), ...
        'ConfigurationNotes', string(configNotes), ...
        'TrialNotes', "Source CSV: " + fileName); %#ok<SAGROW>
end
end

function [stopCondition, notesText] = parse_trial_summary_file(summaryPath)
%PARSE_TRIAL_SUMMARY_FILE Parse key values from per-trial summary TXT file.
stopCondition = "";
notesText = "";

if ~isfile(summaryPath)
    return;
end

try
    rawText = fileread(summaryPath);
catch
    return;
end

lines = splitlines(string(rawText));
lines = strtrim(lines);
lines(lines == "") = [];

noteParts = strings(0, 1);
for i = 1:numel(lines)
    line = lines(i);

    if startsWith(lower(line), "end reason:")
        stopCondition = strtrim(extractAfter(line, ":"));
    end

    if startsWith(lower(line), "trial label:") || ...
            startsWith(lower(line), "hover height target:") || ...
            startsWith(lower(line), "flight duration:")
        noteParts(end + 1, 1) = line; %#ok<SAGROW>
    end
end

if ~isempty(noteParts)
    notesText = strjoin(noteParts, " | ");
end
end

