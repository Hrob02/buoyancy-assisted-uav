from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(
            package='uav_sim',
            executable='vertical_dynamics_node',
            name='vertical_dynamics_node',
            parameters=['../config/vertical_params.yaml'],
            output='screen'
        )
    ])