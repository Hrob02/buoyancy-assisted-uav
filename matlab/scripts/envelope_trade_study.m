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

%% ------------------------------------------------------------------------
% USER SETTINGS
% -------------------------------------------------------------------------

g = 9.81;                  % [m/s^2]
rho_air = 1.225;           % [kg/m^3]
rho_helium = 0.164;        % [kg/m^3]

% Mass range [kg]
mass_vec = linspace(0.001, 0.100, 100);   % 1 g to 100 g

% Default user-selected mass [g]
user_mass_g = 35;
user_mass = user_mass_g / 1000; %#ok<NASGU>

% Volume sweep [m^3]
volume_vec = linspace(0.001, 0.100, 200);   % 1 L to 100 L

% Target buoyancy ratio
target_buoyancy_ratio = 0.99;

% Crazyflie baseline
baseline_mass_g = 28;
baseline_time_min = 7;

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
score_raw           = NaN(nMass, nVol, nShapes);
surf_area_ratio     = zeros(nMass, nVol, nShapes);

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
        end
    end
end

%% ------------------------------------------------------------------------
% SCORE CALCULATION
% -------------------------------------------------------------------------

buoy_norm = normalise_01(buoyancy_ratio);
endu_norm = normalise_01(endurance_factor);
dist_norm = normalise_01(disturb_total);
surf_area_ratio_norm = normalise_01(surf_area_ratio);
max_struct_pen = max([shapes.structure_penalty]);

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
% INITIAL DRAW
% -------------------------------------------------------------------------

update_all_tabs();

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
            m_total = user_mass_local + shapes(s).structure_penalty;
            W_total = m_total * g;

            br_vec = zeros(1, nVol);
            endu_vec = zeros(1, nVol);
            dx_vec = zeros(1, nVol);
            dy_vec = zeros(1, nVol);
            dz_vec = zeros(1, nVol);
            dtotal_vec = zeros(1, nVol);
            sa_ratio_vec = zeros(1, nVol);
            score_vec = NaN(1, nVol);

            for j = 1:nVol
                V_eff = volume_vec(j) * shapes(s).packing_efficiency;
                F_b = buoyant_force(V_eff, rho_air, rho_helium, g);
                br = F_b / W_total;
                br_vec(j) = br;

                F_res = max(W_total - F_b, 0);
                power_ratio = (max(F_res, 1e-8) / W_total)^(3/2);
                endu_vec(j) = 1 / max(power_ratio, 1e-8);

                [L, Wd, H] = shape_dimensions_from_volume(volume_vec(j), shapes(s).aspect);

                A_yz = Wd * H;
                A_xz = L * H;
                A_xy = L * Wd;

                over_buoyant_penalty = max(br - 1.0, 0);

                dx_vec(j) = shapes(s).cd_xyz(1) * A_yz * (1 + 0.5 * over_buoyant_penalty);
                dy_vec(j) = shapes(s).cd_xyz(2) * A_xz * (1 + 0.5 * over_buoyant_penalty);
                dz_vec(j) = shapes(s).cd_xyz(3) * A_xy * (1 + 0.5 * over_buoyant_penalty);
                dtotal_vec(j) = dx_vec(j) + dy_vec(j) + dz_vec(j);

                S = surface_area_from_volume(volume_vec(j), shapes(s).aspect, shapes(s).name);
                sa_ratio_vec(j) = S / volume_vec(j);
            end

            idx_req = find(br_vec >= target_buoyancy_ratio_local, 1, 'first');
            if ~isempty(idx_req)
                local_required_volume(s) = volume_vec(idx_req);
            end

            buoy_norm_local = normalise_01(br_vec);
            endu_norm_local = normalise_01(endu_vec);
            dist_norm_local = normalise_01(dtotal_vec);
            sa_norm_local = normalise_01(sa_ratio_vec);
            struct_pen_norm = shapes(s).structure_penalty / max_struct_pen;

            for j = 1:nVol
                feasible = (br_vec(j) >= 0.55) && (br_vec(j) <= 1.10);
                if feasible
                    score_vec(j) = ...
                        0.30 * buoy_norm_local(j) + ...
                        0.35 * endu_norm_local(j) - ...
                        0.20 * dist_norm_local(j) - ...
                        0.10 * sa_norm_local(j) - ...
                        0.05 * struct_pen_norm;
                end
            end

            [mx, idx_best] = max(score_vec);
            if ~isempty(idx_best) && isfinite(mx)
                best_volume(:,s); %#ok<VUNUS>
                best_volume(round(interp1(mass_vec,1:nMass,user_mass_local,'nearest','extrap')),s) = volume_vec(idx_best);
                best_endurance(round(interp1(mass_vec,1:nMass,user_mass_local,'nearest','extrap')),s) = endu_vec(idx_best);
                best_score(round(interp1(mass_vec,1:nMass,user_mass_local,'nearest','extrap')),s) = score_vec(idx_best);
                best_disturb_x(round(interp1(mass_vec,1:nMass,user_mass_local,'nearest','extrap')),s) = dx_vec(idx_best);
                best_disturb_y(round(interp1(mass_vec,1:nMass,user_mass_local,'nearest','extrap')),s) = dy_vec(idx_best);
                best_disturb_z(round(interp1(mass_vec,1:nMass,user_mass_local,'nearest','extrap')),s) = dz_vec(idx_best);
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
            [L, Wd, H] = shape_dimensions_from_volume(V_req, shapes(shapeIdx).aspect);
            S = surface_area_from_volume(V_req, shapes(shapeIdx).aspect, shapes(shapeIdx).name);
            ratio = S / V_req;

            plot_shape_on_axes(ax1, shapes(shapeIdx).name, [L Wd H]);

            info_lines = {
                sprintf('Selected shape: %s', shapes(shapeIdx).name)
                sprintf('Reference mass: %.1f g', user_mass_g_local)
                sprintf('Target buoyancy ratio: %.2f', target_buoyancy_ratio_local)
                sprintf('Required envelope volume: %.2f L', V_req*1000)
                ' '
                'Estimated dimensions:'
                sprintf('  Length = %.3f m', L)
                sprintf('  Width  = %.3f m', Wd)
                sprintf('  Height = %.3f m', H)
                ' '
                'Shape characteristics:'
                sprintf('Surface area: %.4f m^2', S)
                sprintf('Surface area / volume: %.2f 1/m', ratio)
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

            [L, Wd, H] = shape_dimensions_from_volume(V_here, shapes(s).aspect);
            dims = [L, Wd, H];

            [Xresp, Yresp, Zresp, response_map, metrics] = ...
                disturbance_surface_metrics_3d(dims, shapes(s).cd_xyz, 56, 32);

            all_metrics(s,1) = metrics.mean_response;
            all_metrics(s,2) = metrics.worst_response;
            all_metrics(s,3) = metrics.anisotropy;
            all_metrics(s,4) = metrics.stability_score;

            if s == shapeIdx
                [Xshape, Yshape, Zshape] = shape_surface_from_dims(shapes(s).name, dims, 50);

                char_scale = max(dims) / 2;
                Xenv = char_scale * Xresp;
                Yenv = char_scale * Yresp;
                Zenv = char_scale * Zresp;

                surf(ax3a, Xshape, Yshape, Zshape, ...
                    'EdgeColor', 'none', ...
                    'FaceAlpha', 0.18, ...
                    'FaceColor', [0.7 0.7 0.7]);
                hold(ax3a, 'on');

                surf(ax3a, Xenv, Yenv, Zenv, response_map, ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.92);

                hold(ax3a, 'off');
                axis(ax3a, 'equal');
                grid(ax3a, 'on');
                xlabel(ax3a, 'X [m]');
                ylabel(ax3a, 'Y [m]');
                zlabel(ax3a, 'Z [m]');
                title(ax3a, sprintf('3D disturbance envelope: %s', shapes(s).name));
                view(ax3a, 3);
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
[X, Y, Z] = shape_surface_from_dims(shapeName, dims, 50);

surf(ax, X, Y, Z, 'EdgeColor', 'none', 'FaceAlpha', 0.95);

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

    case {'prolate ellipsoid', 'flattened ellipsoid', 'cigar'}
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

function [Xresp, Yresp, Zresp, response_map, metrics] = disturbance_surface_metrics_3d(dims, cd_xyz, nAz, nEl)
a = dims(1) / 2;
b = dims(2) / 2;
c = dims(3) / 2;

az = linspace(0, 2*pi, nAz);
el = linspace(-pi/2, pi/2, nEl);
[AZ, EL] = meshgrid(az, el);

nx = cos(EL) .* cos(AZ);
ny = cos(EL) .* sin(AZ);
nz = sin(EL);

Aproj = ellipsoid_projected_area(a, b, c, nx, ny, nz);
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

function Cd_dir = directional_cd_from_axes(cd_xyz, nx, ny, nz)
wx = abs(nx);
wy = abs(ny);
wz = abs(nz);
wsum = wx + wy + wz + eps;
Cd_dir = (cd_xyz(1) * wx + cd_xyz(2) * wy + cd_xyz(3) * wz) ./ wsum;
end