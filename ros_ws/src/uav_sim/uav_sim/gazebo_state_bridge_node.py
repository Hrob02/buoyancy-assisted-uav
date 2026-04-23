"""Bridge vertical simulation state into Gazebo model pose updates."""

import math

import rclpy
from geometry_msgs.msg import Pose, Twist
from gazebo_msgs.msg import EntityState
from gazebo_msgs.msg import ModelState
from gazebo_msgs.srv import SetEntityState
from gazebo_msgs.srv import SetModelState
from rclpy.node import Node
from uav_interfaces.msg import VerticalState


class GazeboStateBridgeNode(Node):
    """Pushes simulated altitude into Gazebo so motion is visible."""

    def __init__(self) -> None:
        super().__init__("gazebo_state_bridge")

        self.declare_parameter("entity_name", "simple_uav")
        self.declare_parameter("fixed_x_m", 0.0)
        self.declare_parameter("fixed_y_m", 0.0)
        self.declare_parameter("xy_motion_enabled", True)
        self.declare_parameter("xy_motion_start_delay_s", 3.0)
        self.declare_parameter("xy_motion_duration_s", 24.0)
        self.declare_parameter("xy_motion_radius_m", 2.0)
        self.declare_parameter("xy_motion_period_s", 12.0)
        self.declare_parameter("xy_motion_y_scale", 0.7)

        self._entity_name = str(self.get_parameter("entity_name").value)
        self._fixed_x = float(self.get_parameter("fixed_x_m").value)
        self._fixed_y = float(self.get_parameter("fixed_y_m").value)
        self._xy_motion_enabled = bool(self.get_parameter("xy_motion_enabled").value)
        self._xy_motion_start_delay_s = float(self.get_parameter("xy_motion_start_delay_s").value)
        self._xy_motion_duration_s = float(self.get_parameter("xy_motion_duration_s").value)
        self._xy_motion_radius_m = float(self.get_parameter("xy_motion_radius_m").value)
        self._xy_motion_period_s = max(
            0.1,
            float(self.get_parameter("xy_motion_period_s").value),
        )
        self._xy_motion_y_scale = float(self.get_parameter("xy_motion_y_scale").value)

        self._latest_z = 1.0
        self._latest_vz = 0.0
        self._has_state = False
        self._request_in_flight = False
        self._warned_no_service = False
        self._last_debug_log_s = 0.0
        self._mission_t0_s = None

        self._vertical_state_sub = self.create_subscription(
            VerticalState,
            "/uav/vertical_state",
            self._vertical_state_callback,
            10,
        )

        self._set_state_client = self.create_client(SetEntityState, "/gazebo/set_entity_state")
        self._set_state_client_fallback = self.create_client(SetEntityState, "/set_entity_state")
        self._set_model_state_client = self.create_client(SetModelState, "/gazebo/set_model_state")
        self._set_model_state_client_fallback = self.create_client(SetModelState, "/set_model_state")
        self._model_state_pub = self.create_publisher(ModelState, "/gazebo/set_model_state", 10)
        self._timer = self.create_timer(0.05, self._timer_callback)

        self.get_logger().info("GazeboStateBridgeNode started.")

    def _vertical_state_callback(self, msg: VerticalState) -> None:
        self._latest_z = float(msg.z)
        self._latest_vz = float(msg.vz)
        self._has_state = True

    def _compute_xy_state(self, now_s: float):
        if self._mission_t0_s is None:
            self._mission_t0_s = now_s

        if not self._xy_motion_enabled:
            return self._fixed_x, self._fixed_y, 0.0, 0.0

        elapsed = now_s - self._mission_t0_s
        t_xy = elapsed - self._xy_motion_start_delay_s
        omega = 2.0 * math.pi / self._xy_motion_period_s

        if t_xy <= 0.0:
            return self._fixed_x, self._fixed_y, 0.0, 0.0

        if t_xy > self._xy_motion_duration_s:
            t_xy = self._xy_motion_duration_s

        x = self._fixed_x + self._xy_motion_radius_m * math.cos(omega * t_xy)
        y = self._fixed_y + self._xy_motion_radius_m * self._xy_motion_y_scale * math.sin(omega * t_xy)

        if elapsed - self._mission_t0_s > (self._xy_motion_start_delay_s + self._xy_motion_duration_s):
            return x, y, 0.0, 0.0

        vx = -self._xy_motion_radius_m * omega * math.sin(omega * t_xy)
        vy = (
            self._xy_motion_radius_m
            * self._xy_motion_y_scale
            * omega
            * math.cos(omega * t_xy)
        )
        return x, y, vx, vy

    def _timer_callback(self) -> None:
        if not self._has_state or self._request_in_flight:
            return

        now_s = self.get_clock().now().nanoseconds / 1e9
        x, y, vx, vy = self._compute_xy_state(now_s)
        entity_client = None
        model_client = None
        if self._set_state_client.wait_for_service(timeout_sec=0.0):
            entity_client = self._set_state_client
        elif self._set_state_client_fallback.wait_for_service(timeout_sec=0.0):
            entity_client = self._set_state_client_fallback

        if self._set_model_state_client.wait_for_service(timeout_sec=0.0):
            model_client = self._set_model_state_client
        elif self._set_model_state_client_fallback.wait_for_service(timeout_sec=0.0):
            model_client = self._set_model_state_client_fallback

        if entity_client is None and model_client is None:
            if not self._warned_no_service:
                self.get_logger().warn(
                    "Waiting for Gazebo pose service (/gazebo/set_model_state, /set_model_state, /gazebo/set_entity_state, /set_entity_state)."
                )
                self._warned_no_service = True
            return

        if self._warned_no_service:
            self.get_logger().info("Connected to Gazebo pose service.")
            self._warned_no_service = False

        pose = Pose()
        pose.position.x = x
        pose.position.y = y
        pose.position.z = self._latest_z
        pose.orientation.w = 1.0

        twist = Twist()
        twist.linear.x = vx
        twist.linear.y = vy
        twist.linear.z = self._latest_vz

        # Topic-based model-state update works on many Gazebo setups even when
        # the corresponding services are delayed or unavailable.
        model_state_msg = ModelState()
        model_state_msg.model_name = self._entity_name
        model_state_msg.reference_frame = "world"
        model_state_msg.pose = pose
        model_state_msg.twist = twist
        self._model_state_pub.publish(model_state_msg)

        self._request_in_flight = True
        if model_client is not None:
            req = SetModelState.Request()
            req.model_state = ModelState()
            req.model_state.model_name = self._entity_name
            req.model_state.reference_frame = "world"
            req.model_state.pose = pose
            req.model_state.twist = twist
            future = model_client.call_async(req)
            future.add_done_callback(self._on_set_model_state_done)
        else:
            req = SetEntityState.Request()
            req.state = EntityState()
            req.state.name = self._entity_name
            req.state.reference_frame = "world"
            req.state.pose = pose
            req.state.twist = twist
            future = entity_client.call_async(req)
            future.add_done_callback(self._on_set_state_done)

        if now_s - self._last_debug_log_s >= 2.0:
            self._last_debug_log_s = now_s
            self.get_logger().info(
                "Bridge update x=%.2f y=%.2f z=%.2f"
                % (pose.position.x, pose.position.y, self._latest_z)
            )

    def _on_set_state_done(self, future) -> None:
        self._request_in_flight = False
        try:
            resp = future.result()
            if resp is not None and not resp.success:
                msg = getattr(resp, "status_message", "")
                if msg:
                    self.get_logger().warn("SetEntityState failed: %s" % msg)
                else:
                    self.get_logger().warn("SetEntityState failed.")
        except Exception as exc:  # pragma: no cover - runtime transport errors
            self.get_logger().warn("SetEntityState call exception: %s" % exc)

    def _on_set_model_state_done(self, future) -> None:
        self._request_in_flight = False
        try:
            resp = future.result()
            if resp is not None and not resp.success:
                msg = getattr(resp, "status_message", "")
                if msg:
                    self.get_logger().warn("SetModelState failed: %s" % msg)
                else:
                    self.get_logger().warn("SetModelState failed.")
        except Exception as exc:  # pragma: no cover - runtime transport errors
            self.get_logger().warn("SetModelState call exception: %s" % exc)


def main(args=None) -> None:
    rclpy.init(args=args)
    node = GazeboStateBridgeNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
