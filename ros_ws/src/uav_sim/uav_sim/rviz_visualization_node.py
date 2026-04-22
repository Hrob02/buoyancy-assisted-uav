"""Publish RViz-friendly UAV marker and TF from vertical simulation state."""

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
        self.declare_parameter("marker_scale_m", 0.25)

        self._world_frame = str(self.get_parameter("world_frame").value)
        self._uav_frame = str(self.get_parameter("uav_frame").value)
        self._fixed_x = float(self.get_parameter("fixed_x_m").value)
        self._fixed_y = float(self.get_parameter("fixed_y_m").value)
        self._marker_scale = float(self.get_parameter("marker_scale_m").value)

        self._marker_pub = self.create_publisher(Marker, "/uav/marker", 10)
        self._tf_broadcaster = TransformBroadcaster(self)

        self._vertical_state_sub = self.create_subscription(
            VerticalState,
            "/uav/vertical_state",
            self._vertical_state_callback,
            10,
        )

        self.get_logger().info("RvizVisualizationNode started.")

    def _vertical_state_callback(self, msg: VerticalState) -> None:
        now = self.get_clock().now().to_msg()
        z = float(msg.z)

        marker = Marker()
        marker.header.stamp = now
        marker.header.frame_id = self._world_frame
        marker.ns = "uav"
        marker.id = 0
        marker.type = Marker.SPHERE
        marker.action = Marker.ADD
        marker.pose.position.x = self._fixed_x
        marker.pose.position.y = self._fixed_y
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
        transform.transform.translation.x = self._fixed_x
        transform.transform.translation.y = self._fixed_y
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
        rclpy.shutdown()


if __name__ == "__main__":
    main()
