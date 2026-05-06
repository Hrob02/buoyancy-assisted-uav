"""ROS simulation control and visualization widget.

The widget talks to a helper process running inside WSL so the
Windows-side Qt application can interact with ROS 2 without needing
local ROS Python packages installed.
"""

from __future__ import annotations

import ctypes
import json
import sys
from pathlib import Path
from pathlib import PureWindowsPath
from typing import Callable, Optional

try:
    from PyQt6.QtCore import QEvent, QProcess, QProcessEnvironment, QTimer, Qt, pyqtSignal
    from PyQt6.QtWidgets import (
        QDoubleSpinBox,
        QFrame,
        QGroupBox,
        QHBoxLayout,
        QLabel,
        QPushButton,
        QSlider,
        QVBoxLayout,
        QWidget,
    )
except ImportError:
    from PySide6.QtCore import QEvent, QProcess, QProcessEnvironment, QTimer, Qt, Signal as pyqtSignal  # type: ignore[no-redef]
    from PySide6.QtWidgets import (  # type: ignore[no-redef]
        QDoubleSpinBox,
        QFrame,
        QGroupBox,
        QHBoxLayout,
        QLabel,
        QPushButton,
        QSlider,
        QVBoxLayout,
        QWidget,
    )


class ROSSimWidget(QWidget):
    """3D drone visualization and manual flight control widget."""

    launch_requested = pyqtSignal()
    stop_requested = pyqtSignal()

    def __init__(self, parent: Optional[QWidget] = None, repo_root: Optional[Path] = None) -> None:
        super().__init__(parent)
        self.repo_root = repo_root or Path(__file__).resolve().parents[2]
        self.setMinimumHeight(600)

        self.append_output: Optional[Callable[[str], None]] = None
        self.set_status: Optional[Callable[[str], None]] = None
        self.bridge_process: Optional[QProcess] = None
        self.bridge_connected = False
        self.sim_running = False
        self.launch_ready = False

        self.drone_x = 0.0
        self.drone_y = 0.0
        self.drone_z = 0.0
        self.drone_vz = 0.0
        self.drone_grounded = True
        self.trajectory_history_x: list[float] = []
        self.trajectory_history_y: list[float] = []
        self.trajectory_history_z: list[float] = []
        self.max_history = 200

        self.throttle_cmd = 0.0

        self.gazebo_hwnd: Optional[int] = None
        self.rviz_hwnd: Optional[int] = None
        self.gazebo_pending_attach = False
        self.rviz_pending_attach = False

        self._build_ui()

        self.attach_retry_timer = QTimer(self)
        self.attach_retry_timer.timeout.connect(self._process_pending_attachments)

        self.update_timer = QTimer(self)
        self.update_timer.timeout.connect(self._update_visualization)
        self.update_timer.start(100)

    def _build_ui(self) -> None:
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        layout.setContentsMargins(12, 12, 12, 12)

        button_group = QGroupBox("Simulation Control")
        button_layout = QHBoxLayout(button_group)
        self.launch_button = QPushButton("Launch Manual Simulation")
        self.launch_button.clicked.connect(self.launch_requested.emit)
        self.launch_button.setEnabled(False)
        self.stop_button = QPushButton("Stop Simulation")
        self.stop_button.clicked.connect(self.stop_requested.emit)
        self.stop_button.setEnabled(False)
        button_layout.addWidget(self.launch_button)
        button_layout.addWidget(self.stop_button)
        button_layout.addStretch(1)
        layout.addWidget(button_group)

        state_group = QGroupBox("Drone State")
        state_layout = QHBoxLayout(state_group)
        self.bridge_state_label = QLabel("Bridge: idle")
        self.setup_state_label = QLabel("Setup: preparing workspace")
        state_layout.addWidget(self.setup_state_label)
        self.state_z_label = QLabel("Z: -- m")
        self.state_vz_label = QLabel("Vz: -- m/s")
        self.state_x_label = QLabel("X: -- m")
        self.state_y_label = QLabel("Y: -- m")
        self.state_grounded_label = QLabel("Status: --")
        state_layout.addWidget(self.bridge_state_label)
        state_layout.addWidget(self.state_z_label)
        state_layout.addWidget(self.state_vz_label)
        state_layout.addWidget(self.state_x_label)
        state_layout.addWidget(self.state_y_label)
        state_layout.addWidget(self.state_grounded_label)
        state_layout.addStretch(1)
        layout.addWidget(state_group)

        control_group = QGroupBox("Flight Control")
        control_layout = QVBoxLayout(control_group)

        takeoff_row = QHBoxLayout()
        self.takeoff_button = QPushButton("Take Off (Throttle 0.55)")
        self.takeoff_button.clicked.connect(self.cmd_takeoff)
        self.takeoff_button.setEnabled(False)
        takeoff_row.addWidget(self.takeoff_button)
        takeoff_row.addStretch(1)
        control_layout.addLayout(takeoff_row)

        throttle_row = QHBoxLayout()
        throttle_row.addWidget(QLabel("Throttle:"))
        self.throttle_slider = QSlider()
        self.throttle_slider.setMinimum(0)
        self.throttle_slider.setMaximum(100)
        self.throttle_slider.setValue(0)
        self.throttle_slider.setTickPosition(QSlider.TickPosition.TicksBelow)
        self.throttle_slider.setTickInterval(10)
        self.throttle_slider.valueChanged.connect(self._on_throttle_slider_changed)
        throttle_row.addWidget(self.throttle_slider)
        self.throttle_spinbox = QDoubleSpinBox()
        self.throttle_spinbox.setMinimum(0.0)
        self.throttle_spinbox.setMaximum(1.0)
        self.throttle_spinbox.setSingleStep(0.01)
        self.throttle_spinbox.setValue(0.0)
        self.throttle_spinbox.setPrefix("T: ")
        self.throttle_spinbox.valueChanged.connect(self._on_throttle_spinbox_changed)
        throttle_row.addWidget(self.throttle_spinbox)
        control_layout.addLayout(throttle_row)

        landing_row = QHBoxLayout()
        self.land_button = QPushButton("Land (Throttle 0.0)")
        self.land_button.clicked.connect(self.cmd_land)
        self.land_button.setEnabled(False)
        landing_row.addWidget(self.land_button)
        landing_row.addStretch(1)
        control_layout.addLayout(landing_row)

        layout.addWidget(control_group)

        # Live Simulation Views - side-by-side Gazebo and RViz containers
        views_group = QGroupBox("Live Simulation Views")
        views_layout = QHBoxLayout(views_group)
        views_layout.setSpacing(12)
        views_layout.setContentsMargins(6, 6, 6, 6)

        # Gazebo panel
        gazebo_section = QVBoxLayout()
        gazebo_header = QHBoxLayout()
        gazebo_header.addWidget(QLabel("Gazebo"))
        self.gazebo_attached_label = QLabel("detached")
        self.gazebo_attached_label.setStyleSheet("color: #e08a00;")
        gazebo_header.addWidget(self.gazebo_attached_label)
        self.gazebo_attach_button = QPushButton("Attach")
        self.gazebo_attach_button.setMaximumWidth(80)
        self.gazebo_attach_button.clicked.connect(self._on_attach_gazebo_clicked)
        gazebo_header.addWidget(self.gazebo_attach_button)
        gazebo_header.addStretch(1)
        gazebo_section.addLayout(gazebo_header)
        self.gazebo_container = QFrame()
        self.gazebo_container.setAttribute(Qt.WidgetAttribute.WA_NativeWindow, True)
        self.gazebo_container.installEventFilter(self)
        self.gazebo_container.setMinimumHeight(250)
        self.gazebo_container.setStyleSheet("background: #0a0a0a; border: 2px solid #333;")
        gazebo_section.addWidget(self.gazebo_container, 1)
        views_layout.addLayout(gazebo_section)

        # RViz panel
        rviz_section = QVBoxLayout()
        rviz_header = QHBoxLayout()
        rviz_header.addWidget(QLabel("RViz"))
        self.rviz_attached_label = QLabel("detached")
        self.rviz_attached_label.setStyleSheet("color: #e08a00;")
        rviz_header.addWidget(self.rviz_attached_label)
        self.rviz_attach_button = QPushButton("Attach")
        self.rviz_attach_button.setMaximumWidth(80)
        self.rviz_attach_button.clicked.connect(self._on_attach_rviz_clicked)
        rviz_header.addWidget(self.rviz_attach_button)
        rviz_header.addStretch(1)
        rviz_section.addLayout(rviz_header)
        self.rviz_container = QFrame()
        self.rviz_container.setAttribute(Qt.WidgetAttribute.WA_NativeWindow, True)
        self.rviz_container.installEventFilter(self)
        self.rviz_container.setMinimumHeight(250)
        self.rviz_container.setStyleSheet("background: #0a0a0a; border: 2px solid #333;")
        rviz_section.addWidget(self.rviz_container, 1)
        views_layout.addLayout(rviz_section)

        layout.addWidget(views_group, 1)

    def set_hooks(self, append_output: Callable[[str], None], set_status: Callable[[str], None]) -> None:
        self.append_output = append_output
        self.set_status = set_status

    def set_setup_ready(self, ready: bool, message: str) -> None:
        self.launch_ready = ready
        self.setup_state_label.setText(f"Setup: {message}")
        self.launch_button.setEnabled(ready and not self.sim_running)

    def mark_simulation_running(self) -> None:
        self.sim_running = True
        self.launch_button.setEnabled(False)
        self.stop_button.setEnabled(True)
        self.takeoff_button.setEnabled(True)
        self.land_button.setEnabled(True)
        self.trajectory_history_x.clear()
        self.trajectory_history_y.clear()
        self.trajectory_history_z.clear()
        self._set_bridge_state("starting")
        self._start_bridge_process()
        # Auto-attach once windows are ready.
        self.gazebo_pending_attach = True
        self.rviz_pending_attach = True
        self._set_panel_status("gazebo", "waiting", "#e08a00")
        self._set_panel_status("rviz", "waiting", "#e08a00")
        self.attach_retry_timer.start(700)

    def mark_simulation_stopped(self) -> None:
        self.sim_running = False
        self.attach_retry_timer.stop()
        self.launch_button.setEnabled(self.launch_ready)
        self.stop_button.setEnabled(False)
        self.takeoff_button.setEnabled(False)
        self.land_button.setEnabled(False)
        self.bridge_connected = False
        self._set_bridge_state("idle")
        self._stop_bridge_process()
        self._detach_embedded_windows()
        self._set_panel_status("gazebo", "detached", "#e08a00")
        self._set_panel_status("rviz", "detached", "#e08a00")

    def _set_bridge_state(self, state: str) -> None:
        self.bridge_state_label.setText(f"Bridge: {state}")

    def _emit_log(self, text: str) -> None:
        if self.append_output is not None:
            self.append_output(text)

    def _emit_status(self, text: str) -> None:
        if self.set_status is not None:
            self.set_status(text)

    def _start_bridge_process(self) -> None:
        self._stop_bridge_process()
        process = QProcess(self)
        process.setWorkingDirectory(str(self.repo_root))
        process.setProgram("wsl")
        process.setArguments(["bash", "-lc", self._bridge_command()])
        process.setProcessEnvironment(QProcessEnvironment.systemEnvironment())
        process.readyReadStandardOutput.connect(self._read_bridge_stdout)
        process.readyReadStandardError.connect(self._read_bridge_stderr)
        process.finished.connect(self._bridge_finished)
        self.bridge_process = process
        self._emit_log("[start] ROS bridge helper")
        process.start()

    def _bridge_command(self) -> str:
        repo = str(self.repo_root)
        repo_wsl = repo.replace("\\", "/")
        if ":" in repo_wsl:
            win_path = PureWindowsPath(repo_wsl)
            drive = win_path.drive.rstrip(":").lower()
            tail = "/".join(part for part in win_path.parts[1:] if part)
            repo_wsl = f"/mnt/{drive}/{tail}"
        ros_ws_wsl = f"{repo_wsl}/ros_ws"
        bridge_script_wsl = f"{repo_wsl}/ui/ros_wsl_bridge.py"
        return (
            "set -eo pipefail; "
            f'cd "{ros_ws_wsl}"; '
            "source /opt/ros/humble/setup.bash; "
            "source install/setup.bash; "
            f'python3 "{bridge_script_wsl}"'
        )

    def _stop_bridge_process(self) -> None:
        if self.bridge_process is None:
            return
        if self.bridge_process.state() == QProcess.ProcessState.Running:
            self._send_bridge_message({"type": "shutdown", "payload": {}})
            self.bridge_process.terminate()
            if not self.bridge_process.waitForFinished(2000):
                self.bridge_process.kill()
                self.bridge_process.waitForFinished(1000)
        self.bridge_process = None

    def _read_bridge_stdout(self) -> None:
        if self.bridge_process is None:
            return
        data = bytes(self.bridge_process.readAllStandardOutput()).decode(errors="replace")
        for line in data.splitlines():
            self._handle_bridge_line(line)

    def _read_bridge_stderr(self) -> None:
        if self.bridge_process is None:
            return
        data = bytes(self.bridge_process.readAllStandardError()).decode(errors="replace")
        if data.strip():
            self._emit_log(data.rstrip())

    def _bridge_finished(self, exit_code: int, _exit_status) -> None:
        self.bridge_connected = False
        if self.sim_running:
            self._set_bridge_state(f"stopped ({exit_code})")
        else:
            self._set_bridge_state("idle")

    def _handle_bridge_line(self, line: str) -> None:
        if not line.strip():
            return
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            self._emit_log(line)
            return

        if message.get("type") != "telemetry":
            return

        payload = message.get("payload", {})
        self.bridge_connected = bool(payload.get("connected", False))
        self.drone_x = float(payload.get("x", 0.0))
        self.drone_y = float(payload.get("y", 0.0))
        self.drone_z = float(payload.get("z", 0.0))
        self.drone_vz = float(payload.get("vz", 0.0))
        self.drone_grounded = bool(payload.get("grounded", True))

        if self.bridge_connected:
            self._set_bridge_state("connected")
        elif self.sim_running:
            self._set_bridge_state("waiting for topics")

        self._record_trajectory_sample()

    def _record_trajectory_sample(self) -> None:
        if not self.bridge_connected:
            return
        if self.trajectory_history_x:
            last_dx = self.drone_x - self.trajectory_history_x[-1]
            last_dy = self.drone_y - self.trajectory_history_y[-1]
            last_dz = self.drone_z - self.trajectory_history_z[-1]
            if (last_dx * last_dx + last_dy * last_dy + last_dz * last_dz) <= 0.0025:
                return

        self.trajectory_history_x.append(self.drone_x)
        self.trajectory_history_y.append(self.drone_y)
        self.trajectory_history_z.append(self.drone_z)
        if len(self.trajectory_history_x) > self.max_history:
            self.trajectory_history_x.pop(0)
            self.trajectory_history_y.pop(0)
            self.trajectory_history_z.pop(0)

    def _update_visualization(self) -> None:
        self.state_z_label.setText(f"Z: {self.drone_z:.2f} m")
        self.state_vz_label.setText(f"Vz: {self.drone_vz:.2f} m/s")
        self.state_x_label.setText(f"X: {self.drone_x:.2f} m")
        self.state_y_label.setText(f"Y: {self.drone_y:.2f} m")
        grounded_text = "Grounded" if self.drone_grounded else "Flying"
        self.state_grounded_label.setText(f"Status: {grounded_text}")
        self._resize_embedded_windows()

    def eventFilter(self, watched, event) -> bool:  # type: ignore[override]
        if event.type() == QEvent.Type.Resize:
            if watched is self.gazebo_container:
                self._resize_window_to_container(self.gazebo_hwnd, self.gazebo_container)
            elif watched is self.rviz_container:
                self._resize_window_to_container(self.rviz_hwnd, self.rviz_container)
        return super().eventFilter(watched, event)

    def _on_attach_gazebo_clicked(self) -> None:
        self.gazebo_pending_attach = True
        self._set_panel_status("gazebo", "waiting", "#e08a00")
        self._process_pending_attachments()
        if self.sim_running and not self.attach_retry_timer.isActive():
            self.attach_retry_timer.start(700)

    def _on_attach_rviz_clicked(self) -> None:
        self.rviz_pending_attach = True
        self._set_panel_status("rviz", "waiting", "#e08a00")
        self._process_pending_attachments()
        if self.sim_running and not self.attach_retry_timer.isActive():
            self.attach_retry_timer.start(700)

    def _set_panel_status(self, panel: str, text: str, color: str) -> None:
        label = self.gazebo_attached_label if panel == "gazebo" else self.rviz_attached_label
        label.setText(text)
        label.setStyleSheet(f"color: {color};")

    def _process_pending_attachments(self) -> None:
        if not self.sim_running:
            return
        if self.gazebo_pending_attach:
            hwnd = self._find_top_level_window(("gazebo", "gzclient"))
            if hwnd is not None and self._attach_window_to_container(hwnd, self.gazebo_container):
                self.gazebo_hwnd = hwnd
                self.gazebo_pending_attach = False
                self._set_panel_status("gazebo", "attached", "#4a9eff")
            else:
                self._set_panel_status("gazebo", "waiting", "#e08a00")

        if self.rviz_pending_attach:
            hwnd = self._find_top_level_window(("rviz",))
            if hwnd is not None and self._attach_window_to_container(hwnd, self.rviz_container):
                self.rviz_hwnd = hwnd
                self.rviz_pending_attach = False
                self._set_panel_status("rviz", "attached", "#4a9eff")
            else:
                self._set_panel_status("rviz", "waiting", "#e08a00")

        if not self.gazebo_pending_attach and not self.rviz_pending_attach:
            self.attach_retry_timer.stop()

    def _find_top_level_window(self, keywords: tuple[str, ...]) -> Optional[int]:
        if sys.platform != "win32":
            return None

        user32 = ctypes.windll.user32
        matches: list[int] = []

        enum_proc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

        def callback(hwnd, _lparam):
            if not user32.IsWindowVisible(hwnd):
                return True
            title_len = user32.GetWindowTextLengthW(hwnd)
            if title_len <= 0:
                return True
            title_buf = ctypes.create_unicode_buffer(title_len + 1)
            user32.GetWindowTextW(hwnd, title_buf, title_len + 1)
            title = title_buf.value.strip().lower()
            if "buoyancy-assisted uav" in title:
                return True
            if any(keyword in title for keyword in keywords):
                matches.append(int(hwnd))
            return True

        user32.EnumWindows(enum_proc(callback), 0)
        return matches[0] if matches else None

    def _attach_window_to_container(self, hwnd: int, container: QFrame) -> bool:
        if sys.platform != "win32":
            return False

        user32 = ctypes.windll.user32
        GWL_STYLE = -16
        WS_CHILD = 0x40000000
        WS_VISIBLE = 0x10000000
        WS_CAPTION = 0x00C00000
        WS_THICKFRAME = 0x00040000
        WS_MINIMIZE = 0x20000000
        WS_MAXIMIZE = 0x01000000
        WS_SYSMENU = 0x00080000
        SWP_NOZORDER = 0x0004
        SWP_NOACTIVATE = 0x0010
        SWP_FRAMECHANGED = 0x0020
        SWP_SHOWWINDOW = 0x0040

        if not user32.IsWindow(ctypes.c_void_p(hwnd)):
            return False

        parent_hwnd = int(container.winId())
        style = int(user32.GetWindowLongW(ctypes.c_void_p(hwnd), GWL_STYLE))
        style = (style | WS_CHILD | WS_VISIBLE) & ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZE | WS_MAXIMIZE | WS_SYSMENU)
        user32.SetWindowLongW(ctypes.c_void_p(hwnd), GWL_STYLE, style)

        if not user32.SetParent(ctypes.c_void_p(hwnd), ctypes.c_void_p(parent_hwnd)):
            return False

        self._resize_window_to_container(hwnd, container)
        user32.SetWindowPos(
            ctypes.c_void_p(hwnd),
            None,
            0,
            0,
            container.width(),
            container.height(),
            SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW,
        )
        return True

    def _resize_window_to_container(self, hwnd: Optional[int], container: QFrame) -> None:
        if hwnd is None or sys.platform != "win32":
            return
        user32 = ctypes.windll.user32
        if not user32.IsWindow(ctypes.c_void_p(hwnd)):
            return
        user32.SetWindowPos(
            ctypes.c_void_p(hwnd),
            None,
            0,
            0,
            max(1, container.width()),
            max(1, container.height()),
            0x0004 | 0x0010,
        )

    def _resize_embedded_windows(self) -> None:
        self._resize_window_to_container(self.gazebo_hwnd, self.gazebo_container)
        self._resize_window_to_container(self.rviz_hwnd, self.rviz_container)

    def _detach_embedded_windows(self) -> None:
        if sys.platform != "win32":
            self.gazebo_hwnd = None
            self.rviz_hwnd = None
            return
        user32 = ctypes.windll.user32
        for hwnd in (self.gazebo_hwnd, self.rviz_hwnd):
            if hwnd is not None and user32.IsWindow(ctypes.c_void_p(hwnd)):
                user32.SetParent(ctypes.c_void_p(hwnd), None)
        self.gazebo_hwnd = None
        self.rviz_hwnd = None

    def _send_bridge_message(self, message: dict[str, object]) -> None:
        if self.bridge_process is None or self.bridge_process.state() != QProcess.ProcessState.Running:
            return
        self.bridge_process.write((json.dumps(message) + "\n").encode("utf-8"))

    def _publish_throttle(self) -> None:
        self._send_bridge_message({"type": "throttle", "payload": {"value": self.throttle_cmd}})

    def _on_throttle_slider_changed(self, value: int) -> None:
        self.throttle_spinbox.blockSignals(True)
        self.throttle_spinbox.setValue(value / 100.0)
        self.throttle_spinbox.blockSignals(False)
        self.throttle_cmd = value / 100.0
        self._publish_throttle()

    def _on_throttle_spinbox_changed(self, value: float) -> None:
        slider_value = int(round(value * 100))
        self.throttle_slider.blockSignals(True)
        self.throttle_slider.setValue(slider_value)
        self.throttle_slider.blockSignals(False)
        self.throttle_cmd = value
        self._publish_throttle()

    def cmd_takeoff(self) -> None:
        self.throttle_spinbox.setValue(0.55)

    def cmd_land(self) -> None:
        self.throttle_spinbox.setValue(0.0)

    def cleanup(self) -> None:
        self.mark_simulation_stopped()