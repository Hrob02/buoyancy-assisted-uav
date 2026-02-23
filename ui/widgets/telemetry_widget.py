"""Placeholder telemetry panel widget."""


class TelemetryWidget:
    """Displays real-time UAV telemetry data.

    Placeholder class. Replace with a QWidget subclass that subscribes
    to ROS 2 topics and updates labels/gauges in real time.

    Example topics to subscribe to:
        - uav/altitude_m   (std_msgs/Float64)
        - uav/imu          (sensor_msgs/Imu)
        - uav/throttle_cmd (std_msgs/Float64)
    """

    def update(self, telemetry: dict) -> None:
        """Update displayed values from a telemetry dict."""
        raise NotImplementedError
