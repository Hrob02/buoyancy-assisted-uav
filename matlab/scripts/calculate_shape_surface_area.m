function surfaceArea_m2 = calculate_shape_surface_area(shape, dimensions)
%CALCULATE_SHAPE_SURFACE_AREA Compute envelope surface area for a candidate shape.

L = dimensions.length_m;
W = dimensions.width_m;
H = dimensions.height_m;

switch lower(shape.type)
    case 'sphere'
        radius_m = L / 2;
        surfaceArea_m2 = 4 * pi * radius_m^2;

    case 'ellipsoid'
        a = L / 2;
        b = W / 2;
        c = H / 2;
        p = 1.6075;
        surfaceArea_m2 = 4 * pi * (((a^p * b^p) + (a^p * c^p) + (b^p * c^p)) / 3)^(1 / p);

    case 'cuboid'
        surfaceArea_m2 = 2 * (L * W + L * H + W * H);

    otherwise
        error('EnvelopeGeometry:UnknownShapeType', 'Unsupported shape type: %s', shape.type);
end

end