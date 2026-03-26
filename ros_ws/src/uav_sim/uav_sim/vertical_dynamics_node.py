import rclpy
from rclpy.node import Node
from uav_interfaces.msg import VerticalState
from .physics import step_vertical_dynamics

class VerticalDynamicsNode(Node):
    def __init__(self):
        super().__init__('vertical_dynamics_node')
        # Load parameters (add all needed)
        self.declare_parameters(
            namespace='',
            parameters=[
                ('mass_kg', 0.08),
                ('envelope_volume_m3', 0.003),
                ('air_density_kg_m3', 1.225),
                ('gravity_mps2', 9.81),
                ('max_thrust_n', 1.5),
                ('commanded_thrust_n', 0.6),
                ('drag_coeff', 0.02),
                ('dt', 0.02),
                ('initial_z_m', 1.0),
                ('initial_vz_mps', 0.0),
                ('ground_z_m', 0.0),
            ]
        )
        self.params = {k: self.get_parameter(k).value for k in [
            'mass_kg', 'envelope_volume_m3', 'air_density_kg_m3', 'gravity_mps2',
            'max_thrust_n', 'commanded_thrust_n', 'drag_coeff', 'dt',
            'initial_z_m', 'initial_vz_mps', 'ground_z_m'
        ]}
        self.state = {
            'z': self.params['initial_z_m'],
            'vz': self.params['initial_vz_mps'],
            'az': 0.0
        }
        self.publisher = self.create_publisher(VerticalState, '/uav/vertical_state', 10)
        self.timer = self.create_timer(self.params['dt'], self.timer_callback)

    def timer_callback(self):
        result = step_vertical_dynamics(
            self.state['z'],
            self.state['vz'],
            self.state['az'],
            self.params['dt'],
            self.params,
            self.params['commanded_thrust_n']
        )
        self.state.update({'z': result['z'], 'vz': result['vz'], 'az': result['az']})
        msg = VerticalState()
        msg.z = result['z']
        msg.vz = result['vz']
        msg.az = result['az']
        msg.buoyancy_force = result['buoyancy_force']
        msg.thrust_force = result['thrust_force']
        msg.weight_force = result['weight_force']
        msg.drag_force = result['drag_force']
        msg.net_force = result['net_force']
        msg.grounded = result['grounded']
        self.publisher.publish(msg)

def main(args=None):
    rclpy.init(args=args)
    node = VerticalDynamicsNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()