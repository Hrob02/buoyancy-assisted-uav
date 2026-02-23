"""Unit tests for FlightControllerNode (no ROS runtime required)."""

import unittest
from unittest.mock import MagicMock, patch


class TestFlightControllerNodeImport(unittest.TestCase):
    """Smoke tests that do not require a live ROS 2 context."""

    def test_module_importable(self) -> None:
        """The node module must be importable without rclpy initialised."""
        with patch.dict(
            "sys.modules",
            {
                "rclpy": MagicMock(),
                "rclpy.node": MagicMock(),
                "std_msgs": MagicMock(),
                "std_msgs.msg": MagicMock(),
            },
        ):
            import importlib

            mod = importlib.import_module("uav_sim.flight_controller_node")
            self.assertTrue(hasattr(mod, "FlightControllerNode"))

    def test_main_callable(self) -> None:
        """main() must be a callable."""
        with patch.dict(
            "sys.modules",
            {
                "rclpy": MagicMock(),
                "rclpy.node": MagicMock(),
                "std_msgs": MagicMock(),
                "std_msgs.msg": MagicMock(),
            },
        ):
            import importlib

            mod = importlib.import_module("uav_sim.flight_controller_node")
            self.assertTrue(callable(mod.main))


if __name__ == "__main__":
    unittest.main()
