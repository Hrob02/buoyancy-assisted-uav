"""Launch file for the buoyancy-assisted UAV simulation."""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description() -> LaunchDescription:
    pkg_share = FindPackageShare("uav_sim")

    params_file = PathJoinSubstitution([pkg_share, "config", "sim_params.yaml"])

    use_sim_time_arg = DeclareLaunchArgument(
        "use_sim_time",
        default_value="false",
        description="Use simulation (Gazebo) clock if true",
    )

    flight_controller_node = Node(
        package="uav_sim",
        executable="flight_controller",
        name="flight_controller",
        parameters=[params_file, {"use_sim_time": LaunchConfiguration("use_sim_time")}],
        output="screen",
    )

    sensor_publisher_node = Node(
        package="uav_sim",
        executable="sensor_publisher",
        name="sensor_publisher",
        parameters=[params_file, {"use_sim_time": LaunchConfiguration("use_sim_time")}],
        output="screen",
    )

    return LaunchDescription(
        [
            use_sim_time_arg,
            flight_controller_node,
            sensor_publisher_node,
        ]
    )
