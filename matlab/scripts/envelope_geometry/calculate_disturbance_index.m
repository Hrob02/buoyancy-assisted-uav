function disturbance = calculate_disturbance_index(shape, dimensions)
%CALCULATE_DISTURBANCE_INDEX Compute deterministic disturbance screening metrics.

nAz = 72;
nEl = 37;
azimuth_rad = linspace(0, 2 * pi, nAz);
elevation_rad = linspace(-pi / 2, pi / 2, nEl);
[azimuthGrid, elevationGrid] = meshgrid(azimuth_rad, elevation_rad);

nx = cos(elevationGrid) .* cos(azimuthGrid);
ny = cos(elevationGrid) .* sin(azimuthGrid);
nz = sin(elevationGrid);

projectedArea_m2 = directional_projected_area(shape, dimensions, nx, ny, nz);
directionalCd = directional_cd(shape.cd_xyz, nx, ny, nz);
directionalResponse = projectedArea_m2 .* directionalCd;

meanResponse = mean(directionalResponse, 'all');
worstResponse = max(directionalResponse, [], 'all');
anisotropy = std(directionalResponse, 0, 'all') / max(meanResponse, eps);

disturbance.disturbance_stability_index = meanResponse * (1 + 0.7 * anisotropy) * ...
    (1 + 0.3 * (worstResponse / max(meanResponse, eps)));
disturbance.mean_directional_response = meanResponse;
disturbance.worst_directional_response = worstResponse;
disturbance.anisotropy = anisotropy;

end

function projectedArea_m2 = directional_projected_area(shape, dimensions, nx, ny, nz)
L = dimensions.length_m;
W = dimensions.width_m;
H = dimensions.height_m;

switch lower(shape.type)
    case 'cuboid'
        projectedArea_m2 = abs(nx) * (W * H) + abs(ny) * (L * H) + abs(nz) * (L * W);

    case {'sphere', 'ellipsoid'}
        a = L / 2;
        b = W / 2;
        c = H / 2;
        denominator = sqrt((a .* nx).^2 + (b .* ny).^2 + (c .* nz).^2);
        projectedArea_m2 = pi * a * b * c ./ max(denominator, eps);

    otherwise
        error('EnvelopeGeometry:UnknownShapeType', 'Unsupported shape type: %s', shape.type);
end
end

function directionalCd = directional_cd(cdXYZ, nx, ny, nz)
weightsX = abs(nx);
weightsY = abs(ny);
weightsZ = abs(nz);
weightSum = weightsX + weightsY + weightsZ + eps;

directionalCd = (cdXYZ(1) * weightsX + cdXYZ(2) * weightsY + cdXYZ(3) * weightsZ) ./ weightSum;

end