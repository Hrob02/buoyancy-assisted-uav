function run_envelope_shape_rotation_animation()
%RUN_ENVELOPE_SHAPE_ROTATION_ANIMATION Export rotating shape animations for envelope study candidates.

clc;
close all;

cfg = config_envelope_geometry_parameters();

if ~exist(cfg.paths.figures_dir, 'dir')
    mkdir(cfg.paths.figures_dir);
end

outputDir = fullfile(cfg.paths.figures_dir, 'shape_rotation');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

requiredVolume_m3 = calculate_required_volume( ...
    cfg.system.reference_mass_g, ...
    cfg.system.target_buoyancy_ratio, ...
    cfg);

fprintf('=== Envelope Shape Rotation Animation ===\n');
fprintf('Required volume per shape: %.4f m^3 (%.2f L)\n', requiredVolume_m3, requiredVolume_m3 * 1000);
fprintf('Output directory: %s\n', outputDir);

for shapeIndex = 1:numel(cfg.shapes)
    shape = cfg.shapes(shapeIndex);
    dimensions = calculate_shape_dimensions(requiredVolume_m3, shape);
    export_shape_animation(shape, dimensions, outputDir);
end

fprintf('All shape animations generated.\n');

end

function export_shape_animation(shape, dimensions, outputDir)
nameSlug = char(shape.name);
displayName = char(shape.display_name);

gifPath = fullfile(outputDir, [nameSlug, '_rotation.gif']);
mp4Path = fullfile(outputDir, [nameSlug, '_rotation.mp4']);

if exist(gifPath, 'file')
    delete(gifPath);
end
if exist(mp4Path, 'file')
    delete(mp4Path);
end

figureHandle = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 920 700]);
axesHandle = axes(figureHandle);
axesHandle.Position = [0.07 0.08 0.86 0.78];
hold(axesHandle, 'on');
axis(axesHandle, 'equal');
axis(axesHandle, 'vis3d');
grid(axesHandle, 'on');
set(axesHandle, 'XMinorGrid', 'on', 'YMinorGrid', 'on', 'ZMinorGrid', 'on');
axesHandle.GridColor = [0.72 0.76 0.82];
axesHandle.MinorGridColor = [0.86 0.88 0.92];
axesHandle.GridAlpha = 0.55;
axesHandle.MinorGridAlpha = 0.35;
axesHandle.LineWidth = 0.9;
axesHandle.Color = [0.97 0.98 1.00];
xlabel(axesHandle, 'X [m]');
ylabel(axesHandle, 'Y [m]');
zlabel(axesHandle, 'Z [m]');

draw_shape(axesHandle, shape, dimensions, nameSlug);

maxHalfDimension = max([dimensions.length_m, dimensions.width_m, dimensions.height_m]) / 2;
viewPadding = 1.45;
xlim(axesHandle, [-1, 1] * maxHalfDimension * viewPadding);
ylim(axesHandle, [-1, 1] * maxHalfDimension * viewPadding);
zlim(axesHandle, [-1, 1] * maxHalfDimension * viewPadding);
camproj(axesHandle, 'orthographic');

camlight(axesHandle, 'headlight');
camlight(axesHandle, 'right');
lighting(axesHandle, 'gouraud');
material(axesHandle, 'dull');

shapeLabelText = sprintf('%s', displayName);
equationText = shape_equation_label(shape);
annotation(figureHandle, 'textbox', [0.05 0.92 0.90 0.05], ...
    'String', shapeLabelText, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'Interpreter', 'none', ...
    'EdgeColor', 'none', ...
    'FontWeight', 'bold', ...
    'FontSize', 13, ...
    'Color', [0.08 0.12 0.18], ...
    'BackgroundColor', [1 1 1 0.65]);
annotation(figureHandle, 'textbox', [0.05 0.885 0.90 0.04], ...
    'String', equationText, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'Interpreter', 'none', ...
    'EdgeColor', 'none', ...
    'FontSize', 11, ...
    'Color', [0.16 0.20 0.25], ...
    'BackgroundColor', [1 1 1 0.60]);

frameCount = 180;
frameDelay_s = 0.08;
elevationDeg = 22;
startAzimuthDeg = 40;
totalRotationDeg = 270;
hasMp4 = false;

try
    videoWriter = VideoWriter(mp4Path, 'MPEG-4');
    videoWriter.FrameRate = 1 / frameDelay_s;
    open(videoWriter);
    hasMp4 = true;
catch videoError
    fprintf('MP4 export disabled for %s: %s\n', displayName, videoError.message);
end

for frameIndex = 1:frameCount
    rotationFrac = (frameIndex - 1) / (frameCount - 1);
    azimuthDeg = startAzimuthDeg + rotationFrac * totalRotationDeg;
    view(axesHandle, azimuthDeg, elevationDeg);

    drawnow;

    frame = getframe(figureHandle);
    rgbImage = frame2im(frame);
    [indexedImage, map] = rgb2ind(rgbImage, 256);

    if frameIndex == 1
        imwrite(indexedImage, map, gifPath, 'gif', 'LoopCount', inf, 'DelayTime', frameDelay_s);
    else
        imwrite(indexedImage, map, gifPath, 'gif', 'WriteMode', 'append', 'DelayTime', frameDelay_s);
    end

    if hasMp4
        writeVideo(videoWriter, frame);
    end
end

if hasMp4
    close(videoWriter);
end

close(figureHandle);

fprintf('Generated %s\n', gifPath);
if hasMp4
    fprintf('Generated %s\n', mp4Path);
end
end

function draw_shape(axesHandle, shape, dimensions, shapeStyle)
L = dimensions.length_m;
W = dimensions.width_m;
H = dimensions.height_m;

switch lower(shape.type)
    case {'sphere', 'ellipsoid'}
        resolution = 60;
        [X, Y, Z] = sphere(resolution);
        X = X * (L / 2);
        Y = Y * (W / 2);
        Z = Z * (H / 2);

        textureData = Z ./ max(H / 2, eps);
        colormap(axesHandle, select_shape_colormap(shapeStyle));

        surf(axesHandle, X, Y, Z, ...
            textureData, ...
            'FaceColor', 'interp', ...
            'FaceAlpha', 0.92, ...
            'EdgeColor', [0.20 0.20 0.20], ...
            'EdgeAlpha', 0.08, ...
            'LineStyle', '-');

    case 'cuboid'
        resolutionU = 80;
        resolutionV = 42;
        [uGrid, vGrid] = meshgrid(linspace(-pi, pi, resolutionU), linspace(-pi/2, pi/2, resolutionV));

        % Higher exponent gives a softer, pillow-like rounded cuboid.
        roundnessExponent = 0.55;
        cosU = signed_power(cos(uGrid), roundnessExponent);
        sinU = signed_power(sin(uGrid), roundnessExponent);
        cosV = signed_power(cos(vGrid), roundnessExponent);
        sinV = signed_power(sin(vGrid), roundnessExponent);

        X = (L / 2) .* cosV .* cosU;
        Y = (W / 2) .* cosV .* sinU;
        Z = (H / 2) .* sinV;

        textureData = Z ./ max(H / 2, eps);
        colormap(axesHandle, vertical_green_blue_pink_colormap(256));

        surf(axesHandle, X, Y, Z, ...
            textureData, ...
            'FaceColor', 'interp', ...
            'FaceAlpha', 0.92, ...
            'EdgeColor', [0.20 0.20 0.20], ...
            'EdgeAlpha', 0.08, ...
            'LineStyle', '-');

    otherwise
        error('EnvelopeGeometry:UnknownShapeType', 'Unsupported shape type: %s', shape.type);
end
end

function cmap = select_shape_colormap(nameSlug)
switch lower(nameSlug)
    case {'sphere', 'prolate_ellipsoid', 'flattened_ellipsoid'}
        cmap = vertical_green_blue_pink_colormap(256);
    otherwise
        cmap = turbo(256);
end
end

function labelText = shape_equation_label(shape)
switch lower(char(shape.name))
    case 'sphere'
        labelText = 'x^2 + y^2 + z^2 = r^2';
    case {'prolate_ellipsoid', 'flattened_ellipsoid'}
        labelText = 'x^2/a^2 + y^2/b^2 + z^2/c^2 = 1';
    case 'cuboid'
        labelText = '|x| <= L/2, |y| <= W/2, |z| <= H/2';
    otherwise
        labelText = 'Shape model equation';
end
end

function cmap = vertical_green_blue_pink_colormap(sampleCount)
if nargin < 1
    sampleCount = 256;
end

baseStops = [ ...
    0.18 0.78 0.44; ...
    0.16 0.54 0.92; ...
    0.88 0.36 0.80];

samplePoints = linspace(1, size(baseStops, 1), sampleCount);
cmap = [ ...
    interp1(1:size(baseStops, 1), baseStops(:, 1), samplePoints, 'pchip')', ...
    interp1(1:size(baseStops, 1), baseStops(:, 2), samplePoints, 'pchip')', ...
    interp1(1:size(baseStops, 1), baseStops(:, 3), samplePoints, 'pchip')'];
end

function output = signed_power(inputValue, exponentValue)
output = sign(inputValue) .* (abs(inputValue) .^ exponentValue);
end