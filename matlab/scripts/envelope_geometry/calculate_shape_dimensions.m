function dimensions = calculate_shape_dimensions(requiredVolume_m3, shape)
%CALCULATE_SHAPE_DIMENSIONS Compute characteristic dimensions for a target volume.

aspect = shape.aspect_ratio;
scale = product_scale(requiredVolume_m3, aspect, shape.type);

dimensions.length_m = scale * aspect(1);
dimensions.width_m = scale * aspect(2);
dimensions.height_m = scale * aspect(3);

end

function scale = product_scale(requiredVolume_m3, aspect, shapeType)
if strcmpi(shapeType, 'cuboid')
    scale = (requiredVolume_m3 / prod(aspect))^(1 / 3);
else
    scale = ((6 * requiredVolume_m3) / (pi * prod(aspect)))^(1 / 3);
end
end