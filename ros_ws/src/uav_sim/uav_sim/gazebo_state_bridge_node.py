"""Bridge vertical simulation state into Gazebo model pose updates."""

import rclpy
from geometry_msgs.msg import Pose, Twist
from gazebo_msgs.msg import EntityState
from gazebo_msgs.srv import SetEntityState
from rclpy.node import Node
from uav_interfaces.msg import VerticalState


class GazeboStateBridgeNode(Node):
    """Pushes simulated altitude into Gazebo so motion is visible."""

    def __init__(self) -> None:
        super().__init__("gazebo_state_bridge")

        self.declare_parameter("entity_name", "simple_uav")
        self.declare_parameter("fixed_x_m", 0.0)
        self.declare_parameter("fixed_y_m", 0.0)

        self._entity_name = str(self.get_parameter("entity_name").value)
        self._fixed_x = float(self.get_parameter("fixed_x_m").value)
        self._fixed_y = float(self.get_parameter("fixed_y_m").value)

        self._latest_z = 1.0
        self._latest_vz = 0.0
        self._has_state = False
        self._request_in_flight = False

        self._vertical_state_sub = self.create_subscription(
            VerticalState,
            "/uav/vertical_state",
            self._vertical_state_callback,
            10,
        )

        self._set_state_client = self.create_client(SetEntityState, "/gazebo/set_entity_state")
        self._timer = self.create_timer(0.05, self._timer_callback)

        self.get_logger().info("GazeboStateBridgeNode started.")

    def _vertical_state_callback(self, msg: VerticalState) -> None:
        self._latest_z = float(msg.z)
        self._latest_vz = float(msg.vz)
        self._has_state = True

    def _timer_callback(self) -> None:
        if not self._has_state or self._request_in_flight:
            return

        if not self._set_state_client.wait_for_service(timeout_sec=0.0):
            return

        req = SetEntityState.Request()
        req.state = EntityState()
        req.state.name = self._entity_name
        req.state.reference_frame = "world"

        pose = Pose()
        pose.position.x = self._fixed_x
        pose.position.y = self._fixed_y
        pose.position.z = self._latest_z
        pose.orientation.w = 1.0
        req.state.pose = pose

        twist = Twist()
        twist.linear.z = self._latest_vz
        req.state.twist = twist

        self._request_in_flight = True
        future = self._set_state_client.call_async(req)
        future.add_done_callback(self._on_set_state_done)

    def _on_set_state_done(self, future) -> None:
        self._request_in_flight = False
        try:
            resp = future.result()
            if resp is not None and not resp.success:
                self.get_logger().debug("SetEntityState failed: %s" % resp.status_message)
        except Exception as exc:  # pragma: no cover - runtime transport errors
            self.get_logger().debug("SetEntityState call exception: %s" % exc)


def main(args=None) -> None:
    rclpy.init(args=args)
    node = GazeboStateBridgeNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
