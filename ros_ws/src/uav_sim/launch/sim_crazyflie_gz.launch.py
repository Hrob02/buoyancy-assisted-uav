"""Phase-2 launch for native Crazyflie multicopter actuation in modern Gazebo."""

import os

from launch import LaunchDescription
from launch.actions import ExecuteProcess, SetEnvironmentVariable, TimerAction
from launch.substitutions import PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description() -> LaunchDescription:
    pkg_share = FindPackageShare("uav_sim")
    world_file = PathJoinSubstitution([pkg_share, "worlds", "crazyflie_gz_world.sdf"])

    gz_resource_path = SetEnvironmentVariable(
        name="GZ_SIM_RESOURCE_PATH",
        value=[
            PathJoinSubstitution([pkg_share, "models"]),
            os.pathsep,
            PathJoinSubstitution([pkg_share, "worlds"]),
            os.pathsep,
            os.environ.get("GZ_SIM_RESOURCE_PATH", ""),
        ],
    )

    ign_resource_path = SetEnvironmentVariable(
        name="IGN_GAZEBO_RESOURCE_PATH",
        value=[
            PathJoinSubstitution([pkg_share, "models"]),
            os.pathsep,
            PathJoinSubstitution([pkg_share, "worlds"]),
            os.pathsep,
            os.environ.get("IGN_GAZEBO_RESOURCE_PATH", ""),
        ],
    )

    gz_sim = ExecuteProcess(
        cmd=["gz", "sim", "-v", "4", world_file],
        output="screen",
    )

    # Topic bridge for manual Twist-based control (cmd_vel -> throttle and attitude commands)
    gz_ros_bridge = TimerAction(
        period=2.0,
        actions=[
            Node(
                package="ros_gz_bridge",
                executable="parameter_bridge",
                arguments=[
                    # Subscribe to Gazebo odometry and publish to ROS state topic
                    "/model/crazyflie/odometry@nav_msgs/msg/Odometry[ignition.msgs.Odometry",
                    # Subscribe to ROS Twist command and publish to Gazebo
                    "/cmd_vel@geometry_msgs/msg/Twist]ignition.msgs.Twist",
                ],
                output="screen",
            ),
        ],
    )

    return LaunchDescription([
        gz_resource_path,
        ign_resource_path,
        gz_sim,
        gz_ros_bridge,
    ])
