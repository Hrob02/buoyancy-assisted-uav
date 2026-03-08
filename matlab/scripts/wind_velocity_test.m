%% WIND_VELOCITY_TEST  3D wind-tunnel style airflow visualization.
%   Shows 3D flow vectors around a simplified drone body and overlays a
%   body-surface heatmap of flow resistance/interference.

run('setup_paths.m');

fprintf('=== Wind Velocity Test ===\n');

x = linspace(-2.0, 2.0, 24);
y = linspace(-1.3, 1.3, 18);
z = linspace(-0.9, 0.9, 14);
[X, Y, Z] = meshgrid(x, y, z);

drone.a = 0.42;
drone.b = 0.16;
drone.c = 0.12;

cases = [
    struct('name', 'Baseline cruise', 'U', 12, 'yaw_deg', 0,  'shape', 1.00, 'component', 0.00, 'helium_ratio', 0.18), ...
    struct('name', 'High wind + payload', 'U', 18, 'yaw_deg', 0, 'shape', 1.10, 'component', 0.25, 'helium_ratio', 0.18), ...
    struct('name', 'Crosswind', 'U', 12, 'yaw_deg', 20, 'shape', 1.00, 'component', 0.05, 'helium_ratio', 0.18), ...
    struct('name', 'Low-weight high-helium', 'U', 10, 'yaw_deg', -10, 'shape', 0.95, 'component', 0.05, 'helium_ratio', 0.28)
];

fig = figure('Name', 'UAV 3D Airflow Tunnel Test', 'Color', 'w');
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
all_streamline_handles = gobjects(0);

for idx = 1:numel(cases)
    c = cases(idx);
    nexttile;
    [Ux, Uy, Uz, ~] = local_wind_field_3d(X, Y, Z, drone, c);

    hold on;
    seed_y = linspace(min(y) * 0.85, max(y) * 0.85, 7);
    seed_z = linspace(min(z) * 0.85, max(z) * 0.85, 5);
    [Sy, Sz] = meshgrid(seed_y, seed_z);
    Sx = min(x) * ones(size(Sy));
    stream_cells = stream3(X, Y, Z, Ux, Uy, Uz, Sx, Sy, Sz);
    h_stream = streamline(stream_cells);
    set(h_stream, 'Color', [0.10, 0.10, 0.10], 'LineWidth', 1.0);
    all_streamline_handles = [all_streamline_handles; h_stream(:)];

    local_draw_drone_heatmap(drone, c);

    axis vis3d;
    axis equal;
    xlim([min(x), max(x)]);
    ylim([min(y), max(y)]);
    zlim([min(z), max(z)]);
    view(35, 24);
    grid on;
    xlabel('x [m]');
    ylabel('y [m]');
    zlabel('z [m]');
    title(sprintf('%s | U=%.1f m/s | yaw=%+d deg', c.name, c.U, c.yaw_deg));
    cb = colorbar;
    cb.Label.String = 'Surface resistance / interference index';
    colormap(turbo);
    caxis([0, 1.8]);
    hold off;
end

sgtitle('3D airflow tunnel view with on-body resistance heatmap');
uicontrol(fig, ...
    'Style', 'checkbox', ...
    'String', 'Show streamlines', ...
    'Value', 1, ...
    'Units', 'normalized', ...
    'Position', [0.79, 0.01, 0.20, 0.04], ...
    'Callback', @(src, ~) local_toggle_streamlines(src, all_streamline_handles));

fprintf('Wind velocity test figure generated.\n');


function [Ux, Uy, Uz, resistance_proxy] = local_wind_field_3d(X, Y, Z, drone, c)
    theta = deg2rad(c.yaw_deg);
    Ux0 = c.U * cos(theta);
    Uy0 = c.U * sin(theta);
    Uz0 = 0;

    a_eff = drone.a * c.shape;
    b_eff = drone.b / c.shape;
    c_eff = drone.c;

    eps_val = 1e-6;
    rx = X / (a_eff + eps_val);
    ry = Y / (b_eff + eps_val);
    rz = Z / (c_eff + eps_val);
    r2 = rx.^2 + ry.^2 + rz.^2 + eps_val;

    blockage = (0.45 + 0.6 * c.component) * exp(-1.6 * r2);
    swirl = (0.10 + 0.30 * c.component + 0.45 * max(c.helium_ratio - 0.18, 0)) * exp(-2.2 * r2);

    Ux = Ux0 .* (1 - blockage) - swirl .* Y;
    Uy = Uy0 .* (1 - blockage) + swirl .* X;
    Uz = Uz0 .* ones(size(Z)) + 0.20 * swirl .* Z;

    speed = sqrt(Ux.^2 + Uy.^2 + Uz.^2);
    resistance_proxy = max((c.U - speed) / max(c.U, 1e-6), 0);
end


function local_draw_drone_heatmap(drone, c)
    a_eff = drone.a * c.shape;
    b_eff = drone.b / c.shape;
    c_eff = drone.c;

    [xs, ys, zs] = ellipsoid(0, 0, 0, a_eff, b_eff, c_eff, 48);

    theta = deg2rad(c.yaw_deg);
    Vhat = [cos(theta), sin(theta), 0];

    nx = xs / a_eff;
    ny = ys / b_eff;
    nz = zs / c_eff;
    n_norm = sqrt(nx.^2 + ny.^2 + nz.^2) + 1e-9;
    nx = nx ./ n_norm;
    ny = ny ./ n_norm;
    nz = nz ./ n_norm;

    head_on = max(-(nx * Vhat(1) + ny * Vhat(2) + nz * Vhat(3)), 0);
    interference = 1.0 + 0.75 * c.component + 0.60 * max(c.helium_ratio - 0.18, 0);
    resistance_idx = interference .* (head_on .^ 1.4);

    surf(xs, ys, zs, resistance_idx, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.96, ...
        'FaceLighting', 'gouraud');
    camlight headlight;
end


function local_toggle_streamlines(src, streamline_handles)
    if src.Value
        set(streamline_handles, 'Visible', 'on');
    else
        set(streamline_handles, 'Visible', 'off');
    end
end