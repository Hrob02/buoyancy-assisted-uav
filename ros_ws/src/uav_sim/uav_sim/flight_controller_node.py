"""Stub flight controller node for the buoyancy-assisted UAV."""

import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64


class FlightControllerNode(Node):
    """Minimal stub flight controller.

    Publishes a placeholder throttle command at a fixed rate.
    Replace the control logic with actual aerodynamic model calls.
    """

    def __init__(self) -> None:
        super().__init__("flight_controller")

        # Parameters
        self.declare_parameter("publish_rate_hz", 10.0)
        rate = self.get_parameter("publish_rate_hz").value

        # Publisher
        self._pub = self.create_publisher(Float64, "uav/throttle_cmd", 10)

        # Timer
        self._timer = self.create_timer(1.0 / rate, self._timer_callback)
        self.get_logger().info("FlightControllerNode started.")

    def _timer_callback(self) -> None:
        msg = Float64()
        msg.data = 0.5  # placeholder 50 % throttle
        self._pub.publish(msg)


def main(args=None) -> None:
    rclpy.init(args=args)
    node = FlightControllerNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
