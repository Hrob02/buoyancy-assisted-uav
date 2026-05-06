"""Launch UAV simulation with a Crazyflie visual mesh in Gazebo Classic."""

import os

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, ExecuteProcess, SetEnvironmentVariable, TimerAction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description() -> LaunchDescription:
    pkg_share = FindPackageShare("uav_sim")

    params_file = PathJoinSubstitution([pkg_share, "config", "sim_params_crazyflie.yaml"])
    vertical_params_file = PathJoinSubstitution([pkg_share, "config", "vertical_params.yaml"])
    world_file = PathJoinSubstitution([pkg_share, "worlds", "empty_floor.world"])
    model_file = PathJoinSubstitution([pkg_share, "models", "crazyflie_visual", "model.sdf"])
    rviz_config = PathJoinSubstitution([pkg_share, "rviz", "nav2_default.rviz"])

    use_sim_time_arg = DeclareLaunchArgument(
        "use_sim_time",
        default_value="false",
        description="Use Gazebo simulation time if true",
    )
    start_rviz_arg = DeclareLaunchArgument(
        "start_rviz",
        default_value="true",
        description="Start RViz when true",
    )
    autopilot_enabled_arg = DeclareLaunchArgument(
        "autopilot_enabled",
        default_value="true",
        description="Start flight controller node when true",
    )

    # model:// URIs in SDF resolve against GAZEBO_MODEL_PATH.
    model_path_env = SetEnvironmentVariable(
        name="GAZEBO_MODEL_PATH",
        value=[
            PathJoinSubstitution([pkg_share, "models"]),
            os.pathsep,
            os.environ.get("GAZEBO_MODEL_PATH", ""),
        ],
    )

    gazebo = ExecuteProcess(
        cmd=[
            "gazebo",
            "--verbose",
            world_file,
            "-s",
            "libgazebo_ros_init.so",
            "-s",
            "libgazebo_ros_factory.so",
        ],
        output="screen",
    )

    spawn_uav = TimerAction(
        period=2.0,
        actions=[
            Node(
                package="gazebo_ros",
                executable="spawn_entity.py",
                name="spawn_crazyflie_visual",
                arguments=[
                    "-entity",
                    "crazyflie_visual",
                    "-file",
                    model_file,
                    "-x",
                    "0",
                    "-y",
                    "0",
                    "-z",
                    "0.0",
                ],
                output="screen",
            )
        ],
    )

    flight_controller_node = Node(
        package="uav_sim",
        executable="flight_controller",
        name="flight_controller",
        parameters=[params_file, {"use_sim_time": LaunchConfiguration("use_sim_time")}],
        output="screen",
        condition=IfCondition(LaunchConfiguration("autopilot_enabled")),
    )

    sensor_publisher_node = Node(
        package="uav_sim",
        executable="sensor_publisher",
        name="sensor_publisher",
        parameters=[params_file, {"use_sim_time": LaunchConfiguration("use_sim_time")}],
        output="screen",
    )

    vertical_dynamics_node = Node(
        package="uav_sim",
        executable="vertical_dynamics_node",
        name="vertical_dynamics_node",
        parameters=[vertical_params_file, {"use_sim_time": LaunchConfiguration("use_sim_time")}],
        output="screen",
    )

    gazebo_bridge_node = Node(
        package="uav_sim",
        executable="gazebo_state_bridge",
        name="gazebo_state_bridge",
        parameters=[
            params_file,
            {
                "use_sim_time": LaunchConfiguration("use_sim_time"),
                "xy_motion_enabled": LaunchConfiguration("autopilot_enabled"),
            },
        ],
        output="screen",
    )

    rviz_visualization_node = Node(
        package="uav_sim",
        executable="rviz_visualization",
        name="rviz_visualization",
        parameters=[
            params_file,
            {
                "use_sim_time": LaunchConfiguration("use_sim_time"),
                "xy_motion_enabled": LaunchConfiguration("autopilot_enabled"),
            },
        ],
        output="screen",
    )

    rviz_node = Node(
        package="rviz2",
        executable="rviz2",
        name="rviz2",
        arguments=["-d", rviz_config],
        parameters=[{"use_sim_time": LaunchConfiguration("use_sim_time")}],
        output="screen",
        condition=IfCondition(LaunchConfiguration("start_rviz")),
    )

    return LaunchDescription(
        [
            use_sim_time_arg,
            start_rviz_arg,
            autopilot_enabled_arg,
            model_path_env,
            gazebo,
            spawn_uav,
            flight_controller_node,
            sensor_publisher_node,
            vertical_dynamics_node,
            gazebo_bridge_node,
            rviz_visualization_node,
            rviz_node,
        ]
    )
