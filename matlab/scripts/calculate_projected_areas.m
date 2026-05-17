function projectedAreas = calculate_projected_areas(shape, dimensions)
%CALCULATE_PROJECTED_AREAS Compute principal projected areas and size-envelope terms.

L = dimensions.length_m;
W = dimensions.width_m;
H = dimensions.height_m;

switch lower(shape.type)
    case {'sphere', 'ellipsoid'}
        a = L / 2;
        b = W / 2;
        c = H / 2;
        projectedAreas.area_yz_m2 = pi * b * c;
        projectedAreas.area_xz_m2 = pi * a * c;
        projectedAreas.area_xy_m2 = pi * a * b;

    case 'cuboid'
        projectedAreas.area_yz_m2 = W * H;
        projectedAreas.area_xz_m2 = L * H;
        projectedAreas.area_xy_m2 = L * W;

    otherwise
        error('EnvelopeGeometry:UnknownShapeType', 'Unsupported shape type: %s', shape.type);
end

projectedAreas.max_dimension_m = max([L, W, H]);

end