"""Publish RViz-friendly UAV marker and TF from vertical simulation state."""

import math

import rclpy
from geometry_msgs.msg import TransformStamped
from rclpy.node import Node
from tf2_ros import TransformBroadcaster
from uav_interfaces.msg import VerticalState
from visualization_msgs.msg import Marker


class RvizVisualizationNode(Node):
    """Streams marker and TF so UAV motion is visible in RViz."""

    def __init__(self) -> None:
        super().__init__("rviz_visualization")

        self.declare_parameter("world_frame", "map")
        self.declare_parameter("uav_frame", "simple_uav")
        self.declare_parameter("fixed_x_m", 0.0)
        self.declare_parameter("fixed_y_m", 0.0)
        self.declare_parameter("xy_motion_enabled", True)
        self.declare_parameter("xy_motion_start_delay_s", 3.0)
        self.declare_parameter("xy_motion_duration_s", 24.0)
        self.declare_parameter("xy_motion_radius_m", 2.0)
        self.declare_parameter("xy_motion_period_s", 12.0)
        self.declare_parameter("xy_motion_y_scale", 0.7)
        self.declare_parameter("marker_scale_m", 0.25)

        self._world_frame = str(self.get_parameter("world_frame").value)
        self._uav_frame = str(self.get_parameter("uav_frame").value)
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
        self._marker_scale = float(self.get_parameter("marker_scale_m").value)
        self._mission_t0_s = None

        self._marker_pub = self.create_publisher(Marker, "/uav/marker", 10)
        self._tf_broadcaster = TransformBroadcaster(self)

        self._vertical_state_sub = self.create_subscription(
            VerticalState,
            "/uav/vertical_state",
            self._vertical_state_callback,
            10,
        )

        self.get_logger().info("RvizVisualizationNode started.")

    def _compute_xy(self, now_s: float):
        if self._mission_t0_s is None:
            self._mission_t0_s = now_s

        if not self._xy_motion_enabled:
            return self._fixed_x, self._fixed_y

        elapsed = now_s - self._mission_t0_s
        t_xy = elapsed - self._xy_motion_start_delay_s
        if t_xy <= 0.0:
            return self._fixed_x, self._fixed_y

        if t_xy > self._xy_motion_duration_s:
            t_xy = self._xy_motion_duration_s

        omega = 2.0 * math.pi / self._xy_motion_period_s
        x = self._fixed_x + self._xy_motion_radius_m * math.cos(omega * t_xy)
        y = self._fixed_y + self._xy_motion_radius_m * self._xy_motion_y_scale * math.sin(omega * t_xy)
        return x, y

    def _vertical_state_callback(self, msg: VerticalState) -> None:
        now = self.get_clock().now().to_msg()
        now_s = self.get_clock().now().nanoseconds / 1e9
        x, y = self._compute_xy(now_s)
        z = float(msg.z)

        marker = Marker()
        marker.header.stamp = now
        marker.header.frame_id = self._world_frame
        marker.ns = "uav"
        marker.id = 0
        marker.type = Marker.SPHERE
        marker.action = Marker.ADD
        marker.pose.position.x = x
        marker.pose.position.y = y
        marker.pose.position.z = z
        marker.pose.orientation.w = 1.0
        marker.scale.x = self._marker_scale
        marker.scale.y = self._marker_scale
        marker.scale.z = self._marker_scale
        marker.color.r = 0.1
        marker.color.g = 0.75
        marker.color.b = 1.0
        marker.color.a = 1.0
        self._marker_pub.publish(marker)

        transform = TransformStamped()
        transform.header.stamp = now
        transform.header.frame_id = self._world_frame
        transform.child_frame_id = self._uav_frame
        transform.transform.translation.x = x
        transform.transform.translation.y = y
        transform.transform.translation.z = z
        transform.transform.rotation.w = 1.0
        self._tf_broadcaster.sendTransform(transform)


def main(args=None) -> None:
    rclpy.init(args=args)
    node = RvizVisualizationNode()
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
