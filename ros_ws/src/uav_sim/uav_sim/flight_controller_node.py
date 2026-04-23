"""Autonomous flight controller for vertical mission execution."""

import math

import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64, String
from uav_interfaces.msg import VerticalState


class FlightControllerNode(Node):
    """Executes an automatic takeoff and altitude waypoint mission."""

    def __init__(self) -> None:
        super().__init__("flight_controller")

        # Parameters
        self.declare_parameter("publish_rate_hz", 10.0)
        self.declare_parameter("takeoff_altitude_m", 4.0)
        self.declare_parameter("altitude_tolerance_m", 0.15)
        self.declare_parameter("kp", 0.22)
        self.declare_parameter("ki", 0.06)
        self.declare_parameter("kd", 0.12)
        self.declare_parameter("base_hover_throttle", 0.46)
        self.declare_parameter("min_throttle", 0.0)
        self.declare_parameter("max_throttle", 1.0)
        self.declare_parameter("integral_limit", 6.0)
        self.declare_parameter("mission_hold_time_s", 4.0)
        self.declare_parameter("mission_route_m", [5.5, 3.0, 6.0, 2.5])

        rate = self.get_parameter("publish_rate_hz").value
        self._takeoff_altitude_m = float(self.get_parameter("takeoff_altitude_m").value)
        self._alt_tolerance_m = float(self.get_parameter("altitude_tolerance_m").value)
        self._kp = float(self.get_parameter("kp").value)
        self._ki = float(self.get_parameter("ki").value)
        self._kd = float(self.get_parameter("kd").value)
        self._hover = float(self.get_parameter("base_hover_throttle").value)
        self._thr_min = float(self.get_parameter("min_throttle").value)
        self._thr_max = float(self.get_parameter("max_throttle").value)
        self._integral_limit = float(self.get_parameter("integral_limit").value)
        self._hold_time_s = float(self.get_parameter("mission_hold_time_s").value)
        route_values = self.get_parameter("mission_route_m").value
        self._route = [float(v) for v in route_values]

        if not self._route:
            self._route = [self._takeoff_altitude_m]

        # Publisher
        self._pub = self.create_publisher(Float64, "uav/throttle_cmd", 10)
        self._state_pub = self.create_publisher(String, "uav/mission_state", 10)

        # Subscriptions
        self._vertical_state_sub = self.create_subscription(
            VerticalState,
            "/uav/vertical_state",
            self._vertical_state_callback,
            10,
        )

        # Internal state
        self._current_z = 0.0
        self._current_vz = 0.0
        self._has_state = False
        self._phase = "TAKEOFF"
        self._target_altitude_m = self._takeoff_altitude_m
        self._route_index = 0
        self._hold_start_s = None
        self._last_time_s = None
        self._integral_error = 0.0

        # Timer
        self._timer = self.create_timer(1.0 / rate, self._timer_callback)
        self.get_logger().info(
            "FlightControllerNode started. Mission: takeoff to %.2fm then %s"
            % (self._takeoff_altitude_m, self._route)
        )

    def _vertical_state_callback(self, msg: VerticalState) -> None:
        self._current_z = float(msg.z)
        self._current_vz = float(msg.vz)
        self._has_state = True

    def _publish_phase(self) -> None:
        status = String()
        status.data = f"{self._phase}:{self._target_altitude_m:.2f}"
        self._state_pub.publish(status)

    def _advance_route_if_ready(self, now_s: float) -> None:
        altitude_error = self._target_altitude_m - self._current_z
        in_target_band = math.fabs(altitude_error) <= self._alt_tolerance_m

        if not in_target_band:
            self._hold_start_s = None
            return

        if self._hold_start_s is None:
            self._hold_start_s = now_s
            return

        held_long_enough = (now_s - self._hold_start_s) >= self._hold_time_s
        if not held_long_enough:
            return

        if self._phase == "TAKEOFF":
            self._phase = "MISSION"

        if self._route_index < len(self._route):
            self._target_altitude_m = self._route[self._route_index]
            self._route_index += 1
            self._hold_start_s = None
            self._integral_error = 0.0
            self.get_logger().info(
                "Advancing to mission waypoint %d at %.2fm"
                % (self._route_index, self._target_altitude_m)
            )
        else:
            self._phase = "HOLD_FINAL"

    def _timer_callback(self) -> None:
        if not self._has_state:
            return

        now_s = self.get_clock().now().nanoseconds / 1e9
        self._advance_route_if_ready(now_s)

        altitude_error = self._target_altitude_m - self._current_z
        vz_error = -self._current_vz
        dt = 0.0 if self._last_time_s is None else max(0.0, now_s - self._last_time_s)
        self._last_time_s = now_s
        if dt > 0.0:
            self._integral_error += altitude_error * dt
            self._integral_error = max(
                -self._integral_limit,
                min(self._integral_limit, self._integral_error),
            )

        throttle = (
            self._hover
            + self._kp * altitude_error
            + self._ki * self._integral_error
            + self._kd * vz_error
        )
        throttle = max(self._thr_min, min(self._thr_max, throttle))

        msg = Float64()
        msg.data = float(throttle)
        self._pub.publish(msg)
        self._publish_phase()


def main(args=None) -> None:
    rclpy.init(args=args)
    node = FlightControllerNode()
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
