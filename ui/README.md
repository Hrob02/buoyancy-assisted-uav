# Desktop UI (`ui/`)

Optional PyQt6 / PySide6 desktop application for visualising modelling results
and monitoring/controlling ROS 2 nodes.

## Status

**Scaffold only** — placeholder widgets and entry-point provided.

## Structure

```
ui/
├── widgets/
│   ├── __init__.py
│   ├── telemetry_widget.py     # Placeholder telemetry panel
│   └── plot_widget.py          # Placeholder matplotlib plot panel
├── app.py                      # Application entry-point
└── README.md
```

## Running

```bash
# Activate venv first
source .venv/bin/activate
pip install PyQt6  # or PySide6

python ui/app.py
```

## Connecting to ROS 2

Install `rclpy` in the same environment and use a background thread or
`QTimer` to spin the ROS 2 executor:

```python
import threading
import rclpy

def ros_spin(node):
    rclpy.spin(node)

thread = threading.Thread(target=ros_spin, args=(my_node,), daemon=True)
thread.start()
```
