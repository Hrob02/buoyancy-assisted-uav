"""WSL-side ROS bridge for the Windows Qt GUI.

This process runs inside WSL with the ROS environment sourced.
It streams telemetry as JSON lines on stdout and accepts JSON
commands on stdin so the Windows UI can control the simulation
without importing ROS packages locally.
"""

# pyright: reportMissingImports=false

from __future__ import annotations

import json
import sys
import threading
from dataclasses import asdict, dataclass

import rclpy
from gazebo_msgs.msg import ModelStates
from rclpy.node import Node
from std_msgs.msg import Float64
from uav_interfaces.msg import VerticalState


@dataclass
class TelemetryState:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0
    vz: float = 0.0
    grounded: bool = True
    connected: bool = False


class GuiBridgeNode(Node):
    def __init__(self) -> None:
        super().__init__("uav_sim_gui_bridge")
        self.state = TelemetryState()
        self._lock = threading.Lock()

        self.create_subscription(VerticalState, "/uav/vertical_state", self._on_vertical_state, 10)
        self.create_subscription(ModelStates, "/gazebo/model_states", self._on_model_states, 10)
        self._throttle_pub = self.create_publisher(Float64, "/uav/throttle_cmd", 10)
        self.create_timer(0.1, self._emit_state)

    def _on_vertical_state(self, msg: VerticalState) -> None:
        with self._lock:
            self.state.z = float(msg.z)
            self.state.vz = float(msg.vz)
            self.state.grounded = bool(msg.grounded)
            self.state.connected = True

    def _on_model_states(self, msg: ModelStates) -> None:
        try:
            index = msg.name.index("crazyflie")
        except ValueError:
            return

        pose = msg.pose[index]
        with self._lock:
            self.state.x = float(pose.position.x)
            self.state.y = float(pose.position.y)
            self.state.connected = True

    def _emit_state(self) -> None:
        with self._lock:
            payload = asdict(self.state)
        sys.stdout.write(json.dumps({"type": "telemetry", "payload": payload}) + "\n")
        sys.stdout.flush()

    def publish_throttle(self, value: float) -> None:
        msg = Float64()
        msg.data = float(value)
        self._throttle_pub.publish(msg)


def stdin_loop(node: GuiBridgeNode) -> None:
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue

        command_type = message.get("type")
        payload = message.get("payload", {})
        if command_type == "throttle":
            try:
                node.publish_throttle(float(payload.get("value", 0.0)))
            except (TypeError, ValueError):
                continue
        elif command_type == "shutdown":
            rclpy.try_shutdown()
            break


def main() -> None:
    rclpy.init()
    node = GuiBridgeNode()
    input_thread = threading.Thread(target=stdin_loop, args=(node,), daemon=True)
    input_thread.start()

    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == "__main__":
    main()