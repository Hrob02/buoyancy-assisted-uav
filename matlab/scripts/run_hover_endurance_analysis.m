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
isBaselineConfiguration = [true; false];

baselineNotesPrompt = ['Configuration notes (optional). Examples: hover height, room temperature, ' ...
    'room conditions, battery notes, control mode, stop condition definition, test date, or anything unusual: '];
assistedNotesPrompt = ['Configuration notes (optional). Examples: hover height, room temperature, ' ...
    'room conditions, battery notes, control mode, attachment method, balloon tether length, ' ...
    'stop condition definition, test date, or anything unusual: '];

fprintf('=== Hover Endurance Analysis ===\n');
fprintf('UAV model: %s\n', uavModel);
fprintf('Configurations are fixed: Baseline unassisted and Assisted.\n');
fprintf('Gravity constant: g = %.2f m/s^2\n\n', gravity_m_s2);

%% Collect interactive experiment data
trialRows = cell(0, 1);

for configIndex = 1:numel(configurationLabels)
    configLabel = configurationLabels(configIndex);
    isBaseline = isBaselineConfiguration(configIndex);

    fprintf('--- %s ---\n', configLabel);

    if isBaseline
        measuredBalloonLift_g = 0.0;
    else
        measuredBalloonLift_g = prompt_nonnegative_number('Measured balloon lift [g]: ');
    end

    assemblyMass_g = prompt_positive_number('Assembly mass [g]: ');
    numberOfTrials = prompt_positive_integer('Number of trials: ');

    if isBaseline
        configurationNotes = prompt_text_value(baselineNotesPrompt);
    else
        configurationNotes = prompt_text_value(assistedNotesPrompt);
    end

    stopConditionPrompt = build_stop_condition_prompt(isBaseline);

    for trialNumber = 1:numberOfTrials
        while true
            fprintf('\n%s - Trial %d of %d\n', configLabel, trialNumber, numberOfTrials);

            batteryID = prompt_text_value('Battery ID (optional): ');
            initialBattery_percent = prompt_optional_battery_percentage('Initial battery percentage (optional, Enter to skip): ');
            finalBattery_percent = prompt_optional_battery_percentage('Final battery percentage (optional, Enter to skip): ');
            hoverDuration_s = prompt_positive_number('Hover duration [s]: ');

            stopCondition = prompt_text_value(stopConditionPrompt);
            if strlength(stopCondition) == 0
                stopCondition = "unspecified";
            end

            isValid = prompt_yes_no('Was this trial valid for the main endurance comparison? yes/no [y/n]: ');

            if ~isValid
                redoNow = prompt_yes_no('Do you want to redo this trial now? yes/no [y/n]: ');
                if redoNow
                    fprintf('Re-entering trial %d for %s.\n', trialNumber, configLabel);
                    continue;
                end
            end

            trialNotes = prompt_text_value('Trial notes (optional): ');

            [assemblyWeight_N, measuredBalloonLift_N, brPhysical] = ...
                calculate_trial_quantities(assemblyMass_g, measuredBalloonLift_g, gravity_m_s2, isBaseline);
            [batteryUsed_percent, hoverSecondsPerBatteryPercent] = ...
                calculate_battery_normalized_metrics(initialBattery_percent, finalBattery_percent, hoverDuration_s);

            trialRows{end + 1, 1} = struct( ...
                'ConfigurationLabel', string(configLabel), ...
                'UAVModel', string(uavModel), ...
                'IsBaseline', logical(isBaseline), ...
                'TrialNumber', trialNumber, ...
                'BatteryID', string(batteryID), ...
                'InitialBattery_percent', initialBattery_percent, ...
                'FinalBattery_percent', finalBattery_percent, ...
                'AssemblyMass_g', assemblyMass_g, ...
                'AssemblyWeight_N', assemblyWeight_N, ...
                'MeasuredBalloonLift_g', measuredBalloonLift_g, ...
                'MeasuredBalloonLift_N', measuredBalloonLift_N, ...
                'BR_physical', brPhysical, ...
                'HoverDuration_s', hoverDuration_s, ...
                'HoverDuration_min', hoverDuration_s / 60.0, ...
                'BatteryUsed_percent', batteryUsed_percent, ...
                'HoverSecondsPerBatteryPercent', hoverSecondsPerBatteryPercent, ...
                'StopCondition', string(stopCondition), ...
                'IsValid', logical(isValid), ...
                'ConfigurationNotes', string(configurationNotes), ...
                'TrialNotes', string(trialNotes)); %#ok<SAGROW>

            break;
        end
    end

    fprintf('\nCompleted data entry for %s.\n\n', configLabel);
end

if isempty(trialRows)
    error('HoverEndurance:NoData', 'No trial data was entered.');
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

warningMessages = unique(warningMessages, 'stable');
analysisTable.NotesWarnings(1) = strjoin(warningMessages, " | ");

analysisCsvPath = fullfile(resultsDir, 'hover_endurance_analysis_summary.csv');
writetable(analysisTable, analysisCsvPath);

validityTable = create_validity_summary_table(trialTable, configurationLabels, warningMessages);
validityCsvPath = fullfile(resultsDir, 'hover_endurance_validity_summary.csv');
writetable(validityTable, validityCsvPath);

%% Create and save figures (PNG only)
figurePaths = plot_hover_endurance_results(trialTable, summaryTable, comparisonTable, figuresDir);

%% Write text report
reportPath = fullfile(resultsDir, 'hover_endurance_report_summary.txt');
write_hover_endurance_report_summary(reportPath, summaryTable, comparisonTable, analysisTable, warningMessages, uavModel, configurationLabels);

%% Print completion summary
fprintf('\n=== Hover Endurance Analysis Complete ===\n');
fprintf('Trial-level CSV: %s\n', trialCsvPath);
fprintf('Summary CSV: %s\n', summaryCsvPath);
fprintf('Comparison CSV: %s\n', comparisonCsvPath);
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
function value = prompt_positive_number(promptText)
%PROMPT_POSITIVE_NUMBER Prompt until a positive finite scalar is entered.
while true
    raw = input(promptText, 's');
    value = str2double(strtrim(raw));
    if isfinite(value) && isscalar(value) && value > 0
        return;
    end
    fprintf('Invalid input. Enter a positive numeric value.\n');
end
end

function value = prompt_nonnegative_number(promptText)
%PROMPT_NONNEGATIVE_NUMBER Prompt until a nonnegative finite scalar is entered.
while true
    raw = input(promptText, 's');
    value = str2double(strtrim(raw));
    if isfinite(value) && isscalar(value) && value >= 0
        return;
    end
    fprintf('Invalid input. Enter a nonnegative numeric value.\n');
end
end

function value = prompt_positive_integer(promptText)
%PROMPT_POSITIVE_INTEGER Prompt until a positive integer is entered.
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

function value = prompt_optional_number(promptText)
%PROMPT_OPTIONAL_NUMBER Prompt for a numeric value; blank returns NaN.
while true
    raw = strtrim(input(promptText, 's'));
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

function value = prompt_optional_battery_percentage(promptText)
%PROMPT_OPTIONAL_BATTERY_PERCENTAGE Prompt optional battery percent in [0, 100].
while true
    value = prompt_optional_number(promptText);
    if isnan(value)
        return;
    end
    if value >= 0 && value <= 100
        return;
    end
    fprintf('Invalid input. Enter a value between 0 and 100, or press Enter to skip.\n');
end
end

function textValue = prompt_text_value(promptText)
%PROMPT_TEXT_VALUE Read free text from user; blank input is allowed.
raw = input(promptText, 's');
textValue = string(strtrim(raw));
end

function answer = prompt_yes_no(promptText)
%PROMPT_YES_NO Prompt for yes/no responses.
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
    fprintf('Invalid input. Please enter yes/no or y/n.\n');
end
end

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

function [batteryUsed_percent, hoverSecondsPerBatteryPercent] = ...
    calculate_battery_normalized_metrics(initialBattery_percent, finalBattery_percent, hoverDuration_s)
%CALCULATE_BATTERY_NORMALIZED_METRICS Compute battery-use support metrics.
if ~isfinite(initialBattery_percent) || ~isfinite(finalBattery_percent)
    batteryUsed_percent = NaN;
    hoverSecondsPerBatteryPercent = NaN;
    return;
end

batteryUsed_percent = initialBattery_percent - finalBattery_percent;
if batteryUsed_percent > 0
    hoverSecondsPerBatteryPercent = hoverDuration_s / batteryUsed_percent;
else
    hoverSecondsPerBatteryPercent = NaN;
end
end

function summaryTable = create_hover_endurance_summary_table(trialTable, configurationLabels, uavModel)
%CREATE_HOVER_ENDURANCE_SUMMARY_TABLE Build summary metrics using valid trials.
summaryRows = cell(numel(configurationLabels), 1);

for i = 1:numel(configurationLabels)
    configLabel = configurationLabels(i);
    allRows = trialTable(trialTable.ConfigurationLabel == configLabel, :);
    validRows = allRows(allRows.IsValid, :);

    durations = validRows.HoverDuration_s;
    [mean_s, std_s, se_s, cv_percent, min_s, max_s] = compute_duration_statistics(durations);

    summaryRows{i, 1} = struct( ...
        'ConfigurationLabel', string(configLabel), ...
        'UAVModel', string(uavModel), ...
        'IsBaseline', logical(allRows.IsBaseline(1)), ...
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
        'ConfigurationNotes', string(allRows.ConfigurationNotes(1))); %#ok<AGROW>
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

function figurePaths = plot_hover_endurance_results(trialTable, summaryTable, comparisonTable, outputFolder)
%PLOT_HOVER_ENDURANCE_RESULTS Generate required hover endurance figures.
figurePaths = {};

baselineLabel = summaryTable.ConfigurationLabel(summaryTable.IsBaseline);
assistedLabel = summaryTable.ConfigurationLabel(~summaryTable.IsBaseline);

baselineMean_s = summaryTable.MeanHoverDuration_s(summaryTable.IsBaseline);
assistedMean_s = summaryTable.MeanHoverDuration_s(~summaryTable.IsBaseline);
baselineStd_s = summaryTable.StdHoverDuration_s(summaryTable.IsBaseline);
assistedStd_s = summaryTable.StdHoverDuration_s(~summaryTable.IsBaseline);

%% Figure 1: Mean hover duration by configuration with standard deviation
fig1 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 900 560]);
ax1 = axes(fig1);
barValues = [baselineMean_s, assistedMean_s];
errorValues = [baselineStd_s, assistedStd_s];

bar(ax1, 1:2, barValues, 0.55, 'FaceColor', [0.17 0.47 0.70], 'EdgeColor', [0.05 0.05 0.05]);
hold(ax1, 'on');
errorbar(ax1, 1:2, barValues, errorValues, 'k.', 'LineWidth', 1.3, 'CapSize', 12);
hold(ax1, 'off');

set(ax1, 'XTick', 1:2, 'XTickLabel', cellstr([baselineLabel; assistedLabel]));
ylabel(ax1, 'Hover duration [s]');
xlabel(ax1, 'Configuration');
title(ax1, 'Mean Valid Hover Duration by Configuration');
grid(ax1, 'on');
ylim(ax1, nonnegative_axis_limits(barValues + errorValues, 0.15));

path1 = fullfile(outputFolder, 'hover_duration_summary_bar.png');
exportgraphics(fig1, path1, 'Resolution', 220);
figurePaths{end + 1, 1} = path1; %#ok<AGROW>
close(fig1);

%% Figure 2: Trial hover-duration scatter with invalid marker style
fig2 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 960 560]);
ax2 = axes(fig2);
hold(ax2, 'on');

baselineRows = trialTable(trialTable.IsBaseline, :);
assistedRows = trialTable(~trialTable.IsBaseline, :);

plot_trial_scatter_group(ax2, baselineRows, 1, [0.12 0.45 0.70]);
plot_trial_scatter_group(ax2, assistedRows, 2, [0.20 0.60 0.32]);

plot(ax2, 1, baselineMean_s, 'kd', 'MarkerFaceColor', [1 1 1], 'MarkerSize', 9, 'DisplayName', 'Valid-trial mean');
plot(ax2, 2, assistedMean_s, 'kd', 'MarkerFaceColor', [1 1 1], 'MarkerSize', 9, 'HandleVisibility', 'off');

set(ax2, 'XTick', 1:2, 'XTickLabel', cellstr([baselineLabel; assistedLabel]));
xlim(ax2, [0.5, 2.5]);
ylabel(ax2, 'Hover duration [s]');
xlabel(ax2, 'Configuration');
title(ax2, 'Trial Hover Duration by Configuration');
grid(ax2, 'on');
legend(ax2, 'Location', 'best');
ylim(ax2, nonnegative_axis_limits(trialTable.HoverDuration_s, 0.15));

path2 = fullfile(outputFolder, 'hover_duration_trial_scatter.png');
exportgraphics(fig2, path2, 'Resolution', 220);
figurePaths{end + 1, 1} = path2; %#ok<AGROW>
close(fig2);

%% Figure 3: Direct endurance comparison relative to baseline
fig3 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 900 560]);
ax3 = axes(fig3);
comparisonValues = [baselineMean_s, assistedMean_s];
plot(ax3, [1 2], comparisonValues, '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.4, ...
    'HandleVisibility', 'off');
hold(ax3, 'on');
scatter(ax3, 1, baselineMean_s, 86, 'o', 'MarkerFaceColor', [0.12 0.45 0.70], ...
    'MarkerEdgeColor', [0.05 0.05 0.05], 'DisplayName', char(baselineLabel));
scatter(ax3, 2, assistedMean_s, 86, 'o', 'MarkerFaceColor', [0.20 0.60 0.32], ...
    'MarkerEdgeColor', [0.05 0.05 0.05], 'DisplayName', char(assistedLabel));
yline(ax3, baselineMean_s, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0, 'HandleVisibility', 'off');
hold(ax3, 'off');
set(ax3, 'XTick', 1:2, 'XTickLabel', cellstr([baselineLabel; assistedLabel]));
ylabel(ax3, 'Hover duration [s]');
xlabel(ax3, 'Configuration');
title(ax3, 'Endurance Change Relative to Baseline');
grid(ax3, 'on');

deltaText = sprintf('%.2f s (%.2f%%)', comparisonTable.AbsoluteEnduranceChange_s(1), ...
    comparisonTable.PercentageEnduranceChange_percent(1));
text(ax3, 1.5, max(comparisonValues) + 0.05 * max(comparisonValues + eps), ...
    sprintf('Assisted - baseline = %s', deltaText), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'BackgroundColor', [1 1 1], 'Margin', 5);
ylim(ax3, nonnegative_axis_limits(comparisonValues, 0.20));

path3 = fullfile(outputFolder, 'hover_endurance_change_percent.png');
exportgraphics(fig3, path3, 'Resolution', 220);
figurePaths{end + 1, 1} = path3; %#ok<AGROW>
close(fig3);

%% Figure 4: Physical BR vs mean hover duration
fig4 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 900 560]);
ax4 = axes(fig4);

xBR = [summaryTable.MeanPhysicalBR(summaryTable.IsBaseline), summaryTable.MeanPhysicalBR(~summaryTable.IsBaseline)];
yMean = [baselineMean_s, assistedMean_s];

plot(ax4, xBR, yMean, '-o', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.6, ...
    'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerSize', 7);
grid(ax4, 'on');
xlabel(ax4, 'Physical buoyancy ratio [-]');
ylabel(ax4, 'Mean hover duration [s]');
title(ax4, 'Physical BR vs Mean Hover Duration');

text(ax4, xBR(1), yMean(1), sprintf('  %s', baselineLabel), 'VerticalAlignment', 'bottom');
text(ax4, xBR(2), yMean(2), sprintf('  %s', assistedLabel), 'VerticalAlignment', 'bottom');
 xlim(ax4, nonnegative_axis_limits(xBR, 0.25));
ylim(ax4, nonnegative_axis_limits(yMean, 0.15));

path4 = fullfile(outputFolder, 'hover_duration_vs_physical_BR.png');
exportgraphics(fig4, path4, 'Resolution', 220);
figurePaths{end + 1, 1} = path4; %#ok<AGROW>
close(fig4);

%% Figure 5: Battery percentage summary (only when data is available)
hasInitialData = any(isfinite(summaryTable.MeanInitialBattery_percent));
hasFinalData = any(isfinite(summaryTable.MeanFinalBattery_percent));

if hasInitialData || hasFinalData
    fig5 = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 940 560]);
    ax5 = axes(fig5);

    groupedData = [summaryTable.MeanInitialBattery_percent, summaryTable.MeanFinalBattery_percent];
    bar(ax5, groupedData, 'grouped');
    set(ax5, 'XTickLabel', cellstr(summaryTable.ConfigurationLabel));
    xlabel(ax5, 'Configuration');
    ylabel(ax5, 'Battery percentage [%]');
    title(ax5, 'Battery Percentage Summary (Valid Trials)');
    legend(ax5, {'Mean initial battery', 'Mean final battery'}, 'Location', 'best');
    grid(ax5, 'on');
    ylim(ax5, [0 100]);

    path5 = fullfile(outputFolder, 'hover_endurance_battery_percentage_summary.png');
    exportgraphics(fig5, path5, 'Resolution', 220);
    figurePaths{end + 1, 1} = path5; %#ok<AGROW>
    close(fig5);
end
end

function write_hover_endurance_report_summary(reportPath, summaryTable, comparisonTable, analysisTable, warningMessages, uavModel, configurationLabels)
%WRITE_HOVER_ENDURANCE_REPORT_SUMMARY Write text summary for thesis reporting.
baselineRow = summaryTable(summaryTable.IsBaseline, :);
assistedRow = summaryTable(~summaryTable.IsBaseline, :);
comparisonRow = comparisonTable(1, :);
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

function stopPrompt = build_stop_condition_prompt(isBaseline)
%BUILD_STOP_CONDITION_PROMPT Build stop-condition prompt text with examples.
if isBaseline
    examples = ["battery cutoff", "low battery landing", "manual stop", ...
        "loss of controlled hover", "collision", "planned termination", "setup failure"];
else
    examples = ["battery cutoff", "low battery landing", "manual stop", ...
        "loss of controlled hover", "collision", "attachment issue", ...
        "planned termination", "setup failure"];
end

stopPrompt = sprintf('Stop condition (e.g., %s): ', strjoin(examples, ', '));
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
