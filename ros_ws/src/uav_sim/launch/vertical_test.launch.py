from launch import LaunchDescription

from launch_ros.actions import Node
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from ament_index_python.packages import get_package_share_directory
import os

def generate_launch_description():
    uav_sim_dir = get_package_share_directory('uav_sim')
    world_path = os.path.join(uav_sim_dir, 'worlds', 'empty_floor.world')
    model_path = os.path.join(uav_sim_dir, 'models')
    config = os.path.join(uav_sim_dir, 'config', 'vertical_params.yaml')
    os.environ['GAZEBO_MODEL_PATH'] = model_path

    return LaunchDescription([
        # Launch Gazebo with the world
        Node(
            package='gazebo_ros',
            executable='gazebo',
            name='gazebo',
            output='screen',
            arguments=['--verbose', world_path, '-s', 'libgazebo_ros_factory.so']
        ),
        # Spawn the UAV model
        Node(
            package='gazebo_ros',
            executable='spawn_entity.py',
            name='spawn_simple_uav',
            output='screen',
            arguments=[
                '-entity', 'simple_uav',
                '-file', os.path.join(model_path, 'simple_uav', 'model.sdf'),
                '-x', '0', '-y', '0', '-z', '1.0'
            ]
        ),
        # Start the vertical dynamics node
        Node(
            package='uav_sim',
            executable='vertical_dynamics_node',
            name='vertical_dynamics_node',
            parameters=[config],
            output='screen'
        ),
        # Launch nav2_bringup for navigation stack
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource([
                os.path.join(get_package_share_directory('nav2_bringup'), 'launch', 'bringup_launch.py')
            ]),
            launch_arguments={
                'use_sim_time': 'true',
                'autostart': 'true'
            }.items(),
        ),
        # Launch RViz2 for visualization
        Node(
            package='rviz2',
            executable='rviz2',
            name='rviz2',
            output='screen',
            arguments=['-d', os.path.join(uav_sim_dir, 'rviz', 'nav2_default.rviz')]
        )
    ])