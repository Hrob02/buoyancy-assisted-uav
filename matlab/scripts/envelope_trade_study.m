function envelope_trade_study
% ENVELOPE_TRADE_STUDY
% Comparative helium-assisted UAV envelope study.
% This tool compares:
% 1. Required helium volume vs system mass
% 2. Estimated flight time vs mass and buoyancy ratio
% 3. 3D directional disturbance response
% 4. Overall design score + simple statistics
%
% This is a comparative design screening tool, not CFD.


clc;
close all;

fprintf('=== Buoyancy-Assisted UAV Envelope Trade Study ===\n');

% ------------------------------------------------------------------------
% CLEAN RESULTS DIRECTORY BEFORE WRITING NEW OUTPUTS
% ------------------------------------------------------------------------
results_dir = matlab_results_dir();
if exist(results_dir, 'dir')
    files = dir(fullfile(results_dir, '*.csv'));
    for k = 1:numel(files)
        delete(fullfile(results_dir, files(k).name));
    end
    files = dir(fullfile(results_dir, '*.png'));
    for k = 1:numel(files)
        delete(fullfile(results_dir, files(k).name));
    end
end

%% ------------------------------------------------------------------------
% USER SETTINGS
% -------------------------------------------------------------------------

g = 9.81;                  % [m/s^2]
rho_air = 1.225;           % [kg/m^3]
rho_helium = 0.164;        % [kg/m^3]
% Arbitrary reference envelope surface density [kg/m^2].
% Typical thin polymer film; absolute value is arbitrary — shapes are
% compared at the same sigma_ref so it cancels in relative rankings.
sigma_ref = 0.05;          % [kg/m^2]

% Mass range [kg]
mass_vec = linspace(0.001, 0.100, 100);   % 1 g to 100 g

% Default user-selected mass [g]
user_mass_g = 35;
user_mass = user_mass_g / 1000; %#ok<NASGU>

% Volume sweep [m^3]
volume_vec = linspace(0.001, 0.100, 200);   % 1 L to 100 L

% Target buoyancy ratio
target_buoyancy_ratio = 0.99;

% Statistical significance threshold for ANOVA reporting
anova_alpha = 0.005;

% Crazyflie baseline
baseline_mass_g = 28;
baseline_time_min = 7;

% Shape definitions
shapes = [
    struct('name','Sphere', ...
           'aspect',[1.0 1.0 1.0], ...
           'cd_xyz',[0.90 0.90 0.90]), ...

    struct('name','Prolate Ellipsoid', ...
           'aspect',[1.8 1.0 1.0], ...
           'cd_xyz',[0.65 0.95 0.95]), ...

    struct('name','Cuboid', ...
            'aspect',[1.0 1.0 1.0], ...
            'cd_xyz',[1.00 1.00 1.00]), ...

    struct('name','Flattened Ellipsoid', ...
           'aspect',[1.6 1.3 0.7], ...
           'cd_xyz',[0.82 0.92 1.08]) ...
];

nShapes = numel(shapes);
nMass   = numel(mass_vec);
nVol    = numel(volume_vec);

shape_names = cell(1, nShapes);
for s = 1:nShapes
    shape_names{s} = shapes(s).name;
end

mass_strings = cellstr(num2str((mass_vec(:)*1000), '%.1f'));

%% ------------------------------------------------------------------------
% PREALLOCATE
% -------------------------------------------------------------------------

buoyancy_ratio      = zeros(nMass, nVol, nShapes);
endurance_factor    = zeros(nMass, nVol, nShapes);
disturb_x           = zeros(nMass, nVol, nShapes);
disturb_y           = zeros(nMass, nVol, nShapes);
disturb_z           = zeros(nMass, nVol, nShapes);
disturb_total       = zeros(nMass, nVol, nShapes);
surf_area_ratio     = zeros(nMass, nVol, nShapes);
structural_efficiency = zeros(nMass, nVol, nShapes);
target_disturb_mean = NaN(nMass, nShapes);
target_disturb_worst = NaN(nMass, nShapes);
target_disturb_aniso = NaN(nMass, nShapes);
target_disturb_index = NaN(nMass, nShapes);
target_sa_to_vol = NaN(nMass, nShapes);
target_struct_iq = NaN(nMass, nShapes);
target_struct_mass_frac = NaN(nMass, nShapes);

required_volume_for_target = NaN(nMass, nShapes);
best_volume                = NaN(nMass, nShapes);
best_endurance             = NaN(nMass, nShapes);
best_disturb_x             = NaN(nMass, nShapes);
best_disturb_y             = NaN(nMass, nShapes);
best_disturb_z             = NaN(nMass, nShapes);

%% ------------------------------------------------------------------------
% MAIN PARAMETER SWEEP
% -------------------------------------------------------------------------

for s = 1:nShapes
    for i = 1:nMass
        for j = 1:nVol

            m_total = mass_vec(i);
            W_total = m_total * g;

            V_eff = volume_vec(j);
            F_b = buoyant_force(V_eff, rho_air, rho_helium, g);

            br = F_b / W_total;
            buoyancy_ratio(i,j,s) = br;

            F_res = max(W_total - F_b, 0);
            power_ratio = (max(F_res, 1e-8) / W_total)^(3/2);
            endurance_factor(i,j,s) = 1 / max(power_ratio, 1e-8);

            [L, Wd, H] = shape_dimensions_from_volume(volume_vec(j), shapes(s).aspect, shapes(s).name);

            A_yz = Wd * H;
            A_xz = L * H;
            A_xy = L * Wd;

            over_buoyant_penalty = max(br - 1.0, 0);

            dx = shapes(s).cd_xyz(1) * A_yz * (1 + 0.5 * over_buoyant_penalty);
            dy = shapes(s).cd_xyz(2) * A_xz * (1 + 0.5 * over_buoyant_penalty);
            dz = shapes(s).cd_xyz(3) * A_xy * (1 + 0.5 * over_buoyant_penalty);

            disturb_x(i,j,s) = dx;
            disturb_y(i,j,s) = dy;
            disturb_z(i,j,s) = dz;
            disturb_total(i,j,s) = dx + dy + dz;

            S = surface_area_from_volume(volume_vec(j), shapes(s).aspect, shapes(s).name);
            surf_area_ratio(i,j,s) = S / volume_vec(j);
            structural_efficiency(i,j,s) = isoperimetric_quotient(volume_vec(j), S);
        end
    end
end

%% ------------------------------------------------------------------------
% SHAPE EVALUATION AT TARGET BUOYANCY RATIO
% -------------------------------------------------------------------------

for s = 1:nShapes
    for i = 1:nMass
        % Evaluate each shape at the controlled operating point BR = target_buoyancy_ratio.
        V_req = (target_buoyancy_ratio * mass_vec(i)) / (rho_air - rho_helium);

        if V_req <= max(volume_vec)
            required_volume_for_target(i,s) = V_req;
            best_volume(i,s) = V_req;

            best_endurance(i,s) = endurance_from_buoyancy_ratio(target_buoyancy_ratio);

            [L, Wd, H] = shape_dimensions_from_volume(V_req, shapes(s).aspect, shapes(s).name);
            dims = [L, Wd, H];
            S = surface_area_from_volume(V_req, shapes(s).aspect, shapes(s).name);
            target_sa_to_vol(i,s) = S / V_req;
            target_struct_iq(i,s) = isoperimetric_quotient(V_req, S);
            % Structural mass fraction: envelope mass (sigma_ref * S) relative to
            % total system mass. V_req scales with mass, so S ~ V^(2/3) ~ mass^(2/3),
            % meaning this ratio varies with mass and differs between shapes.
            target_struct_mass_frac(i,s) = (sigma_ref * S) / mass_vec(i);

            [~, ~, ~, ~, metrics] = disturbance_surface_metrics_3d(dims, shapes(s).cd_xyz, shapes(s).name, 56, 32);
            target_disturb_mean(i,s) = metrics.mean_response;
            target_disturb_worst(i,s) = metrics.worst_response;
            target_disturb_aniso(i,s) = metrics.anisotropy;

            target_disturb_index(i,s) = metrics.mean_response .* (1 + 0.7 * metrics.anisotropy) .* ...
                (1 + 0.3 * (metrics.worst_response / max(metrics.mean_response, eps)));
        end
    end
end

%% ------------------------------------------------------------------------
% SHAPE METRICS AT CONTROLLED BUOYANCY TARGET
% -------------------------------------------------------------------------

for i = 1:nMass
    for s = 1:nShapes
        if ~isnan(required_volume_for_target(i,s))
            [L, Wd, H] = shape_dimensions_from_volume(best_volume(i,s), shapes(s).aspect, shapes(s).name);
            A_yz = Wd * H;
            A_xz = L * H;
            A_xy = L * Wd;

            over_buoyant_penalty = max(target_buoyancy_ratio - 1.0, 0);

            best_disturb_x(i,s) = shapes(s).cd_xyz(1) * A_yz * (1 + 0.5 * over_buoyant_penalty);
            best_disturb_y(i,s) = shapes(s).cd_xyz(2) * A_xz * (1 + 0.5 * over_buoyant_penalty);
            best_disturb_z(i,s) = shapes(s).cd_xyz(3) * A_xy * (1 + 0.5 * over_buoyant_penalty);
        end
    end
end

%% ------------------------------------------------------------------------
% PER-METRIC STATISTICS
% -------------------------------------------------------------------------

metric_titles = {'Stability Disturbance Index', 'Surface Area / Volume', 'Structural Mass Fraction'};
metric_data = {target_disturb_index, target_sa_to_vol, target_struct_mass_frac};
metric_anova_text = cell(1, numel(metric_data));
metric_anova_p = NaN(1, numel(metric_data));
metric_pairwise_sig_count = zeros(1, numel(metric_data));
metric_sig_pairs_text = repmat({'None'}, 1, numel(metric_data));
metric_stat_note = repmat({'ANOVA + Tukey-Kramer applied.'}, 1, numel(metric_data));
pairwise_rows = {};

for m = 1:numel(metric_data)
    metric_values = [];
    metric_labels = {};
    vals_by_shape = cell(nShapes, 1);
    group_counts = zeros(nShapes, 1);
    group_var = zeros(nShapes, 1);
    for s = 1:nShapes
        vals = metric_data{m}(:,s);
        vals = vals(~isnan(vals));
        vals_by_shape{s} = vals(:);
        group_counts(s) = numel(vals);
        if numel(vals) >= 2
            group_var(s) = var(vals, 0);
        else
            group_var(s) = 0;
        end
        metric_values = [metric_values; vals(:)]; %#ok<AGROW>
        metric_labels = [metric_labels; repmat({shapes(s).name}, numel(vals), 1)]; %#ok<AGROW>
    end

    % If the metric is effectively deterministic by shape (or under-replicated),
    % inferential p-values are not meaningful because ANOVA assumptions fail.
    has_replicates = all(group_counts >= 2);
    has_within_group_variation = any(group_var > 1e-12);
    if ~has_replicates || ~has_within_group_variation
        metric_anova_p(m) = NaN;
        metric_pairwise_sig_count(m) = 0;
        metric_sig_pairs_text{m} = 'None';
        metric_stat_note{m} = 'Deterministic/low-variance metric: inferential p-values not reported.';
        metric_anova_text{m} = sprintf('%s: inferential ANOVA skipped (deterministic or under-replicated data).', metric_titles{m});

        for a = 1:(nShapes-1)
            for b = (a+1):nShapes
                mean_a = mean(vals_by_shape{a});
                mean_b = mean(vals_by_shape{b});
                pairwise_rows(end+1, :) = { ...
                    metric_titles{m}, ...
                    shapes(a).name, ...
                    shapes(b).name, ...
                    mean_a - mean_b, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    false}; %#ok<AGROW>
            end
        end
        continue;
    end

    try
        [p_val, ~, anova_stats] = anova1(metric_values, metric_labels, 'off');
        p_val_safe = max(p_val, realmin('double'));
        metric_anova_p(m) = p_val_safe;
        sig_pair_labels = {};
        seen_pair_keys = {};
        if p_val_safe < anova_alpha
            metric_anova_text{m} = sprintf('%s: significant by ANOVA (p = %s, alpha = %s).', ...
                metric_titles{m}, format_p_value(p_val_safe), format_p_value(anova_alpha));
        else
            metric_anova_text{m} = sprintf('%s: not significant by ANOVA (p = %s, alpha = %s).', ...
                metric_titles{m}, format_p_value(p_val_safe), format_p_value(anova_alpha));
        end

        % Pairwise shape comparisons for this metric (Tukey-Kramer by default).
        if ~isempty(anova_stats)
            comparison = multcompare(anova_stats, 'Display', 'off');
            for r = 1:size(comparison, 1)
                group_a = anova_stats.gnames{comparison(r,1)};
                group_b = anova_stats.gnames{comparison(r,2)};

                pair_sorted = sort({group_a, group_b});
                pair_key = [pair_sorted{1} '|' pair_sorted{2}];
                if any(strcmp(seen_pair_keys, pair_key))
                    continue;
                end
                seen_pair_keys{end+1} = pair_key; %#ok<AGROW>

                p_pair = max(comparison(r,6), realmin('double'));
                sig_pair = p_pair < anova_alpha;
                metric_pairwise_sig_count(m) = metric_pairwise_sig_count(m) + sig_pair;
                if sig_pair
                    sig_pair_labels{end+1} = sprintf('%s vs %s (p=%s)', pair_sorted{1}, pair_sorted{2}, format_p_value(p_pair)); %#ok<AGROW>
                end

                pairwise_rows(end+1, :) = { ...
                    metric_titles{m}, ...
                    pair_sorted{1}, ...
                    pair_sorted{2}, ...
                    comparison(r,4), ...
                    comparison(r,3), ...
                    comparison(r,5), ...
                    p_pair, ...
                    sig_pair}; %#ok<AGROW>
            end
        end
        if ~isempty(sig_pair_labels)
            metric_sig_pairs_text{m} = strjoin(sig_pair_labels, '; ');
        end
    catch
        metric_anova_text{m} = sprintf('%s: ANOVA unavailable (Statistics Toolbox may be required).', metric_titles{m});
        metric_stat_note{m} = 'ANOVA unavailable (Statistics Toolbox may be required).';
    end
end

%% ------------------------------------------------------------------------
% SHARED RESULTS EXPORT (CSV + PNG)
% -------------------------------------------------------------------------

results_dir = matlab_results_dir();

shape_rows = [];
for s = 1:nShapes
    for i = 1:nMass
        if ~isnan(best_volume(i,s)) && ~isnan(best_endurance(i,s))
            shape_rows = [shape_rows; ...
                i, ...
                s, ...
                mass_vec(i)*1000, ...
                best_volume(i,s)*1000, ...
                best_endurance(i,s), ...
                target_disturb_index(i,s), ...
                target_sa_to_vol(i,s), ...
                target_struct_mass_frac(i,s)]; %#ok<AGROW>
        end
    end
end

shape_analysis_tbl = array2table(shape_rows, 'VariableNames', {
    'mass_index', 'shape_index', 'mass_g', 'target_volume_L', 'endurance_factor_at_target_BR', ...
    'stability_disturbance_index', 'surface_area_to_volume', 'structural_mass_fraction'});
shape_analysis_tbl.shape_name = shape_names(shape_analysis_tbl.shape_index)';
shape_analysis_tbl = movevars(shape_analysis_tbl, 'shape_name', 'After', 'shape_index');
safe_writetable(shape_analysis_tbl, fullfile(results_dir, 'shape_analysis_results.csv'));

if ~isempty(pairwise_rows)
    pairwise_tbl = cell2table(pairwise_rows, 'VariableNames', {
        'metric', 'shape_a', 'shape_b', 'mean_diff', 'ci_low', 'ci_high', 'p_value', 'significant_at_alpha'});
else
    pairwise_tbl = table('Size', [0, 8], ...
        'VariableTypes', {'string', 'string', 'string', 'double', 'double', 'double', 'double', 'logical'}, ...
        'VariableNames', {'metric', 'shape_a', 'shape_b', 'mean_diff', 'ci_low', 'ci_high', 'p_value', 'significant_at_alpha'});
end
safe_writetable(pairwise_tbl, fullfile(results_dir, 'metric_pairwise_comparisons.csv'));

summary_rows = cell(numel(metric_titles), 7);
for m = 1:numel(metric_titles)
    anova_sig = ~isnan(metric_anova_p(m)) && (metric_anova_p(m) < anova_alpha);
    metric_pairs = pairwise_tbl(strcmp(string(pairwise_tbl.metric), string(metric_titles{m})), :);
    n_total_pairs = height(metric_pairs);

    sig_pairs = metric_pairs(metric_pairs.significant_at_alpha, :);
    if isempty(sig_pairs)
        sig_pairs_text = 'None';
    else
        sig_labels = cell(height(sig_pairs), 1);
        for r = 1:height(sig_pairs)
            sig_labels{r} = sprintf('%s vs %s (p=%s)', ...
                sig_pairs.shape_a{r}, sig_pairs.shape_b{r}, format_p_value(sig_pairs.p_value(r)));
        end
        sig_labels = unique(sig_labels, 'stable');
        sig_pairs_text = strjoin(sig_labels, '; ');
    end
    metric_sig_pairs_text{m} = sig_pairs_text;

    summary_rows{m,1} = metric_titles{m};
    summary_rows{m,2} = metric_anova_p(m);
    summary_rows{m,3} = anova_sig;
    summary_rows{m,4} = metric_pairwise_sig_count(m);
    summary_rows{m,5} = n_total_pairs;
    summary_rows{m,6} = sig_pairs_text;
    summary_rows{m,7} = metric_stat_note{m};
end

metric_summary_tbl = cell2table(summary_rows, 'VariableNames', {
    'metric', 'anova_p_value', 'anova_significant_at_alpha', 'n_significant_pairs', 'n_total_pairs', 'significant_pairs', 'statistical_note'});
safe_writetable(metric_summary_tbl, fullfile(results_dir, 'metric_significance_summary.csv'));

required_volume_tbl = array2table(mass_vec(:) * 1000, 'VariableNames', {'mass_g'});
for s = 1:nShapes
    variable_name = matlab.lang.makeValidName([lower(strrep(shape_names{s}, ' ', '_')) '_required_volume_L']);
    required_volume_tbl.(variable_name) = required_volume_for_target(:, s) * 1000;
end
safe_writetable(required_volume_tbl, fullfile(results_dir, 'buoyancy_test_results.csv'));

battery_life_tbl = array2table(mass_vec(:) * 1000, 'VariableNames', {'mass_g'});
for s = 1:nShapes
    variable_name = matlab.lang.makeValidName([lower(strrep(shape_names{s}, ' ', '_')) '_endurance_factor']);
    battery_life_tbl.(variable_name) = best_endurance(:, s);
end
safe_writetable(battery_life_tbl, fullfile(results_dir, 'battery_life_results.csv'));

%% ------------------------------------------------------------------------
% DOCUMENTATION-STYLE SUMMARY TABLES
% -------------------------------------------------------------------------

% 1. Per-shape mean metrics summary table
doc_shape_metrics = cell(nShapes, 5);
for s = 1:nShapes
    doc_shape_metrics{s,1} = shape_names{s};
    doc_shape_metrics{s,2} = mean(target_disturb_index(:,s), 'omitnan');
    doc_shape_metrics{s,3} = mean(target_sa_to_vol(:,s), 'omitnan');
    doc_shape_metrics{s,4} = mean(target_struct_mass_frac(:,s), 'omitnan');
    doc_shape_metrics{s,5} = ""; % Placeholder for overall observation/comment
end
doc_shape_metrics_tbl = cell2table(doc_shape_metrics, 'VariableNames', { ...
    'Shape', 'Mean_disturbance_stability_index', 'Mean_surface_area_to_volume', 'Mean_structural_mass_fraction', 'Overall_observation'});
safe_writetable(doc_shape_metrics_tbl, fullfile(results_dir, 'doc_shape_metrics_summary.csv'));

% 2. Per-shape geometry/dimension summary table for reference mass and target buoyancy
ref_mass_idx = find(abs(mass_vec*1000 - user_mass_g) < 1e-3, 1, 'first');
doc_shape_geom = cell(nShapes, 8);
for s = 1:nShapes
    V_req = (target_buoyancy_ratio * mass_vec(ref_mass_idx)) / (rho_air - rho_helium);
    [L, Wd, H] = shape_dimensions_from_volume(V_req, shapes(s).aspect, shapes(s).name);
    S = surface_area_from_volume(V_req, shapes(s).aspect, shapes(s).name);
    ratio = S / V_req;
    doc_shape_geom{s,1} = shape_names{s};
    doc_shape_geom{s,2} = V_req * 1000; % L
    doc_shape_geom{s,3} = L;
    doc_shape_geom{s,4} = Wd;
    doc_shape_geom{s,5} = H;
    doc_shape_geom{s,6} = S;
    doc_shape_geom{s,7} = ratio;
    doc_shape_geom{s,8} = ""; % Placeholder for spatial footprint comment
end
doc_shape_geom_tbl = cell2table(doc_shape_geom, 'VariableNames', { ...
    'Shape', 'Required_volume_L', 'Length_m', 'Width_m', 'Height_m', 'Surface_area_m2', 'SA_to_V_1_per_m', 'Spatial_footprint_comment'});
safe_writetable(doc_shape_geom_tbl, fullfile(results_dir, 'doc_shape_geometry_summary.csv'));

% 3. Per-metric ANOVA/statistical summary table (already written as metric_significance_summary.csv)

% 4. Pairwise significance matrices for each metric
metric_names = {'Stability Disturbance Index', 'Surface Area / Volume', 'Structural Mass Fraction'};
for m = 1:numel(metric_names)
    matrix = cell(nShapes+1, nShapes+1);
    matrix(1,2:end) = shape_names;
    matrix(2:end,1) = shape_names';
    matrix(1,1) = {''};
    for i = 1:nShapes
        for j = 1:nShapes
            if i == j
                matrix{i+1,j+1} = '-';
            else
                % Find pairwise significance for this metric and shape pair
                mask = strcmp(pairwise_tbl.metric, metric_names{m}) & ...
                       ((strcmp(pairwise_tbl.shape_a, shape_names{i}) & strcmp(pairwise_tbl.shape_b, shape_names{j})) | ...
                        (strcmp(pairwise_tbl.shape_a, shape_names{j}) & strcmp(pairwise_tbl.shape_b, shape_names{i})));
                if any(mask)
                    sig = pairwise_tbl.significant_at_alpha(mask);
                    if sig
                        matrix{i+1,j+1} = 'Significant';
                    else
                        matrix{i+1,j+1} = 'N.S.';
                    end
                else
                    matrix{i+1,j+1} = 'N.S.';
                end
            end
        end
    end
    T = cell2table(matrix(2:end,2:end), 'VariableNames', shape_names, 'RowNames', shape_names);
    safe_writetable(T, fullfile(results_dir, sprintf('doc_pairwise_significance_%s.csv', matlab.lang.makeValidName(metric_names{m}))));
end

fig_battery = figure('Name', 'Battery Life: Endurance Factor vs Mass', ...
    'Color', 'w', 'Position', [200 200 820 480], 'Visible', 'off');
ax_bat = axes(fig_battery);
hold(ax_bat, 'on');
line_styles = {'-o', '-s', '-^', '-d'};
for s = 1:nShapes
    valid = ~isnan(best_endurance(:, s));
    plot(ax_bat, mass_vec(valid)*1000, best_endurance(valid, s), ...
        line_styles{mod(s-1, numel(line_styles))+1}, ...
        'DisplayName', shape_names{s}, 'LineWidth', 1.6);
end
hold(ax_bat, 'off');
xlabel(ax_bat, 'System mass [g]');
ylabel(ax_bat, 'Endurance factor [-]  (higher = longer flight)');
title(ax_bat, 'Battery Life: Endurance Factor vs System Mass');
legend(ax_bat, 'Location', 'northeast');
grid(ax_bat, 'on');
box(ax_bat, 'on');
safe_exportgraphics(fig_battery, fullfile(results_dir, 'battery_life_results.png'));
close(fig_battery);

%% ------------------------------------------------------------------------
% COMMAND WINDOW SUMMARY
% -------------------------------------------------------------------------

fprintf('\n=== Best design summary ===\n');
fprintf('%-22s %-10s %-15s %-15s %-15s\n', ...
    'Shape', 'Mass [g]', 'Target Vol [L]', 'Endu @ BR target', 'Stab. Idx');

for s = 1:nShapes
    for i = 1:nMass
        if ~isnan(best_volume(i,s))
            fprintf('%-22s %-10.1f %-15.2f %-15.2f %-15.3f\n', ...
                shapes(s).name, ...
                mass_vec(i)*1000, ...
                best_volume(i,s)*1000, ...
                best_endurance(i,s), ...
                target_disturb_index(i,s));
        end
    end
end

fprintf('\n=== Per-metric ANOVA summary ===\n');
for m = 1:numel(metric_anova_text)
    fprintf('%s\n', metric_anova_text{m});
    fprintf('  Pairwise significant differences: %d\n', metric_pairwise_sig_count(m));
end

%% ------------------------------------------------------------------------
% FIGURE + TABS
% -------------------------------------------------------------------------

fig = figure('Name', 'Buoyancy-Assisted UAV Envelope Trade Study', ...
             'Color', 'w', ...
             'Position', [100 80 1450 850]);

tg = uitabgroup(fig);

tab1 = uitab(tg, 'Title', '3D Shape Viewer');
tab2 = uitab(tg, 'Title', 'Endurance');
tab3 = uitab(tg, 'Title', '3D Disturbance');
tab4 = uitab(tg, 'Title', 'Metric Statistics');

%% ------------------------------------------------------------------------
% TAB 1: 3D SHAPE VIEWER
% -------------------------------------------------------------------------

ax1 = axes('Parent', tab1, 'Units', 'normalized', 'Position', [0.05 0.12 0.48 0.78]);
box(ax1, 'on');
grid(ax1, 'on');
view(ax1, 3);

uicontrol('Parent', tab1, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.93 0.08 0.04], ...
    'String', 'Shape', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'w');

popupShape = uicontrol('Parent', tab1, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [0.12 0.935 0.16 0.04], ...
    'String', shape_names, ...
    'Value', 1, ...
    'Callback', @update_all_tabs);

uicontrol('Parent', tab1, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.31 0.93 0.12 0.04], ...
    'String', 'Reference mass [g]', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'w');

uicontrol('Parent', tab1, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'Position', [0.43 0.935 0.10 0.04], ...
    'String', num2str(user_mass_g, '%.1f'), ...
    'Callback', @config_input_callback, ...
    'Tag', 'massInputBox');

uicontrol('Parent', tab1, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.56 0.93 0.12 0.04], ...
    'String', 'Target buoyancy ratio', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'w');

uicontrol('Parent', tab1, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'Position', [0.69 0.935 0.08 0.04], ...
    'String', num2str(target_buoyancy_ratio, '%.2f'), ...
    'Callback', @config_input_callback, ...
    'Tag', 'buoyancyInputBox');

uicontrol('Parent', tab1, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.80 0.935 0.10 0.04], ...
    'String', 'Update', ...
    'Callback', @config_input_callback);

infoBox = uicontrol('Parent', tab1, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.58 0.18 0.35 0.66], ...
    'FontName', 'Courier New', ...
    'FontSize', 10, ...
    'Max', 2, 'Min', 0);

%% ------------------------------------------------------------------------
% TAB 2: ENDURANCE
% -------------------------------------------------------------------------

axEndu = axes('Parent', tab2, 'Units', 'normalized', 'Position', [0.08 0.13 0.7 0.8]);

annotation_text_tab2 = {
    'Interpretation:'
    ' '
    'This map shows estimated flight time using a physics-guided hover model.'
    ' '
    'Model basis:'
    'Hover power scales with required thrust^(3/2).'
    'Buoyancy reduces required rotor thrust.'
    'Crazyflie baseline is fixed at 28 g, 0 buoyancy, 7 min.'
    ' '
    'This is still a comparative estimate, not a full propulsion model.'
};

uicontrol('Parent', tab2, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.01 0.01 0.98 0.07], ...
    'String', annotation_text_tab2, ...
    'FontSize', 10, ...
    'BackgroundColor', 'w', ...
    'Max', 2, 'Min', 0);

%% ------------------------------------------------------------------------
% TAB 3: 3D DISTURBANCE
% -------------------------------------------------------------------------

uicontrol('Parent', tab3, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.93 0.12 0.04], ...
    'String', 'Reference mass [g]', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'w');

popupDistMass = uicontrol('Parent', tab3, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [0.17 0.935 0.10 0.04], ...
    'String', mass_strings, ...
    'Value', ceil(nMass/2), ...
    'Callback', @update_disturbance_plot_3d);

uicontrol('Parent', tab3, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.31 0.93 0.08 0.04], ...
    'String', 'Shape', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'w');

popupDistShape = uicontrol('Parent', tab3, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [0.39 0.935 0.16 0.04], ...
    'String', shape_names, ...
    'Value', 1, ...
    'Callback', @update_disturbance_plot_3d);

ax3a = axes('Parent', tab3, 'Units', 'normalized', 'Position', [0.05 0.18 0.42 0.66]);
ax3b = axes('Parent', tab3, 'Units', 'normalized', 'Position', [0.52 0.54 0.26 0.28]);
ax3c = axes('Parent', tab3, 'Units', 'normalized', 'Position', [0.52 0.18 0.26 0.24]);

infoBox3 = uicontrol('Parent', tab3, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.81 0.18 0.16 0.66], ...
    'FontSize', 10, ...
    'BackgroundColor', 'w', ...
    'Max', 2, 'Min', 0);

uicontrol('Parent', tab3, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.03 0.92 0.10], ...
    'String', {
        'Interpretation:'
        ' '
        'The coloured 3D shape is not the balloon itself. It is the disturbance response envelope.'
        ' '
        'A larger radius in a direction means that orientation is more exposed to external flow.'
        'A more spherical response envelope means more isotropic behaviour.'
        ' '
        'Lower mean and lower worst-case response are desirable.'
        'Lower anisotropy means the shape behaves more consistently in 3D space.'
    }, ...
    'FontSize', 10, ...
    'BackgroundColor', 'w', ...
    'Max', 2, 'Min', 0);

%% ------------------------------------------------------------------------
% TAB 4: METRIC STATISTICS
% -------------------------------------------------------------------------

ax4a = axes('Parent', tab4, 'Units', 'normalized', 'Position', [0.06 0.56 0.26 0.34]);
boxplot(ax4a, target_disturb_index, 'Labels', shape_names);
ylabel(ax4a, 'Disturbance index [-] (lower better)');
title(ax4a, 'Stability to External Force');
grid(ax4a, 'on');

ax4b = axes('Parent', tab4, 'Units', 'normalized', 'Position', [0.37 0.56 0.26 0.34]);
boxplot(ax4b, target_sa_to_vol, 'Labels', shape_names);
ylabel(ax4b, 'S/V [1/m] (lower better)');
title(ax4b, 'Surface Area to Volume');
grid(ax4b, 'on');

ax4c = axes('Parent', tab4, 'Units', 'normalized', 'Position', [0.68 0.56 0.26 0.34]);
boxplot(ax4c, target_struct_mass_frac, 'Labels', shape_names);
ylabel(ax4c, 'Struct. mass fraction [-] (lower better)');
title(ax4c, 'Structural Mass Fraction');
grid(ax4c, 'on');

stats_lines = {'Independent metric analysis (no composite score):'; ' '};
for m = 1:numel(metric_titles)
    stats_lines{end+1,1} = metric_anova_text{m}; %#ok<SAGROW>
    stats_lines{end+1,1} = sprintf('  Pairwise significant differences: %d', metric_pairwise_sig_count(m)); %#ok<SAGROW>
    stats_lines{end+1,1} = sprintf('  Significant pairs: %s', metric_sig_pairs_text{m}); %#ok<SAGROW>
end
stats_lines{end+1,1} = ' ';
stats_lines{end+1,1} = 'Per-shape means by metric:';

for s = 1:nShapes
    stats_lines{end+1,1} = sprintf('%s | Stability idx %.4f | S/V %.4f | Struct penalty %.4f', ...
        shape_names{s}, ...
        mean(target_disturb_index(:,s), 'omitnan'), ...
        mean(target_sa_to_vol(:,s), 'omitnan'), ...
        mean(target_struct_mass_frac(:,s), 'omitnan')); %#ok<SAGROW>
end

uicontrol('Parent', tab4, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.06 0.08 0.88 0.40], ...
    'String', stats_lines, ...
    'FontSize', 10, ...
    'BackgroundColor', 'w', ...
    'Max', 2, 'Min', 0);

%% ------------------------------------------------------------------------
% INITIAL DRAW
% -------------------------------------------------------------------------

update_all_tabs();
drawnow;
safe_exportgraphics(fig, fullfile(results_dir, 'relevant_graph_outputs.png'));

%% ------------------------------------------------------------------------
% NESTED CALLBACKS
% -------------------------------------------------------------------------

    function update_all_tabs(~, ~)
        massInputBox = findobj(fig, 'Tag', 'massInputBox');
        buoyancyInputBox = findobj(fig, 'Tag', 'buoyancyInputBox');

        user_mass_g_local = str2double(get(massInputBox, 'String'));
        if isnan(user_mass_g_local) || user_mass_g_local <= 0
            user_mass_g_local = 35;
            set(massInputBox, 'String', '35.0');
        end
        user_mass_local = user_mass_g_local / 1000;

        target_buoyancy_ratio_local = str2double(get(buoyancyInputBox, 'String'));
        if isnan(target_buoyancy_ratio_local) || target_buoyancy_ratio_local <= 0
            target_buoyancy_ratio_local = 0.99;
            set(buoyancyInputBox, 'String', '0.99');
        end

        local_required_volume = NaN(1, nShapes);

        for s = 1:nShapes
            V_req = (target_buoyancy_ratio_local * user_mass_local) / (rho_air - rho_helium);
            if V_req <= max(volume_vec)
                local_required_volume(s) = V_req;
            end
        end

        % --- Update Tab 1 ---
        cla(ax1);
        shapeIdx = get(popupShape, 'Value');
        V_req = local_required_volume(shapeIdx);

        if isnan(V_req)
            max_vol_L = max(volume_vec) * 1000;
            title(ax1, 'No feasible design found');
            set(infoBox, 'String', { ...
                'No feasible design found for this mass and buoyancy ratio.'; ...
                ['Not feasible within current envelope size constraint (max = ' num2str(max_vol_L, '%.1f') ' L).'] ...
                });
        else
            [L, Wd, H] = shape_dimensions_from_volume(V_req, shapes(shapeIdx).aspect, shapes(shapeIdx).name);
            S = surface_area_from_volume(V_req, shapes(shapeIdx).aspect, shapes(shapeIdx).name);
            ratio = S / V_req;

            plot_shape_on_axes(ax1, shapes(shapeIdx).name, [L Wd H]);

            info_lines = {
                sprintf('Selected shape: %s', shapes(shapeIdx).name)
                sprintf('Reference mass: %.1f g', user_mass_g_local)
                sprintf('Target buoyancy ratio: %.2f', target_buoyancy_ratio_local)
                sprintf('Required envelope volume: %.2f L', V_req*1000)
                sprintf('Endurance factor at target BR: %.2f (same for all shapes)', endurance_from_buoyancy_ratio(target_buoyancy_ratio_local))
                ' '
                'Estimated dimensions:'
                sprintf('  Length = %.3f m', L)
                sprintf('  Width  = %.3f m', Wd)
                sprintf('  Height = %.3f m', H)
                ' '
                'Shape characteristics:'
                sprintf('Surface area: %.4f m^2', S)
                sprintf('Surface area / volume: %.2f 1/m', ratio)
                sprintf('Structural efficiency (IQ): %.4f', isoperimetric_quotient(V_req, S))
            };
            set(infoBox, 'String', info_lines);
        end

        update_endurance_map();
        update_disturbance_plot_3d();
    end

    function config_input_callback(~, ~)
        update_all_tabs();
    end

    function update_endurance_map(~, ~)
        ax = axEndu;

        mass_fine = linspace(10, 80, 120);
        br_fine   = linspace(0.0, 0.95, 160);

        [MASS, BR] = meshgrid(mass_fine, br_fine);

        thrust_fraction = max(1 - BR, 0.01);

        flight_time = baseline_time_min .* ...
                      (baseline_mass_g ./ MASS).^0.5 .* ...
                      (1 ./ thrust_fraction).^1.5;

        realism_taper = 1 ./ (1 + 0.18 * (BR ./ 0.95).^6);
        flight_time = flight_time .* realism_taper;

        flight_time = min(flight_time, 120);

        cla(ax);
        surf(ax, MASS, BR, flight_time, ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.98);

        xlabel(ax, 'System mass [g]');
        ylabel(ax, 'Buoyancy ratio');
        zlabel(ax, 'Flight Time [min]');
        title(ax, 'Estimated Flight Time from Mass and Buoyancy');

        colormap(ax, turbo);
        cb = colorbar(ax);
        cb.Label.String = 'Estimated flight time [min]';

        view(ax, 45, 30);
        grid(ax, 'on');

        hold(ax, 'on');
        scatter3(ax, baseline_mass_g, 0, baseline_time_min, 120, 'k', 'filled');
        plot3(ax, [baseline_mass_g baseline_mass_g], [0 0], [0 baseline_time_min], 'k--', 'LineWidth', 1.2);

        [~, idx] = max(flight_time(:));
        opt_mass = MASS(idx);
        opt_br   = BR(idx);
        opt_time = flight_time(idx);

        scatter3(ax, opt_mass, opt_br, opt_time, 150, 'r', 'filled');
        text(ax, opt_mass, opt_br, opt_time, ...
            sprintf('  Best region: %.1f g, BR %.2f', opt_mass, opt_br), ...
            'FontSize', 9, 'FontWeight', 'bold');

        hold(ax, 'off');
    end

    function update_disturbance_plot(~, ~)
        update_disturbance_plot_3d();
    end

    function update_disturbance_plot_3d(~, ~)
        massIdx = get(popupDistMass, 'Value');
        shapeIdx = get(popupDistShape, 'Value');

        cla(ax3a);
        cla(ax3b);
        cla(ax3c);

        all_metrics = NaN(nShapes, 4);

        for s = 1:nShapes
            V_here = best_volume(massIdx, s);
            if isnan(V_here)
                continue;
            end

            [L, Wd, H] = shape_dimensions_from_volume(V_here, shapes(s).aspect, shapes(s).name);
            dims = [L, Wd, H];

            [Xresp, Yresp, Zresp, response_map, metrics] = ...
                disturbance_surface_metrics_3d(dims, shapes(s).cd_xyz, shapes(s).name, 56, 32);

            all_metrics(s,1) = metrics.mean_response;
            all_metrics(s,2) = metrics.worst_response;
            all_metrics(s,3) = metrics.anisotropy;
            all_metrics(s,4) = metrics.stability_score;

            if s == shapeIdx
                char_scale = max(dims) / 2;
                Xenv = char_scale * Xresp;
                Yenv = char_scale * Yresp;
                Zenv = char_scale * Zresp;

                if strcmpi(shapes(s).name, 'cuboid')
                    draw_cuboid_on_axes(ax3a, dims, 0.18, [0.7 0.7 0.7]);
                else
                    [Xshape, Yshape, Zshape] = shape_surface_from_dims(shapes(s).name, dims, 50);
                    surf(ax3a, Xshape, Yshape, Zshape, ...
                        'EdgeColor', 'none', ...
                        'FaceAlpha', 0.18, ...
                        'FaceColor', [0.7 0.7 0.7]);
                end
                hold(ax3a, 'on');

                surf(ax3a, Xenv, Yenv, Zenv, response_map, ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.92);

                hold(ax3a, 'off');
                grid(ax3a, 'on');
                xlabel(ax3a, 'X [m]');
                ylabel(ax3a, 'Y [m]');
                zlabel(ax3a, 'Z [m]');
                title(ax3a, sprintf('3D disturbance envelope: %s', shapes(s).name));
                view(ax3a, 3);
                env_half_span = max(abs([Xenv(:); Yenv(:); Zenv(:)]));
                shape_half_span = max(dims) / 2;
                set_square_axes_with_padding(ax3a, max(env_half_span, shape_half_span), 1.18);
                colormap(ax3a, turbo);
                cb = colorbar(ax3a);
                cb.Label.String = 'Relative disturbance response [-]';
                camlight(ax3a, 'headlight');
                lighting(ax3a, 'gouraud');
            end
        end

        if all(all(isnan(all_metrics)))
            text(ax3a, 0.5, 0.5, 'No feasible disturbance data', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center');
            return;
        end

        overall_index = all_metrics(:,1) .* (1 + 0.7 * all_metrics(:,3)) .* ...
                        (1 + 0.3 * (all_metrics(:,2) ./ max(all_metrics(:,2) + eps)));

        bar(ax3b, overall_index);
        set(ax3b, 'XTick', 1:nShapes, 'XTickLabel', shape_names);
        ylabel(ax3b, 'Overall 3D disturbance index [-]');
        title(ax3b, sprintf('Shape comparison at %.1f g', mass_vec(massIdx)*1000));
        grid(ax3b, 'on');

        selected = all_metrics(shapeIdx, :);
        norm_selected = selected;
        norm_selected(1) = selected(1) / max(all_metrics(:,1) + eps);
        norm_selected(2) = selected(2) / max(all_metrics(:,2) + eps);
        norm_selected(3) = selected(3) / max(all_metrics(:,3) + eps);
        norm_selected(4) = selected(4) / max(all_metrics(:,4) + eps);

        bar(ax3c, norm_selected);
        set(ax3c, 'XTick', 1:4, 'XTickLabel', {'Mean', 'Worst', 'Aniso.', 'Stability'});
        ylabel(ax3c, 'Normalised metric [-]');
        title(ax3c, 'Selected shape metric profile');
        grid(ax3c, 'on');

        info_lines = {
            sprintf('Selected mass: %.1f g', mass_vec(massIdx)*1000)
            sprintf('Selected shape: %s', shapes(shapeIdx).name)
            ' '
            'Summary values:'
            sprintf('Mean response: %.4f', all_metrics(shapeIdx,1))
            sprintf('Worst-case response: %.4f', all_metrics(shapeIdx,2))
            sprintf('Anisotropy: %.4f', all_metrics(shapeIdx,3))
            sprintf('3D stability score: %.4f', all_metrics(shapeIdx,4))
            ' '
            'How to read this:'
            'Mean response = average 3D disturbance exposure'
            'Worst-case = most exposed direction'
            'Anisotropy = how uneven the 3D response is'
            'Stability score = higher means more uniform in all directions'
            ' '
            'Recommended interpretation:'
            'Prefer lower mean and worst-case response.'
            'Prefer lower anisotropy if you want predictable behaviour.'
            ' '
            'This is a 3D geometric proxy model.'
            'It is much stronger than X/Y/Z bars, but still not CFD.'
        };
        set(infoBox3, 'String', info_lines);
    end

end

%% ------------------------------------------------------------------------
% LOCAL FUNCTIONS
% -------------------------------------------------------------------------

function F_b = buoyant_force(V, rho_air, rho_helium, g)
F_b = (rho_air - rho_helium) * g * V;
end

function [L, W, H] = shape_dimensions_from_volume(V, aspect, shapeName)
if nargin < 3
    shapeName = '';
end

a = aspect(1);
b = aspect(2);
c = aspect(3);

if strcmpi(shapeName, 'cuboid')
    % Cuboid volume model: V = L*W*H with preserved aspect ratios.
    k = (V / (a * b * c))^(1/3);
else
    % Ellipsoid/sphere volume model: V = (pi/6)*L*W*H with preserved aspect ratios.
    k = ((6 * V) / (pi * a * b * c))^(1/3);
end

L = k * a;
W = k * b;
H = k * c;
end

function arr_norm = normalise_01(arr)
mn = min(arr(:));
mx = max(arr(:));

if abs(mx - mn) < 1e-12
    arr_norm = zeros(size(arr));
else
    arr_norm = (arr - mn) ./ (mx - mn);
end
end

function arr_norm = normalise_01_ignore_nan(arr)
arr_norm = NaN(size(arr));
valid = ~isnan(arr);

if ~any(valid)
    return;
end

vals = arr(valid);
mn = min(vals);
mx = max(vals);

if abs(mx - mn) < 1e-12
    arr_norm(valid) = 0;
else
    arr_norm(valid) = (vals - mn) ./ (mx - mn);
end
end

function endurance = endurance_from_buoyancy_ratio(br)
thrust_fraction = max(1 - br, 1e-8);
endurance = 1 / max(thrust_fraction^(3/2), 1e-8);
end

function [p_value, mean_diff] = permutation_pvalue_mean_diff(x, y, n_perm)
if nargin < 3
    n_perm = 3000;
end

x = x(:);
y = y(:);

mean_diff = mean(x) - mean(y);
pooled = [x; y];
n_x = numel(x);
n_total = numel(pooled);

if n_x == 0 || n_total == n_x
    p_value = NaN;
    return;
end

count_extreme = 0;
for k = 1:n_perm
    idx = randperm(n_total);
    x_perm = pooled(idx(1:n_x));
    y_perm = pooled(idx(n_x+1:end));
    diff_perm = mean(x_perm) - mean(y_perm);
    if abs(diff_perm) >= abs(mean_diff)
        count_extreme = count_extreme + 1;
    end
end

p_value = (count_extreme + 1) / (n_perm + 1);
end

function plot_shape_on_axes(ax, shapeName, dims)
if strcmpi(shapeName, 'cuboid')
    draw_cuboid_on_axes(ax, dims, 0.95);
else
    [X, Y, Z] = shape_surface_from_dims(shapeName, dims, 50);
    surf(ax, X, Y, Z, 'EdgeColor', 'none', 'FaceAlpha', 0.95);
end

axis(ax, 'equal');
xlabel(ax, 'X [m]');
ylabel(ax, 'Y [m]');
zlabel(ax, 'Z [m]');
title(ax, ['3D envelope view: ' shapeName]);
grid(ax, 'on');
view(ax, 3);
set_square_axes_with_padding(ax, max(dims) / 2, 1.22);
camlight(ax, 'headlight');
lighting(ax, 'gouraud');
end

function [X, Y, Z] = shape_surface_from_dims(shapeName, dims, n)
L = dims(1);
W = dims(2);
H = dims(3);

switch lower(shapeName)
    case 'sphere'
        r = L/2;
        [Xs, Ys, Zs] = sphere(n);
        X = r * Xs;
        Y = r * Ys;
        Z = r * Zs;

    case {'prolate ellipsoid', 'flattened ellipsoid'}
        a = L/2;
        b = W/2;
        c = H/2;
        [Xs, Ys, Zs] = sphere(n);
        X = a * Xs;
        Y = b * Ys;
        Z = c * Zs;

    otherwise
        error('Unknown shape type.');
end
end

function S = surface_area_from_volume(V, aspect, shapeName)
[L, W, H] = shape_dimensions_from_volume(V, aspect, shapeName);

switch lower(shapeName)
    case 'sphere'
        r = L/2;
        S = 4 * pi * r^2;

    case {'prolate ellipsoid', 'flattened ellipsoid'}
        p = 1.6075;
        S = 4 * pi * (((L/2)^p * (W/2)^p + (L/2)^p * (H/2)^p + (W/2)^p * (H/2)^p)/3)^(1/p);

    case 'cuboid'
        S = 2 * (L*W + L*H + W*H);

    otherwise
        S = NaN;
end
end

function iq = isoperimetric_quotient(V, S)
iq = (36 * pi * V^2) / max(S^3, eps);
end

function [Xresp, Yresp, Zresp, response_map, metrics] = disturbance_surface_metrics_3d(dims, cd_xyz, shapeName, nAz, nEl)
if nargin < 3
    shapeName = '';
end

az = linspace(0, 2*pi, nAz);
el = linspace(-pi/2, pi/2, nEl);
[AZ, EL] = meshgrid(az, el);

nx = cos(EL) .* cos(AZ);
ny = cos(EL) .* sin(AZ);
nz = sin(EL);

if strcmpi(shapeName, 'cuboid')
    Aproj = cuboid_projected_area(dims, nx, ny, nz);
else
    a = dims(1) / 2;
    b = dims(2) / 2;
    c = dims(3) / 2;
    Aproj = ellipsoid_projected_area(a, b, c, nx, ny, nz);
end
Cd_dir = directional_cd_from_axes(cd_xyz, nx, ny, nz);

response_map = Aproj .* Cd_dir;

response_norm = response_map ./ max(response_map(:) + eps);
radial_scale = 0.35 + 0.85 * response_norm;

Xresp = radial_scale .* nx;
Yresp = radial_scale .* ny;
Zresp = radial_scale .* nz;

mean_response = mean(response_map(:));
worst_response = max(response_map(:));
anisotropy = std(response_map(:)) / max(mean_response, eps);
stability_score = 1 / (1 + anisotropy);

metrics.mean_response = mean_response;
metrics.worst_response = worst_response;
metrics.anisotropy = anisotropy;
metrics.stability_score = stability_score;
end

function Aproj = ellipsoid_projected_area(a, b, c, nx, ny, nz)
denom = sqrt((a .* nx).^2 + (b .* ny).^2 + (c .* nz).^2);
Aproj = pi * a * b * c ./ max(denom, eps);
end

function Aproj = cuboid_projected_area(dims, nx, ny, nz)
L = dims(1);
W = dims(2);
H = dims(3);
Aproj = abs(nx) * (W * H) + abs(ny) * (L * H) + abs(nz) * (L * W);
end

function draw_cuboid_on_axes(ax, dims, faceAlpha, faceColor)
[X, Y, Z] = rounded_cuboid_surface_from_dims(dims, 96, 64, 0.50);

if nargin < 4 || isempty(faceColor)
    surf(ax, X, Y, Z, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', faceAlpha);
else
    surf(ax, X, Y, Z, ...
        'EdgeColor', 'none', ...
        'FaceColor', faceColor, ...
        'FaceAlpha', faceAlpha);
end
end

function [X, Y, Z] = rounded_cuboid_surface_from_dims(dims, nAz, nEl, roundness)
L = dims(1);
W = dims(2);
H = dims(3);

if nargin < 2
    nAz = 64;
end
if nargin < 3
    nEl = 40;
end
if nargin < 4
    roundness = 0.38;
end

eta = linspace(-pi/2, pi/2, nEl);
omega = linspace(-pi, pi, nAz);
[OMEGA, ETA] = meshgrid(omega, eta);

cx = sign(cos(ETA)) .* abs(cos(ETA)).^roundness;
X = (L/2) .* cx .* sign(cos(OMEGA)) .* abs(cos(OMEGA)).^roundness;
Y = (W/2) .* cx .* sign(sin(OMEGA)) .* abs(sin(OMEGA)).^roundness;
Z = (H/2) .* sign(sin(ETA)) .* abs(sin(ETA)).^roundness;
end

function set_square_axes_with_padding(ax, baseHalfSpan, padFactor)
if nargin < 3
    padFactor = 1.20;
end
halfSpan = max(baseHalfSpan, eps) * padFactor;
axis(ax, 'equal');
pbaspect(ax, [1 1 1]);
xlim(ax, [-halfSpan, halfSpan]);
ylim(ax, [-halfSpan, halfSpan]);
zlim(ax, [-halfSpan, halfSpan]);
end

function Cd_dir = directional_cd_from_axes(cd_xyz, nx, ny, nz)
wx = abs(nx);
wy = abs(ny);
wz = abs(nz);
wsum = wx + wy + wz + eps;
Cd_dir = (cd_xyz(1) * wx + cd_xyz(2) * wy + cd_xyz(3) * wz) ./ wsum;
end

function output_dir = matlab_results_dir()
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(fileparts(script_path)));
output_dir = fullfile(project_root, 'results', 'matlab_analysis');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
end

function safe_writetable(tbl, output_path)
output_folder = fileparts(output_path);
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end
writetable(tbl, output_path);
fprintf('Saved table: %s\n', output_path);
end

function p_text = format_p_value(p_value)
if isnan(p_value)
    p_text = 'NaN';
elseif p_value < 1e-3
    p_text = sprintf('%.2e', p_value);
else
    p_text = sprintf('%.4f', p_value);
end
end

function safe_exportgraphics(fig_handle, output_path)
output_folder = fileparts(output_path);
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end
try
    exportgraphics(fig_handle, output_path, 'Resolution', 200);
catch err
    if isgraphics(fig_handle, 'figure') && contains(err.message, 'more than one container')
        try
            exportapp(fig_handle, output_path);
        catch
            warning('safe_exportgraphics:skipExport', ...
                'Skipping figure export for %s due to UI-container limitations.', output_path);
            return;
        end
    elseif isgraphics(fig_handle, 'figure') && contains(err.message, 'UI components are not supported')
        try
            exportapp(fig_handle, output_path);
        catch
            warning('safe_exportgraphics:skipExport', ...
                'Skipping figure export for %s due to UI-component limitations.', output_path);
            return;
        end
    else
        rethrow(err);
    end
end
fprintf('Saved figure: %s\n', output_path);
end
