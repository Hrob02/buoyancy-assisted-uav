from setuptools import find_packages, setup

package_name = "uav_sim"

setup(
    name=package_name,
    version="0.1.0",
    packages=find_packages(exclude=["test"]),
    data_files=[
        ("share/ament_index/resource_index/packages", ["resource/" + package_name]),
        ("share/" + package_name, ["package.xml"]),
        ("share/" + package_name + "/launch", ["launch/sim.launch.py"]),
        ("share/" + package_name + "/config", ["config/sim_params.yaml"]),
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
        ],
    },
)
