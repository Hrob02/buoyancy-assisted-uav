def compute_weight(mass, g):
    return mass * g

def compute_buoyancy(rho_air, g, volume):
    return rho_air * g * volume

def compute_drag(vz, drag_coeff):
    return drag_coeff * vz

def compute_net_force(buoyancy, thrust, weight, drag):
    return buoyancy + thrust - weight - drag

def step_vertical_dynamics(z, vz, az, dt, params, thrust):
    # Unpack parameters
    mass = params['mass_kg']
    g = params['gravity_mps2']
    rho_air = params['air_density_kg_m3']
    volume = params['envelope_volume_m3']
    drag_coeff = params['drag_coeff']
    ground_z = params['ground_z_m']

    weight = compute_weight(mass, g)
    buoyancy = compute_buoyancy(rho_air, g, volume)
    drag = compute_drag(vz, drag_coeff)
    net_force = compute_net_force(buoyancy, thrust, weight, drag)
    az = net_force / mass

    vz_new = vz + az * dt
    z_new = z + vz_new * dt

    grounded = False
    if z_new <= ground_z:
        z_new = ground_z
        if vz_new < 0:
            vz_new = 0
        grounded = True

    return {
        'z': z_new,
        'vz': vz_new,
        'az': az,
        'buoyancy_force': buoyancy,
        'thrust_force': thrust,
        'weight_force': weight,
        'drag_force': drag,
        'net_force': net_force,
        'grounded': grounded
    }