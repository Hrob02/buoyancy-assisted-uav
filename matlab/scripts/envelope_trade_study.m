function envelope_trade_study
% ENVELOPE_TRADE_STUDY
% Comparative helium-assisted UAV envelope study.
% This tool compares:
% 1. Required helium volume vs system mass
% 2. Endurance improvement vs system mass
% 3. 3-axis disturbance sensitivity
% 4. Overall design score
% 5. 3D visualisation of envelope shapes
%
% This is a comparative design screening tool, not CFD.

clc;
close all;

fprintf('=== Buoyancy-Assisted UAV Envelope Trade Study ===\n');

%% ------------------------------------------------------------------------
% USER SETTINGS
% -------------------------------------------------------------------------

g = 9.81;                  % [m/s^2]
rho_air = 1.225;           % [kg/m^3]
rho_helium = 0.164;        % [kg/m^3]

% Crazyflie-based mass range [kg]
mass_vec = linspace(0.029, 0.040, 8);   % 29 g to 40 g
% Default mass value (grams)
user_mass_g = 35; % Default value, can be changed by user
user_mass = user_mass_g / 1000; % [kg]

% Volume sweep [m^3]
volume_vec = linspace(0.001, 0.100, 200);   % 1 L to 100 L

% Target buoyancy ratio for "required helium volume"
target_buoyancy_ratio = 0.99; % Default, can be changed by user

% Crazyflie baseline comparison
baseline_flight_time_min = 7;

% Shape definitions
shapes = [
    struct('name','Sphere', ...
           'aspect',[1.0 1.0 1.0], ...
           'cd_xyz',[0.90 0.90 0.90], ...
           'packing_efficiency',1.00, ...
           'structure_penalty',0.0020), ...

    struct('name','Prolate Ellipsoid', ...
           'aspect',[1.8 1.0 1.0], ...
           'cd_xyz',[0.65 0.95 0.95], ...
           'packing_efficiency',0.97, ...
           'structure_penalty',0.0025), ...

    struct('name','Cigar', ...
           'aspect',[2.6 0.85 0.85], ...
           'cd_xyz',[0.55 1.05 1.05], ...
           'packing_efficiency',0.94, ...
           'structure_penalty',0.0030), ...

    struct('name','Flattened Ellipsoid', ...
           'aspect',[1.6 1.3 0.7], ...
           'cd_xyz',[0.82 0.92 1.08], ...
           'packing_efficiency',0.93, ...
           'structure_penalty',0.0028) ...
];

nShapes = numel(shapes);
nMass   = numel(mass_vec);
nVol    = numel(volume_vec);

shape_names = cell(1, nShapes);
for s = 1:nShapes
    shape_names{s} = shapes(s).name;
end

%% ------------------------------------------------------------------------
% PREALLOCATE
% -------------------------------------------------------------------------

buoyancy_ratio      = zeros(nMass, nVol, nShapes);
endurance_factor    = zeros(nMass, nVol, nShapes);
disturb_x           = zeros(nMass, nVol, nShapes);
disturb_y           = zeros(nMass, nVol, nShapes);
disturb_z           = zeros(nMass, nVol, nShapes);
disturb_total       = zeros(nMass, nVol, nShapes);
score_raw           = NaN(nMass, nVol, nShapes);
surf_area_ratio     = zeros(nMass, nVol, nShapes); % Surface area/volume ratio

required_volume_for_target = NaN(nMass, nShapes);
best_volume                = NaN(nMass, nShapes);
best_endurance             = NaN(nMass, nShapes);
best_score                 = NaN(nMass, nShapes);
best_disturb_x             = NaN(nMass, nShapes);
best_disturb_y             = NaN(nMass, nShapes);
best_disturb_z             = NaN(nMass, nShapes);

%% ------------------------------------------------------------------------
% MAIN PARAMETER SWEEP
% -------------------------------------------------------------------------

for s = 1:nShapes
    for i = 1:nMass
        for j = 1:nVol

            m_total = mass_vec(i) + shapes(s).structure_penalty;
            W_total = m_total * g;

            V_eff = volume_vec(j) * shapes(s).packing_efficiency;

            F_b = buoyant_force(V_eff, rho_air, rho_helium, g);

            br = F_b / W_total;
            buoyancy_ratio(i,j,s) = br;

            F_res = max(W_total - F_b, 0);
            power_ratio = (max(F_res, 1e-8) / W_total)^(3/2);
            endurance_factor(i,j,s) = 1 / max(power_ratio, 1e-8);

            [L, Wd, H] = shape_dimensions_from_volume(volume_vec(j), shapes(s).aspect);

            % Projected areas for directional external influence
            A_yz = Wd * H;   % disturbance along X
            A_xz = L * H;    % disturbance along Y
            A_xy = L * Wd;   % disturbance along Z

            over_buoyant_penalty = max(br - 1.0, 0);

            dx = shapes(s).cd_xyz(1) * A_yz * (1 + 0.5 * over_buoyant_penalty);
            dy = shapes(s).cd_xyz(2) * A_xz * (1 + 0.5 * over_buoyant_penalty);
            dz = shapes(s).cd_xyz(3) * A_xy * (1 + 0.5 * over_buoyant_penalty);

            disturb_x(i,j,s) = dx;
            disturb_y(i,j,s) = dy;
            disturb_z(i,j,s) = dz;
            disturb_total(i,j,s) = dx + dy + dz;
                % Surface area/volume ratio
                S = surface_area_from_volume(volume_vec(j), shapes(s).aspect, shapes(s).name);
                surf_area_ratio(i,j,s) = S / volume_vec(j);
        end
    end
end

%% ------------------------------------------------------------------------
% SCORE CALCULATION
% -------------------------------------------------------------------------

buoy_norm = normalise_01(buoyancy_ratio);
endu_norm = normalise_01(endurance_factor);
dist_norm = normalise_01(disturb_total);
max_struct_pen = max([shapes.structure_penalty]);
surf_area_ratio_norm = normalise_01(surf_area_ratio);

for s = 1:nShapes
    struct_pen_norm = shapes(s).structure_penalty / max_struct_pen;

    for i = 1:nMass
        for j = 1:nVol
            br = buoyancy_ratio(i,j,s);
            feasible = (br >= 0.55) && (br <= 1.10);

            if feasible
                score_raw(i,j,s) = ...
                0.30 * buoy_norm(i,j,s) + ...
                0.35 * endu_norm(i,j,s) - ...
                0.20 * dist_norm(i,j,s) - ...
                0.10 * surf_area_ratio_norm(i,j,s) - ...
                0.05 * struct_pen_norm;
            end
        end
    end
end

%% ------------------------------------------------------------------------
% REQUIRED VOLUME FOR TARGET BUOYANCY RATIO
% -------------------------------------------------------------------------

for s = 1:nShapes
    for i = 1:nMass
        idx = find(squeeze(buoyancy_ratio(i,:,s)) >= target_buoyancy_ratio, 1, 'first');
        if ~isempty(idx)
            required_volume_for_target(i,s) = volume_vec(idx);
        end
    end
end

%% ------------------------------------------------------------------------
% BEST DESIGN PER MASS AND SHAPE
% -------------------------------------------------------------------------

for s = 1:nShapes
    for i = 1:nMass
        row_scores = squeeze(score_raw(i,:,s));
        [mx, idx_best] = max(row_scores);

        if ~isempty(idx_best) && isfinite(mx)
            best_volume(i,s)    = volume_vec(idx_best);
            best_endurance(i,s) = endurance_factor(i,idx_best,s);
            best_score(i,s)     = score_raw(i,idx_best,s);
            best_disturb_x(i,s) = disturb_x(i,idx_best,s);
            best_disturb_y(i,s) = disturb_y(i,idx_best,s);
            best_disturb_z(i,s) = disturb_z(i,idx_best,s);
        end
    end
end

%% ------------------------------------------------------------------------
% STATS DATA
% -------------------------------------------------------------------------

score_values = [];
shape_labels = {};

for s = 1:nShapes
    vals = best_score(:,s);
    vals = vals(~isnan(vals));
    score_values = [score_values; vals(:)]; %#ok<AGROW>
    shape_labels = [shape_labels; repmat({shapes(s).name}, numel(vals), 1)]; %#ok<AGROW>
end

anova_text = 'ANOVA not run.';
anova_p = NaN;
anova_stats = [];

try
    [anova_p, ~, anova_stats] = anova1(score_values, shape_labels, 'off');
    if anova_p < 0.05
        anova_text = sprintf('One-way ANOVA found a statistically significant difference between shapes (p = %.4f).', anova_p);
    else
        anova_text = sprintf('One-way ANOVA did not find a statistically significant difference between shapes (p = %.4f).', anova_p);
    end
catch
    anova_text = 'ANOVA could not be completed. This may require the Statistics Toolbox.';
end

%% ------------------------------------------------------------------------
% COMMAND WINDOW SUMMARY
% -------------------------------------------------------------------------

fprintf('\n=== Best design summary ===\n');
fprintf('%-22s %-10s %-15s %-15s %-15s\n', ...
    'Shape', 'Mass [g]', 'Best Vol [L]', 'Endurance x', 'Score');

for s = 1:nShapes
    for i = 1:nMass
        if ~isnan(best_volume(i,s))
            fprintf('%-22s %-10.1f %-15.2f %-15.2f %-15.3f\n', ...
                shapes(s).name, ...
                mass_vec(i)*1000, ...
                best_volume(i,s)*1000, ...
                best_endurance(i,s), ...
                best_score(i,s));
        end
    end
end

fprintf('\n%s\n', anova_text);

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
tab4 = uitab(tg, 'Title', 'Score + Statistics');

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
    'Value', 1);

uicontrol('Parent', tab1, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.31 0.93 0.12 0.04], ...
    'String', 'Reference mass [g]', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'w');

mass_strings = cellstr(num2str((mass_vec(:)*1000), '%.1f'));


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
    'Position', [0.56 0.935 0.10 0.04], ...
    'String', 'Update', ...
    'Callback', @config_input_callback);

infoBox = uicontrol('Parent', tab1, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.58 0.18 0.35 0.66], ...
    'FontName', 'Courier New', ...
    'FontSize', 10, ...
    'Max', 2, 'Min', 0);



% Now that all axes and UI controls are created, define the update functions


%% ------------------------------------------------------------------------
% TAB 2: ENDURANCE
% -------------------------------------------------------------------------

ax2a = axes('Parent', tab2, 'Units', 'normalized', 'Position', [0.07 0.55 0.58 0.35]);
hold(ax2a, 'on');
for s = 1:nShapes
    plot(ax2a, mass_vec*1000, best_endurance(:,s), ...
        'LineWidth', 2, 'DisplayName', shapes(s).name);
end
hold(ax2a, 'off');
xlabel(ax2a, 'System mass [g]');
ylabel(ax2a, 'Best relative endurance factor [-]');
title(ax2a, 'Best predicted endurance improvement versus system mass');
legend(ax2a, 'Location', 'northwest');
grid(ax2a, 'on');

ax2b = axes('Parent', tab2, 'Units', 'normalized', 'Position', [0.07 0.12 0.58 0.28]);
refMassIdx = ceil(nMass/2);
bar(ax2b, 1:nShapes, baseline_flight_time_min * best_endurance(refMassIdx,:));
set(ax2b, 'XTick', 1:nShapes, 'XTickLabel', shape_names);
ylabel(ax2b, 'Estimated endurance [min]');
title(ax2b, sprintf('Estimated endurance at %.1f g reference mass', mass_vec(refMassIdx)*1000));
grid(ax2b, 'on');

annotation_text_tab2 = {
    'Interpretation:'
    ' '
    'Each line shows the best endurance gain obtained for each shape'
    'after balancing lift assistance against disturbance penalty.'
    ' '
    'The lower plot converts endurance factor into estimated'
    'flight time using the 7 minute Crazyflie baseline.'
    ' '
    'These are comparative estimates only.'
};

uicontrol('Parent', tab2, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.70 0.20 0.25 0.55], ...
    'String', annotation_text_tab2, ...
    'FontSize', 10, ...
    'BackgroundColor', 'w', ...
    'Max', 2, 'Min', 0);

%% ------------------------------------------------------------------------
% TAB 3: DISTURBANCE
% -------------------------------------------------------------------------

uicontrol('Parent', tab3, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.07 0.93 0.12 0.04], ...
    'String', 'Reference mass [g]', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'w');

popupDistMass = uicontrol('Parent', tab3, 'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [0.20 0.935 0.10 0.04], ...
    'String', mass_strings, ...
    'Value', ceil(nMass/2), ...
    'Callback', @update_disturbance_plot);

ax3a = axes('Parent', tab3, 'Units', 'normalized', 'Position', [0.07 0.14 0.60 0.72]);

uicontrol('Parent', tab3, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.72 0.18 0.23 0.62], ...
    'String', {
        'Interpretation:'
        ' '
        'The grouped bars compare directional sensitivity in X, Y, and Z.'
        ' '
        'X sensitivity is linked to projected YZ area.'
        'Y sensitivity is linked to projected XZ area.'
        'Z sensitivity is linked to projected XY area.'
        ' '
        'This is a simplified directional proxy model.'
        'It is not a CFD solution.'
        ' '
        'It compares how envelope geometry may respond differently'
        'to external effects in all 3 dimensions.'
    }, ...
    'FontSize', 10, ...
    'BackgroundColor', 'w', ...
    'Max', 2, 'Min', 0);


update_disturbance_plot();

% Now that all axes and UI controls are created, call update_all_tabs
update_all_tabs();

%% ------------------------------------------------------------------------
% TAB 4: SCORE + STATISTICS
% -------------------------------------------------------------------------

ax4a = axes('Parent', tab4, 'Units', 'normalized', 'Position', [0.07 0.16 0.40 0.68]);
boxplot(ax4a, score_values, shape_labels);
ylabel(ax4a, 'Overall design score [-]');
title(ax4a, 'Overall score distribution by shape');
grid(ax4a, 'on');

ax4b = axes('Parent', tab4, 'Units', 'normalized', 'Position', [0.56 0.55 0.32 0.28]);
mean_scores = zeros(1, nShapes);
std_scores  = zeros(1, nShapes);

for s = 1:nShapes
    vals = best_score(:,s);
    vals = vals(~isnan(vals));
    mean_scores(s) = mean(vals);
    std_scores(s)  = std(vals);
end

bar(ax4b, 1:nShapes, mean_scores);
set(ax4b, 'XTick', 1:nShapes, 'XTickLabel', shape_names);
ylabel(ax4b, 'Mean score [-]');
title(ax4b, 'Mean overall score by shape');
grid(ax4b, 'on');

stats_lines = [{'Statistical summary:'}; {' '}; {anova_text}; {' '}; {'Mean and standard deviation:'}];
for s = 1:nShapes
    stats_lines{end+1,1} = sprintf('%s: mean = %.4f, std = %.4f', ...
        shape_names{s}, mean_scores(s), std_scores(s)); %#ok<SAGROW>
end

uicontrol('Parent', tab4, 'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.56 0.16 0.36 0.28], ...
    'String', stats_lines, ...
    'FontSize', 10, ...
    'BackgroundColor', 'w', ...
    'Max', 2, 'Min', 0);

if ~isempty(anova_stats) && ~isnan(anova_p) && anova_p < 0.05
    uicontrol('Parent', tab4, 'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.07 0.90 0.16 0.05], ...
        'String', 'Open Post-hoc Comparison', ...
        'Callback', @open_posthoc);
end

%% ------------------------------------------------------------------------
% NESTED CALLBACKS
% -------------------------------------------------------------------------


    function update_all_tabs(~, ~)
        % Get user mass and buoyancy ratio from input boxes
        massInputBox = findobj(fig, 'Tag', 'massInputBox');
        buoyancyInputBox = findobj(fig, 'Tag', 'buoyancyInputBox');
        user_mass_g = str2double(get(massInputBox, 'String'));
        if isnan(user_mass_g) || user_mass_g <= 0
            user_mass_g = 35;
        end
        user_mass = user_mass_g / 1000;
        target_buoyancy_ratio = str2double(get(buoyancyInputBox, 'String'));
        if isnan(target_buoyancy_ratio) || target_buoyancy_ratio <= 0
            target_buoyancy_ratio = 0.99;
        end

        % Recompute all metrics for this mass and buoyancy ratio only
        m_total = user_mass + [shapes.structure_penalty];
        W_total = m_total * g;
        V_eff = volume_vec' * [shapes.packing_efficiency]; % [nVol x nShapes]
        F_b = (rho_air - rho_helium) * g * V_eff; % [nVol x nShapes]
        br = F_b ./ W_total; % [nVol x nShapes]

        F_res = max(W_total - F_b, 0);
        power_ratio = (max(F_res, 1e-8) ./ W_total).^(3/2);
        endurance_factor = 1 ./ max(power_ratio, 1e-8);

        % Find required volume for target buoyancy ratio
        required_volume_for_target = NaN(1, nShapes);
        for s = 1:nShapes
            idx = find(br(:,s) >= target_buoyancy_ratio, 1, 'first');
            if ~isempty(idx)
                required_volume_for_target(s) = volume_vec(idx);
            end
        end

        % Find best design for this mass
        score_raw = NaN(nVol, nShapes);
        disturb_x = zeros(nVol, nShapes);
        disturb_y = zeros(nVol, nShapes);
        disturb_z = zeros(nVol, nShapes);
        disturb_total = zeros(nVol, nShapes);
        for s = 1:nShapes
            struct_pen_norm = shapes(s).structure_penalty / max([shapes.structure_penalty]);
            for j = 1:nVol
                [L, Wd, H] = shape_dimensions_from_volume(volume_vec(j), shapes(s).aspect);
                A_yz = Wd * H;
                A_xz = L * H;
                A_xy = L * Wd;
                S = surface_area_from_volume(volume_vec(j), shapes(s).aspect, shapes(s).name);
                ratio = S / volume_vec(j);
                over_buoyant_penalty = max(br(j,s) - 1.0, 0);
                dx = shapes(s).cd_xyz(1) * A_yz * (1 + 0.5 * over_buoyant_penalty);
                dy = shapes(s).cd_xyz(2) * A_xz * (1 + 0.5 * over_buoyant_penalty);
                dz = shapes(s).cd_xyz(3) * A_xy * (1 + 0.5 * over_buoyant_penalty);
                disturb_x(j,s) = dx;
                disturb_y(j,s) = dy;
                disturb_z(j,s) = dz;
                disturb_total(j,s) = dx + dy + dz;
            end
            % Normalise for scoring
            buoy_norm = (br(:,s) - min(br(:,s))) / max(1e-12, max(br(:,s)) - min(br(:,s)));
            endu_norm = (endurance_factor(:,s) - min(endurance_factor(:,s))) / max(1e-12, max(endurance_factor(:,s)) - min(endurance_factor(:,s)));
            dist_norm = (disturb_total(:,s) - min(disturb_total(:,s))) / max(1e-12, max(disturb_total(:,s)) - min(disturb_total(:,s)));
            for j = 1:nVol
                feasible = (br(j,s) >= 0.55) && (br(j,s) <= 1.10);
                if feasible
                    score_raw(j,s) = 0.35 * buoy_norm(j) + 0.40 * endu_norm(j) - 0.20 * dist_norm(j) - 0.05 * struct_pen_norm;
                end
            end
        end
        [mx, idx_best] = max(score_raw, [], 1);
        best_volume = volume_vec(idx_best);
        best_endurance = endurance_factor(idx_best + (0:nShapes-1)*nVol);
        best_score = score_raw(idx_best + (0:nShapes-1)*nVol);
        best_disturb_x = disturb_x(idx_best + (0:nShapes-1)*nVol);
        best_disturb_y = disturb_y(idx_best + (0:nShapes-1)*nVol);
        best_disturb_z = disturb_z(idx_best + (0:nShapes-1)*nVol);

        % --- Update 3D Shape Viewer (Tab 1) ---
        cla(ax1);
        shapeIdx = get(popupShape, 'Value');
        V_req = required_volume_for_target(shapeIdx);
        if isnan(V_req)
            max_vol_L = max(volume_vec) * 1000;
            title(ax1, 'No feasible design found');
            set(infoBox, 'String', {['No feasible design found for this mass and buoyancy ratio.'];
                ['Not feasible within the current envelope size constraint (max = ' num2str(max_vol_L, '%.1f') ' L).']});
        else
            [L, Wd, H] = shape_dimensions_from_volume(V_req, shapes(shapeIdx).aspect);
            S = surface_area_from_volume(V_req, shapes(shapeIdx).aspect, shapes(shapeIdx).name);
            ratio = S / V_req;
            plot_shape_on_axes(ax1, shapes(shapeIdx).name, [L Wd H]);
            info_lines = {
                sprintf('Selected shape: %s', shapes(shapeIdx).name)
                sprintf('Reference mass: %.1f g', user_mass_g)
                sprintf('Target buoyancy ratio: %.2f', target_buoyancy_ratio)
                sprintf('Required envelope volume: %.2f L', V_req*1000)
                ' '
                'Estimated dimensions:'
                sprintf('  Length = %.3f m', L)
                sprintf('  Width  = %.3f m', Wd)
                sprintf('  Height = %.3f m', H)
                ' '
                'Shape characteristics:'
                sprintf('Surface area per unit volume: %.4f m^2', S)
                sprintf('Surface area / volume: %.2f 1/m', ratio)
            };
            set(infoBox, 'String', info_lines);
        end

        % --- Update Endurance (Tab 2) ---
        cla(ax2a);
        hold(ax2a, 'on');
        for s = 1:nShapes
            plot(ax2a, user_mass_g, best_endurance(s), 'o', 'LineWidth', 2, 'DisplayName', shapes(s).name);
        end
        hold(ax2a, 'off');
        xlabel(ax2a, 'System mass [g]');
        ylabel(ax2a, 'Best relative endurance factor [-]');
        title(ax2a, 'Best predicted endurance improvement versus system mass');
        legend(ax2a, 'Location', 'northwest');
        grid(ax2a, 'on');

        cla(ax2b);
        bar(ax2b, 1:nShapes, baseline_flight_time_min * best_endurance);
        set(ax2b, 'XTick', 1:nShapes, 'XTickLabel', shape_names);
        ylabel(ax2b, 'Estimated endurance [min]');
        title(ax2b, sprintf('Estimated endurance at %.1f g reference mass', user_mass_g));
        grid(ax2b, 'on');

        % --- Update Disturbance (Tab 3) ---
        cla(ax3a);
        D = [best_disturb_x(:)'; best_disturb_y(:)'; best_disturb_z(:)']';
        bar(ax3a, D, 'grouped');
        set(ax3a, 'XTick', 1:nShapes, 'XTickLabel', shape_names);
        ylabel(ax3a, 'Directional disturbance sensitivity [-]');
        title(ax3a, sprintf('3-axis disturbance comparison at %.1f g', user_mass_g));
        legend(ax3a, {'X direction', 'Y direction', 'Z direction'}, 'Location', 'northwest');
        grid(ax3a, 'on');
    end

    function config_input_callback(src, ~)
        update_all_tabs();
    end

    function update_disturbance_plot(~, ~)
        cla(ax3a);

        massIdx = get(popupDistMass, 'Value');

        D = [
            best_disturb_x(massIdx, :);
            best_disturb_y(massIdx, :);
            best_disturb_z(massIdx, :)
        ]';

        bar(ax3a, D, 'grouped');
        set(ax3a, 'XTick', 1:nShapes, 'XTickLabel', shape_names);
        ylabel(ax3a, 'Directional disturbance sensitivity [-]');
        title(ax3a, sprintf('3-axis disturbance comparison at %.1f g', mass_vec(massIdx)*1000));
        legend(ax3a, {'X direction', 'Y direction', 'Z direction'}, 'Location', 'northwest');
        grid(ax3a, 'on');
    end

    function open_posthoc(~, ~)
        figure('Name', 'Post-hoc Multiple Comparison', 'Color', 'w');
        multcompare(anova_stats);
    end
end

%% ------------------------------------------------------------------------
% LOCAL FUNCTIONS
% -------------------------------------------------------------------------

function F_b = buoyant_force(V, rho_air, rho_helium, g)
F_b = (rho_air - rho_helium) * g * V;
end

function [L, W, H] = shape_dimensions_from_volume(V, aspect)
a = aspect(1);
b = aspect(2);
c = aspect(3);

k = ((6 * V) / (pi * a * b * c))^(1/3);

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

function plot_shape_on_axes(ax, shapeName, dims)
L = dims(1);
W = dims(2);
H = dims(3);

switch lower(shapeName)
    case 'sphere'
        r = L/2;
        [X,Y,Z] = sphere(50);
        surf(ax, r*X, r*Y, r*Z, 'EdgeColor', 'none', 'FaceAlpha', 0.95);

    case 'prolate ellipsoid'
        a = L/2; b = W/2; c = H/2;
        [X,Y,Z] = sphere(50);
        surf(ax, a*X, b*Y, c*Z, 'EdgeColor', 'none', 'FaceAlpha', 0.95);

    case 'flattened ellipsoid'
        a = L/2; b = W/2; c = H/2;
        [X,Y,Z] = sphere(50);
        surf(ax, a*X, b*Y, c*Z, 'EdgeColor', 'none', 'FaceAlpha', 0.95);

    case 'cigar'
        % Use prolate spheroid for classic blimp shape
        a = L/2; b = W/2; c = H/2;
        [X, Y, Z] = sphere(50);
        surf(ax, a*X, b*Y, c*Z, 'EdgeColor', 'none', 'FaceAlpha', 0.95);

    otherwise
        error('Unknown shape type.');
end

axis(ax, 'equal');
xlabel(ax, 'X [m]');
ylabel(ax, 'Y [m]');
zlabel(ax, 'Z [m]');
title(ax, ['3D envelope view: ' shapeName]);
grid(ax, 'on');
view(ax, 3);
camlight(ax, 'headlight');
lighting(ax, 'gouraud');
end

function [X, Y, Z] = capsule_surface(L, r, n)
if L <= 2*r
    [Xs,Ys,Zs] = sphere(n);
    X = r * Xs;
    Y = r * Ys;
    Z = r * Zs;
    return;
end

cylLen = L - 2*r;

theta = linspace(0, 2*pi, n+1);
xCyl = linspace(-cylLen/2, cylLen/2, n+1);
[ThetaCyl, XCyl] = meshgrid(theta, xCyl);
YCyl = r * cos(ThetaCyl);
ZCyl = r * sin(ThetaCyl);

[XS,YS,ZS] = sphere(n);

X_left = r * XS - cylLen/2;
Y_left = r * YS;
Z_left = r * ZS;
left_mask = XS <= 0;

X_right = r * XS + cylLen/2;
Y_right = r * YS;
Z_right = r * ZS;
right_mask = XS >= 0;

X_left(~left_mask) = NaN;
Y_left(~left_mask) = NaN;
Z_left(~left_mask) = NaN;

X_right(~right_mask) = NaN;
Y_right(~right_mask) = NaN;
Z_right(~right_mask) = NaN;

X = [XCyl; X_left; X_right];
Y = [YCyl; Y_left; Y_right];
Z = [ZCyl; Z_left; Z_right];
end

function S = surface_area_from_volume(V, aspect, shapeName)
    a = aspect(1);
    b = aspect(2);
    c = aspect(3);
    k = ((6 * V) / (pi * a * b * c))^(1/3);
    L = k * a;
    W = k * b;
    H = k * c;
    switch lower(shapeName)
        case 'sphere'
            r = L/2;
            S = 4 * pi * r^2;
        case {'prolate ellipsoid', 'flattened ellipsoid', 'cigar'}
            p = 1.6075;
            S = 4 * pi * (((L/2)^p * (W/2)^p + (L/2)^p * (H/2)^p + (W/2)^p * (H/2)^p)/3)^(1/p);
        otherwise
            S = NaN;
    end
end