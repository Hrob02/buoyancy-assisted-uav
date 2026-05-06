from setuptools import find_packages, setup
from glob import glob
import os

package_name = "uav_sim"

setup(
    name=package_name,
    version="0.1.0",
    packages=find_packages(exclude=["test"]),
    data_files=[
        ("share/ament_index/resource_index/packages", ["resource/" + package_name]),
        ("share/" + package_name, ["package.xml"]),
        (os.path.join("share", package_name, "launch"), glob("launch/*.launch.py")),
        (os.path.join("share", package_name, "config"), glob("config/*.yaml")),
        (os.path.join("share", package_name, "worlds"), glob("worlds/*")),
        (os.path.join("share", package_name, "rviz"), glob("rviz/*")),
        (os.path.join("share", package_name, "models", "simple_uav"), glob("models/simple_uav/*")),
        (
            os.path.join("share", package_name, "models", "crazyflie_visual"),
            [
                "models/crazyflie_visual/model.config",
                "models/crazyflie_visual/model.sdf",
            ],
        ),
        (
            os.path.join("share", package_name, "models", "crazyflie_visual", "meshes"),
            glob("models/crazyflie_visual/meshes/*"),
        ),
        (
            os.path.join("share", package_name, "models", "crazyflie_gz"),
            [
                "models/crazyflie_gz/model.config",
                "models/crazyflie_gz/model.sdf",
            ],
        ),
        (
            os.path.join("share", package_name, "models", "crazyflie_gz", "meshes"),
            glob("models/crazyflie_gz/meshes/*"),
        ),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="Hrob02",
    maintainer_email="placeholder@example.com",
    description="ROS 2 Python simulation package for the buoyancy-assisted UAV.",
    license="MIT",
    tests_require=["pytest"],
    entry_points={
        "console_scripts": [
            "flight_controller = uav_sim.flight_controller_node:main",
            "sensor_publisher = uav_sim.sensor_publisher_node:main",
            "vertical_dynamics_node = uav_sim.vertical_dynamics_node:main",
            "gazebo_state_bridge = uav_sim.gazebo_state_bridge_node:main",
            "rviz_visualization = uav_sim.rviz_visualization_node:main",
        ],
    },
)