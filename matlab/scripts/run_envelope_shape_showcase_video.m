function run_envelope_shape_showcase_video()
%RUN_ENVELOPE_SHAPE_SHOWCASE_VIDEO Stitch shape rotation clips into one showcase video.

clc;

cfg = config_envelope_geometry_parameters();
rotationDir = fullfile(cfg.paths.figures_dir, 'shape_rotation');
outputPath = fullfile(rotationDir, 'envelope_shape_showcase.mp4');

clipOrder = {
    'sphere_rotation.mp4', ...
    'prolate_ellipsoid_rotation.mp4', ...
    'cuboid_rotation.mp4', ...
    'flattened_ellipsoid_rotation.mp4'};

clipLabels = {
    'Sphere', ...
    'Prolate Ellipsoid', ...
    'Rounded Cuboid', ...
    'Flattened Ellipsoid'};

for clipIndex = 1:numel(clipOrder)
    clipPath = fullfile(rotationDir, clipOrder{clipIndex});
    if ~exist(clipPath, 'file')
        error('EnvelopeGeometry:MissingRotationClip', ...
            'Missing clip: %s. Generate shape rotations before stitching.', clipPath);
    end
end

if exist(outputPath, 'file')
    delete(outputPath);
end

firstReader = VideoReader(fullfile(rotationDir, clipOrder{1}));
writer = VideoWriter(outputPath, 'MPEG-4');
writer.FrameRate = firstReader.FrameRate;
open(writer);

fprintf('=== Envelope Shape Showcase Stitch ===\n');
fprintf('Output video: %s\n', outputPath);

for clipIndex = 1:numel(clipOrder)
    clipPath = fullfile(rotationDir, clipOrder{clipIndex});
    reader = VideoReader(clipPath);
    fprintf('Appending clip %d/%d: %s\n', clipIndex, numel(clipOrder), clipLabels{clipIndex});

    while hasFrame(reader)
        frame = readFrame(reader);
        writeVideo(writer, frame);
    end
end

close(writer);
fprintf('Showcase video generated successfully.\n');

end