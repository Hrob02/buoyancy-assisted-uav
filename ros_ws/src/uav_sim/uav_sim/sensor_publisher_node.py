"""Stub sensor publisher node — simulates IMU and altitude sensor data."""

import rclpy
from geometry_msgs.msg import Vector3
from rclpy.node import Node
from sensor_msgs.msg import Imu
from std_msgs.msg import Float64
from uav_interfaces.msg import VerticalState


class SensorPublisherNode(Node):
    """Publishes placeholder IMU and altitude messages.

    Simulates sensor data for integration testing before hardware is
    available. Replace stub values with Gazebo topic subscriptions.
    """

    def __init__(self) -> None:
        super().__init__("sensor_publisher")

        self.declare_parameter("publish_rate_hz", 50.0)
        rate = self.get_parameter("publish_rate_hz").value

        self._imu_pub = self.create_publisher(Imu, "uav/imu", 10)
        self._alt_pub = self.create_publisher(Float64, "uav/altitude_m", 10)
        self._vertical_state_sub = self.create_subscription(
            VerticalState,
            "/uav/vertical_state",
            self._vertical_state_callback,
            10,
        )

        self._altitude_m = 0.0

        self._timer = self.create_timer(1.0 / rate, self._timer_callback)
        self.get_logger().info("SensorPublisherNode started.")

    def _vertical_state_callback(self, msg: VerticalState) -> None:
        self._altitude_m = float(msg.z)

    def _timer_callback(self) -> None:
        stamp = self.get_clock().now().to_msg()

        imu_msg = Imu()
        imu_msg.header.stamp = stamp
        imu_msg.header.frame_id = "imu_link"
        imu_msg.linear_acceleration = Vector3(x=0.0, y=0.0, z=9.81)
        self._imu_pub.publish(imu_msg)

        alt_msg = Float64()
        alt_msg.data = float(self._altitude_m)
        self._alt_pub.publish(alt_msg)


def main(args=None) -> None:
    rclpy.init(args=args)
    node = SensorPublisherNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
