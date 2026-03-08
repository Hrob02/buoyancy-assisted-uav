"""Entry point for the buoyancy-assisted UAV desktop UI.

Requires PyQt6 or PySide6. Install with:
    pip install PyQt6
"""

# pyright: reportMissingImports=false

import json
import math
from pathlib import Path
import sys
import time

import matplotlib  # type: ignore[import-not-found]
import numpy as np  # type: ignore[import-not-found]

matplotlib.use("QtAgg")

from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg  # type: ignore[import-not-found]
from matplotlib.figure import Figure  # type: ignore[import-not-found]

try:
    import psutil  # type: ignore[import-not-found]
except ImportError:
    psutil = None


try:
    from PyQt6.QtCore import QEasingCurve, QProcess, QPropertyAnimation, QRect, QTimer
    from PyQt6.QtWidgets import (
        QApplication,
        QComboBox,
        QDoubleSpinBox,
        QFrame,
        QGroupBox,
        QHBoxLayout,
        QLabel,
        QListWidget,
        QMainWindow,
        QProgressBar,
        QPushButton,
        QStackedWidget,
        QTextEdit,
        QToolButton,
        QVBoxLayout,
        QWidget,
    )
except ImportError:
    try:
        from PySide6.QtCore import (  # type: ignore[no-redef]
            QEasingCurve,
            QProcess,
            QPropertyAnimation,
            QRect,
            QTimer,
        )
        from PySide6.QtWidgets import (  # type: ignore[no-redef]
            QApplication,
            QComboBox,
            QDoubleSpinBox,
            QFrame,
            QGroupBox,
            QHBoxLayout,
            QLabel,
            QListWidget,
            QMainWindow,
            QProgressBar,
            QPushButton,
            QStackedWidget,
            QTextEdit,
            QToolButton,
            QVBoxLayout,
            QWidget,
        )
    except ImportError:
        print("PyQt6 or PySide6 is required to run the UI.\nInstall with: pip install PyQt6")
        sys.exit(1)


class SlideDrawer(QFrame):
    def __init__(self, parent: QWidget, edge: str, size: int) -> None:
        super().__init__(parent)
        self.edge = edge
        self.drawer_size = size
        self.is_open = False
        self.animation = QPropertyAnimation(self, b"geometry", self)
        self.animation.setDuration(220)
        self.animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.setObjectName(f"drawer_{edge}")

    def _open_rect(self) -> QRect:
        parent_rect = self.parent().rect()
        if self.edge == "left":
            return QRect(0, 0, self.drawer_size, parent_rect.height())
        if self.edge == "right":
            return QRect(parent_rect.width() - self.drawer_size, 0, self.drawer_size, parent_rect.height())
        if self.edge == "top":
            return QRect(0, 0, parent_rect.width(), self.drawer_size)
        return QRect(0, parent_rect.height() - self.drawer_size, parent_rect.width(), self.drawer_size)

    def _closed_rect(self) -> QRect:
        parent_rect = self.parent().rect()
        if self.edge == "left":
            return QRect(-self.drawer_size, 0, self.drawer_size, parent_rect.height())
        if self.edge == "right":
            return QRect(parent_rect.width(), 0, self.drawer_size, parent_rect.height())
        if self.edge == "top":
            return QRect(0, -self.drawer_size, parent_rect.width(), self.drawer_size)
        return QRect(0, parent_rect.height(), parent_rect.width(), self.drawer_size)

    def sync_geometry(self) -> None:
        self.setGeometry(self._open_rect() if self.is_open else self._closed_rect())

    def set_open(self, open_state: bool) -> None:
        if self.is_open == open_state:
            self.sync_geometry()
            return
        self.is_open = open_state
        self.animation.stop()
        self.animation.setStartValue(self.geometry())
        self.animation.setEndValue(self._open_rect() if self.is_open else self._closed_rect())
        self.animation.start()

    def toggle(self) -> None:
        self.set_open(not self.is_open)


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.repo_root = Path(__file__).resolve().parents[1]
        self.running_processes: list[QProcess] = []
        self.task_defs = self._load_tasks()
        self.page_lookup: dict[str, int] = {}
        self.dark_mode = True
        self.left_collapsed = False
        self._fallback_tick = 0
        self.left_nav_widgets: list[QWidget] = []
        self.sidebar_expanded_width = 260
        self.sidebar_collapsed_width = 72

        self.cpu_label: QLabel
        self.cpu_bar: QProgressBar
        self.ram_label: QLabel
        self.ram_bar: QProgressBar
        self.disk_label: QLabel
        self.disk_bar: QProgressBar
        self.status_label: QLabel
        self.output: QTextEdit
        self.sidebar: QFrame
        self.sidebar_anim: QPropertyAnimation
        self.sidebar_title: QLabel
        self.sidebar_toggle_button: QPushButton
        self.menu_nav_btn: QPushButton
        self.airflow_nav_btn: QPushButton
        self.output_nav_btn: QPushButton

        self.setWindowTitle("Buoyancy-Assisted UAV")
        self.setMinimumSize(1120, 760)

        self.root = QWidget(self)
        root_layout = QVBoxLayout(self.root)
        root_layout.setContentsMargins(12, 12, 12, 12)
        root_layout.setSpacing(10)

        self._build_top_bar(root_layout)
        self._build_main_pages(root_layout)

        self.setCentralWidget(self.root)
        self._build_drawers()
        self._apply_theme()

        self.monitor_timer = QTimer(self)
        self.monitor_timer.timeout.connect(self.update_system_monitors)
        self.monitor_timer.start(1200)
        self.update_system_monitors()

    def _build_top_bar(self, parent_layout: QVBoxLayout) -> None:
        top_bar = QFrame()
        top_bar.setObjectName("topBar")
        layout = QHBoxLayout(top_bar)
        layout.setContentsMargins(12, 10, 12, 10)
        layout.setSpacing(8)

        self.left_drawer_button = QToolButton()
        self.left_drawer_button.setText("◀")
        self.left_drawer_button.setToolTip("Collapse sidebar")

        self.right_drawer_button = QToolButton()
        self.right_drawer_button.setText("⫶")
        self.right_drawer_button.setToolTip("Toggle right drawer")

        self.top_drawer_button = QToolButton()
        self.top_drawer_button.setText("⮝")
        self.top_drawer_button.setToolTip("Toggle top drawer")

        self.bottom_drawer_button = QToolButton()
        self.bottom_drawer_button.setText("⮟")
        self.bottom_drawer_button.setToolTip("Toggle output drawer")

        self.theme_button = QPushButton("Dark Mode")
        self.theme_button.setCheckable(True)
        self.theme_button.setChecked(True)
        self.theme_button.clicked.connect(self.toggle_theme)

        title = QLabel("Buoyancy-Assisted UAV")
        title.setObjectName("appTitle")

        layout.addWidget(self.left_drawer_button)
        layout.addWidget(self.right_drawer_button)
        layout.addWidget(self.top_drawer_button)
        layout.addWidget(self.bottom_drawer_button)
        layout.addSpacing(10)
        layout.addWidget(title)
        layout.addStretch(1)
        layout.addWidget(self.theme_button)

        parent_layout.addWidget(top_bar)

    def _build_main_pages(self, parent_layout: QVBoxLayout) -> None:
        content_row = QHBoxLayout()
        content_row.setSpacing(10)

        self._build_docked_sidebar(content_row)

        self.pages = QStackedWidget()

        menu_page = QWidget()
        menu_layout = QVBoxLayout(menu_page)

        heading = QLabel("Menu")
        heading.setObjectName("pageHeading")
        menu_layout.addWidget(heading)

        action_group = QGroupBox("Actions")
        action_layout = QHBoxLayout(action_group)
        self.action_combo = QComboBox()
        self.action_combo.addItems(["Run ROS Sim", "Run MATLAB Sim", "Control Drone (Placeholder)"])
        run_action_button = QPushButton("Run Selected Action")
        run_action_button.clicked.connect(self.run_selected_action)
        action_layout.addWidget(self.action_combo)
        action_layout.addWidget(run_action_button)
        menu_layout.addWidget(action_group)

        tests_group = QGroupBox("Tests")
        tests_layout = QVBoxLayout(tests_group)
        self.test_menu_list = QListWidget()
        self.test_menu_list.addItems(
            [
                "Airflow tunnel test (shape + conditions)",
                "Additional component effect on aerodynamics",
                "Weight-to-helium ratio sweep",
                "Duty-cycled thrust vs power consumption",
            ]
        )
        open_test_button = QPushButton("Open Selected Test")
        open_test_button.clicked.connect(self.open_selected_test_page)
        tests_layout.addWidget(self.test_menu_list)
        tests_layout.addWidget(open_test_button)
        menu_layout.addWidget(tests_group)
        menu_layout.addStretch(1)

        menu_idx = self.pages.addWidget(menu_page)
        self.page_lookup["Menu"] = menu_idx

        airflow_page = QWidget()
        airflow_layout = QVBoxLayout(airflow_page)

        airflow_title = QLabel("Airflow Tunnel Test")
        airflow_title.setObjectName("pageHeading")
        airflow_layout.addWidget(airflow_title)

        controls_row = QHBoxLayout()
        self.condition_combo = QComboBox()
        self.condition_combo.addItems(["Calm", "Cruise", "High Wind", "Crosswind", "Gust"])

        self.shape_combo = QComboBox()
        self.shape_combo.addItems(["Baseline", "Slender", "Blunt"])

        self.component_combo = QComboBox()
        self.component_combo.addItems(["No Extra Components", "Sensor Pod", "Payload Pod"])

        self.helium_ratio_spin = QDoubleSpinBox()
        self.helium_ratio_spin.setRange(0.10, 0.40)
        self.helium_ratio_spin.setSingleStep(0.01)
        self.helium_ratio_spin.setValue(0.18)
        self.helium_ratio_spin.setPrefix("He ratio ")

        controls_row.addWidget(QLabel("Condition"))
        controls_row.addWidget(self.condition_combo)
        controls_row.addWidget(QLabel("Shape"))
        controls_row.addWidget(self.shape_combo)
        controls_row.addWidget(QLabel("Components"))
        controls_row.addWidget(self.component_combo)
        controls_row.addWidget(self.helium_ratio_spin)

        button_row = QHBoxLayout()
        update_graph_button = QPushButton("Update Graph")
        update_graph_button.clicked.connect(self.update_wind_plot)
        open_matlab_button = QPushButton("Open MATLAB Wind Test")
        open_matlab_button.clicked.connect(self.run_matlab_task)
        back_menu_button = QPushButton("Back to Menu")
        back_menu_button.clicked.connect(lambda: self.pages.setCurrentIndex(self.page_lookup["Menu"]))
        button_row.addWidget(update_graph_button)
        button_row.addWidget(open_matlab_button)
        button_row.addWidget(back_menu_button)

        self.figure = Figure(figsize=(7.5, 4.5), tight_layout=True)
        self.canvas = FigureCanvasQTAgg(self.figure)
        self.ax = self.figure.add_subplot(111, projection="3d")

        airflow_layout.addLayout(controls_row)
        airflow_layout.addLayout(button_row)
        airflow_layout.addWidget(self.canvas)

        airflow_idx = self.pages.addWidget(airflow_page)
        self.page_lookup["Airflow tunnel test (shape + conditions)"] = airflow_idx

        placeholders = [
            "Additional component effect on aerodynamics",
            "Weight-to-helium ratio sweep",
            "Duty-cycled thrust vs power consumption",
        ]
        for name in placeholders:
            page = QWidget()
            layout = QVBoxLayout(page)
            label = QLabel(name)
            label.setObjectName("pageHeading")
            description = QLabel("Placeholder page. Associated graphs and controls will be added next.")
            back = QPushButton("Back to Menu")
            back.clicked.connect(lambda _, n="Menu": self.pages.setCurrentIndex(self.page_lookup[n]))
            layout.addWidget(label)
            layout.addWidget(description)
            layout.addWidget(back)
            layout.addStretch(1)
            idx = self.pages.addWidget(page)
            self.page_lookup[name] = idx

        content_row.addWidget(self.pages, 1)
        parent_layout.addLayout(content_row)
        self.pages.setCurrentIndex(self.page_lookup["Menu"])
        self.update_wind_plot()

    def _build_docked_sidebar(self, parent_layout: QHBoxLayout) -> None:
        self.sidebar = QFrame()
        self.sidebar.setObjectName("dockSidebar")
        self.sidebar.setMinimumWidth(self.sidebar_collapsed_width)
        self.sidebar.setMaximumWidth(self.sidebar_expanded_width)

        self.sidebar_anim = QPropertyAnimation(self.sidebar, b"maximumWidth", self)
        self.sidebar_anim.setDuration(180)
        self.sidebar_anim.setEasingCurve(QEasingCurve.Type.OutCubic)

        layout = QVBoxLayout(self.sidebar)
        layout.setContentsMargins(10, 12, 10, 12)
        layout.setSpacing(8)

        self.sidebar_title = QLabel("Navigation")
        self.sidebar_title.setObjectName("drawerTitle")

        self.sidebar_toggle_button = QPushButton("◀")
        self.sidebar_toggle_button.setToolTip("Collapse sidebar")
        self.sidebar_toggle_button.clicked.connect(self.toggle_left_collapse)

        separator = QFrame()
        separator.setFrameShape(QFrame.Shape.HLine)

        self.menu_nav_btn = QPushButton("⌂  Menu")
        self.menu_nav_btn.setToolTip("Open Menu")
        self.menu_nav_btn.clicked.connect(lambda: self.pages.setCurrentIndex(self.page_lookup["Menu"]))

        self.airflow_nav_btn = QPushButton("🌀  Airflow")
        self.airflow_nav_btn.setToolTip("Open Airflow Test")
        self.airflow_nav_btn.clicked.connect(
            lambda: self.pages.setCurrentIndex(self.page_lookup["Airflow tunnel test (shape + conditions)"])
        )

        self.output_nav_btn = QPushButton("▤  Output")
        self.output_nav_btn.setToolTip("Toggle output panel")
        self.output_nav_btn.clicked.connect(self.toggle_output_drawer)

        layout.addWidget(self.sidebar_title)
        layout.addWidget(self.sidebar_toggle_button)
        layout.addWidget(separator)
        layout.addWidget(self.menu_nav_btn)
        layout.addWidget(self.airflow_nav_btn)
        layout.addWidget(self.output_nav_btn)
        layout.addStretch(1)

        self.left_nav_widgets = [self.sidebar_title, self.menu_nav_btn, self.airflow_nav_btn, self.output_nav_btn]
        parent_layout.addWidget(self.sidebar)

    def _build_drawers(self) -> None:
        self.right_drawer = SlideDrawer(self.root, "right", 280)
        self.top_drawer = SlideDrawer(self.root, "top", 140)
        self.bottom_drawer = SlideDrawer(self.root, "bottom", 240)

        self._populate_right_drawer()
        self._populate_top_drawer()
        self._populate_bottom_drawer()

        self.left_drawer_button.clicked.connect(self.toggle_left_collapse)
        self.right_drawer_button.clicked.connect(self.right_drawer.toggle)
        self.top_drawer_button.clicked.connect(self.top_drawer.toggle)
        self.bottom_drawer_button.clicked.connect(self.bottom_drawer.toggle)

        self.right_drawer.raise_()
        self.top_drawer.raise_()
        self.bottom_drawer.raise_()

        QTimer.singleShot(0, self._sync_drawers)

    def _populate_right_drawer(self) -> None:
        layout = QVBoxLayout(self.right_drawer)
        layout.setContentsMargins(14, 16, 14, 16)

        title = QLabel("System Monitor")
        title.setObjectName("drawerTitle")

        self.cpu_label = QLabel("CPU: --%")
        self.cpu_bar = QProgressBar()

        self.ram_label = QLabel("RAM: --%")
        self.ram_bar = QProgressBar()

        self.disk_label = QLabel("Disk: --%")
        self.disk_bar = QProgressBar()

        for bar in (self.cpu_bar, self.ram_bar, self.disk_bar):
            bar.setRange(0, 100)

        note = QLabel("Later this panel can display UAV vitals.")
        note.setWordWrap(True)

        layout.addWidget(title)
        layout.addWidget(self.cpu_label)
        layout.addWidget(self.cpu_bar)
        layout.addWidget(self.ram_label)
        layout.addWidget(self.ram_bar)
        layout.addWidget(self.disk_label)
        layout.addWidget(self.disk_bar)
        layout.addWidget(note)
        layout.addStretch(1)

    def _populate_top_drawer(self) -> None:
        layout = QVBoxLayout(self.top_drawer)
        layout.setContentsMargins(16, 10, 16, 10)

        row = QHBoxLayout()
        quick_menu = QPushButton("Menu")
        quick_menu.clicked.connect(lambda: self.pages.setCurrentIndex(self.page_lookup["Menu"]))
        quick_airflow = QPushButton("Airflow")
        quick_airflow.clicked.connect(
            lambda: self.pages.setCurrentIndex(self.page_lookup["Airflow tunnel test (shape + conditions)"])
        )
        quick_output = QPushButton("Output")
        quick_output.clicked.connect(self.bottom_drawer.toggle)

        sep1 = QFrame()
        sep1.setFrameShape(QFrame.Shape.VLine)
        sep2 = QFrame()
        sep2.setFrameShape(QFrame.Shape.VLine)

        row.addWidget(quick_menu)
        row.addWidget(sep1)
        row.addWidget(quick_airflow)
        row.addWidget(sep2)
        row.addWidget(quick_output)
        row.addStretch(1)

        info = QLabel("Quick actions drawer")

        layout.addLayout(row)
        layout.addWidget(info)

    def _populate_bottom_drawer(self) -> None:
        layout = QVBoxLayout(self.bottom_drawer)
        layout.setContentsMargins(14, 12, 14, 12)

        title_row = QHBoxLayout()
        title = QLabel("Output")
        title.setObjectName("drawerTitle")
        close_btn = QPushButton("Hide")
        close_btn.clicked.connect(self.bottom_drawer.toggle)
        title_row.addWidget(title)
        title_row.addStretch(1)
        title_row.addWidget(close_btn)

        self.status_label = QLabel("Ready")
        self.output = QTextEdit()
        self.output.setReadOnly(True)

        layout.addLayout(title_row)
        layout.addWidget(self.status_label)
        layout.addWidget(self.output)

    def _load_tasks(self) -> dict[str, dict[str, object]]:
        tasks_file = self.repo_root / ".vscode" / "tasks.json"
        if not tasks_file.exists():
            return {}
        try:
            content = json.loads(tasks_file.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}

        task_map: dict[str, dict[str, object]] = {}
        for task in content.get("tasks", []):
            label = task.get("label")
            if isinstance(label, str):
                task_map[label] = task
        return task_map

    def append_output(self, text: str) -> None:
        if text.strip():
            self.output.append(text.rstrip())

    def run_selected_action(self) -> None:
        selection = self.action_combo.currentText()
        if selection == "Control Drone (Placeholder)":
            self.status_label.setText("Control Drone not implemented yet")
            self.append_output("[placeholder] Drone control UI will be added in a later phase.")
            return

        task = self.task_defs.get(selection)
        if task is None:
            self.status_label.setText(f"Task not found: {selection}")
            self.append_output(f"[error] Could not find '{selection}' in .vscode/tasks.json")
            return

        program = task.get("command")
        args = task.get("args", [])
        if not isinstance(program, str):
            self.status_label.setText(f"Invalid task command: {selection}")
            self.append_output(f"[error] '{selection}' has an invalid command.")
            return
        if not isinstance(args, list) or not all(isinstance(arg, str) for arg in args):
            self.status_label.setText(f"Invalid task args: {selection}")
            self.append_output(f"[error] '{selection}' has invalid args.")
            return

        self.start_process(selection, program, args)

    def open_selected_test_page(self) -> None:
        selected = self.test_menu_list.currentItem()
        if selected is None:
            self.status_label.setText("No test selected")
            self.append_output("Select a test from the menu first.")
            return

        test_name = selected.text()
        page_idx = self.page_lookup.get(test_name)
        if page_idx is None:
            self.status_label.setText(f"Unknown test: {test_name}")
            self.append_output(f"Unknown test selection: {test_name}")
            return

        self.pages.setCurrentIndex(page_idx)
        if test_name == "Airflow tunnel test (shape + conditions)":
            self.update_wind_plot()
        self.status_label.setText(f"Opened test page: {test_name}")
        self.append_output(f"Opened test page: {test_name}")

    def run_matlab_task(self) -> None:
        task = self.task_defs.get("Run MATLAB Sim")
        if task is None:
            self.append_output("Task 'Run MATLAB Sim' not found in .vscode/tasks.json")
            self.status_label.setText("MATLAB task missing")
            return

        program = task.get("command")
        args = task.get("args", [])
        if not isinstance(program, str) or not isinstance(args, list) or not all(
            isinstance(arg, str) for arg in args
        ):
            self.append_output("Invalid 'Run MATLAB Sim' task format.")
            self.status_label.setText("Invalid MATLAB task")
            return

        self.start_process("Run MATLAB Sim", program, args)

    def update_wind_plot(self) -> None:
        condition_name = self.condition_combo.currentText()
        shape_name = self.shape_combo.currentText()
        component_name = self.component_combo.currentText()
        helium_ratio = float(self.helium_ratio_spin.value())

        base_speed_map = {
            "Calm": (6.0, 0.0),
            "Cruise": (12.0, 0.0),
            "High Wind": (20.0, 0.0),
            "Crosswind": (12.0, 20.0),
            "Gust": (16.0, -12.0),
        }
        shape_scale_map = {"Baseline": 1.00, "Slender": 0.90, "Blunt": 1.15}
        component_factor_map = {
            "No Extra Components": 0.00,
            "Sensor Pod": 0.12,
            "Payload Pod": 0.24,
        }

        wind_speed, yaw_deg = base_speed_map.get(condition_name, (12.0, 0.0))
        shape_scale = shape_scale_map.get(shape_name, 1.0)
        component_factor = component_factor_map.get(component_name, 0.0)

        x = np.linspace(-2.0, 2.0, 24)
        y = np.linspace(-1.3, 1.3, 16)
        z = np.linspace(-0.9, 0.9, 12)
        xx, yy, zz = np.meshgrid(x, y, z)

        theta = np.deg2rad(yaw_deg)
        u0 = wind_speed * np.cos(theta)
        v0 = wind_speed * np.sin(theta)

        a = 0.42 * shape_scale
        b = 0.16 / shape_scale
        c = 0.12
        eps = 1e-6
        r2 = (xx / (a + eps)) ** 2 + (yy / (b + eps)) ** 2 + (zz / (c + eps)) ** 2 + eps

        blockage = (0.45 + 0.6 * component_factor) * np.exp(-1.6 * r2)
        swirl = (0.10 + 0.30 * component_factor + 0.45 * max(helium_ratio - 0.18, 0.0)) * np.exp(
            -2.2 * r2
        )

        uu = u0 * (1 - blockage) - swirl * yy
        vv = v0 * (1 - blockage) + swirl * xx
        ww = 0.20 * swirl * zz

        self.ax.clear()
        stride = 2
        self.ax.quiver(
            xx[::stride, ::stride, ::stride],
            yy[::stride, ::stride, ::stride],
            zz[::stride, ::stride, ::stride],
            uu[::stride, ::stride, ::stride],
            vv[::stride, ::stride, ::stride],
            ww[::stride, ::stride, ::stride],
            length=0.09,
            normalize=True,
            color="#2d2d2d",
            linewidth=0.45,
        )

        u = np.linspace(0.0, 2.0 * np.pi, 52)
        v = np.linspace(0.0, np.pi, 26)
        uu_s, vv_s = np.meshgrid(u, v)
        xs = a * np.cos(uu_s) * np.sin(vv_s)
        ys = b * np.sin(uu_s) * np.sin(vv_s)
        zs = c * np.cos(vv_s)

        vhat = np.array([np.cos(theta), np.sin(theta), 0.0])
        nx = xs / (a + eps)
        ny = ys / (b + eps)
        nz = zs / (c + eps)
        norm = np.sqrt(nx**2 + ny**2 + nz**2) + eps
        nx /= norm
        ny /= norm
        nz /= norm

        head_on = np.maximum(-(nx * vhat[0] + ny * vhat[1] + nz * vhat[2]), 0.0)
        interference_scale = 1.0 + 0.75 * component_factor + 0.60 * max(helium_ratio - 0.18, 0.0)
        resistance_idx = interference_scale * (head_on**1.4)

        cmap = matplotlib.colormaps.get_cmap("turbo")
        vmax = 1.8
        facecolors = cmap(np.clip(resistance_idx / vmax, 0.0, 1.0))
        self.ax.plot_surface(
            xs,
            ys,
            zs,
            facecolors=facecolors,
            linewidth=0,
            antialiased=True,
            shade=False,
            alpha=0.98,
        )

        self.ax.set_box_aspect((4.0, 2.6, 1.8))
        self.ax.set_xlim(-2.0, 2.0)
        self.ax.set_ylim(-1.3, 1.3)
        self.ax.set_zlim(-0.9, 0.9)
        self.ax.set_xlabel("x [m]")
        self.ax.set_ylabel("y [m]")
        self.ax.set_zlabel("z [m]")
        self.ax.view_init(elev=23, azim=35)
        self.ax.set_title(
            f"3D Airflow | {condition_name}, {shape_name}, {component_name}, He={helium_ratio:.2f}"
        )

        if self.figure.axes and len(self.figure.axes) > 1:
            for extra_ax in self.figure.axes[1:]:
                extra_ax.remove()

        norm_map = matplotlib.colors.Normalize(vmin=0.0, vmax=vmax)
        scalar_map = matplotlib.cm.ScalarMappable(norm=norm_map, cmap="turbo")
        scalar_map.set_array([])
        self.figure.colorbar(
            scalar_map,
            ax=self.ax,
            fraction=0.046,
            pad=0.04,
            label="Surface resistance / interference index",
        )
        self.canvas.draw_idle()

    def start_process(self, label: str, program: str, args: list[str]) -> None:
        process = QProcess(self)
        process.setWorkingDirectory(str(self.repo_root))
        process.setProgram(program)
        process.setArguments(args)

        process.readyReadStandardOutput.connect(lambda p=process: self._read_process_output(p, False))
        process.readyReadStandardError.connect(lambda p=process: self._read_process_output(p, True))
        process.finished.connect(
            lambda exit_code, exit_status, p=process, task_label=label: self._process_finished(
                p, task_label, exit_code, exit_status
            )
        )
        process.errorOccurred.connect(
            lambda error, task_label=label: self._process_error(task_label, error)
        )

        self.running_processes.append(process)
        self.status_label.setText(f"Running: {label}")
        self.append_output(f"[start] {label}: {program} {' '.join(args)}")
        process.start()

    def _read_process_output(self, process: QProcess, is_error: bool) -> None:
        data = process.readAllStandardError() if is_error else process.readAllStandardOutput()
        text = bytes(data).decode(errors="replace")
        self.append_output(text)

    def _process_finished(
        self,
        process: QProcess,
        label: str,
        exit_code: int,
        exit_status: QProcess.ExitStatus,
    ) -> None:
        status_name = "normal" if exit_status == QProcess.ExitStatus.NormalExit else "crash"
        self.status_label.setText(f"Finished: {label} (code {exit_code})")
        self.append_output(f"[done] {label} exited with code {exit_code} ({status_name})")
        if process in self.running_processes:
            self.running_processes.remove(process)

    def _process_error(self, label: str, error: QProcess.ProcessError) -> None:
        self.status_label.setText(f"Process error: {label}")
        self.append_output(f"[error] {label} process error: {error}")

    def update_system_monitors(self) -> None:
        if psutil is not None:
            cpu = float(psutil.cpu_percent(interval=None))
            ram = float(psutil.virtual_memory().percent)
            disk = float(psutil.disk_usage(str(self.repo_root)).percent)
        else:
            self._fallback_tick += 1
            t = time.time() + self._fallback_tick
            cpu = 30 + 22 * math.sin(t * 0.7)
            ram = 45 + 18 * math.sin(t * 0.4 + 1.3)
            disk = 62 + 10 * math.sin(t * 0.2 + 0.6)

        cpu_i = int(max(0, min(100, cpu)))
        ram_i = int(max(0, min(100, ram)))
        disk_i = int(max(0, min(100, disk)))

        self.cpu_label.setText(f"CPU: {cpu_i}%")
        self.ram_label.setText(f"RAM: {ram_i}%")
        self.disk_label.setText(f"Disk: {disk_i}%")

        self.cpu_bar.setValue(cpu_i)
        self.ram_bar.setValue(ram_i)
        self.disk_bar.setValue(disk_i)

    def toggle_left_collapse(self) -> None:
        self.left_collapsed = not self.left_collapsed
        target_width = self.sidebar_collapsed_width if self.left_collapsed else self.sidebar_expanded_width

        self.sidebar_anim.stop()
        self.sidebar_anim.setStartValue(self.sidebar.maximumWidth())
        self.sidebar_anim.setEndValue(target_width)
        self.sidebar_anim.start()

        if self.left_collapsed:
            self.left_drawer_button.setText("▶")
            self.left_drawer_button.setToolTip("Expand sidebar")
            self.sidebar_toggle_button.setText("▶")
            self.sidebar_toggle_button.setToolTip("Expand sidebar")
            self.sidebar_title.hide()
            self.menu_nav_btn.setText("⌂")
            self.airflow_nav_btn.setText("🌀")
            self.output_nav_btn.setText("▤")
        else:
            self.left_drawer_button.setText("◀")
            self.left_drawer_button.setToolTip("Collapse sidebar")
            self.sidebar_toggle_button.setText("◀")
            self.sidebar_toggle_button.setToolTip("Collapse sidebar")
            self.sidebar_title.show()
            self.menu_nav_btn.setText("⌂  Menu")
            self.airflow_nav_btn.setText("🌀  Airflow")
            self.output_nav_btn.setText("▤  Output")

    def toggle_output_drawer(self) -> None:
        if hasattr(self, "bottom_drawer"):
            self.bottom_drawer.toggle()

    def toggle_theme(self) -> None:
        self.dark_mode = self.theme_button.isChecked()
        self.theme_button.setText("Dark Mode" if self.dark_mode else "Light Mode")
        self._apply_theme()

    def _apply_theme(self) -> None:
        if self.dark_mode:
            bg = "#0f1117"
            card = "#171a23"
            card2 = "#1d2130"
            border = "#2c3245"
            text = "#edf2ff"
            muted = "#aeb8d2"
            accent = "#5d8dff"
        else:
            bg = "#f4f6fb"
            card = "#ffffff"
            card2 = "#eef2ff"
            border = "#ced7ef"
            text = "#1e2638"
            muted = "#4a5a7a"
            accent = "#2f61e6"

        style = f"""
        QWidget {{
            background: {bg};
            color: {text};
            font-size: 13px;
        }}
        #topBar {{
            background: {card};
            border: 1px solid {border};
            border-radius: 14px;
        }}
        #appTitle {{
            font-size: 17px;
            font-weight: 700;
        }}
        #pageHeading, #drawerTitle {{
            font-size: 16px;
            font-weight: 700;
        }}
        QGroupBox {{
            border: 1px solid {border};
            border-radius: 14px;
            margin-top: 10px;
            padding: 10px;
            background: {card};
        }}
        QGroupBox::title {{
            subcontrol-origin: margin;
            left: 12px;
            padding: 0 4px;
            color: {muted};
        }}
        QPushButton, QToolButton, QComboBox, QDoubleSpinBox, QListWidget, QTextEdit, QProgressBar {{
            border: 1px solid {border};
            border-radius: 12px;
            padding: 8px 10px;
            background: {card};
        }}
        QPushButton:hover, QToolButton:hover {{
            border: 1px solid {accent};
            background: {card2};
        }}
        QPushButton:pressed, QToolButton:pressed {{
            background: {accent};
            color: white;
        }}
        QProgressBar::chunk {{
            border-radius: 10px;
            background: {accent};
        }}
        QFrame#drawer_right, QFrame#drawer_top, QFrame#drawer_bottom, QFrame#dockSidebar {{
            background: {card};
            border: 1px solid {border};
            border-radius: 14px;
        }}
        """
        self.setStyleSheet(style)

    def _sync_drawers(self) -> None:
        self.right_drawer.sync_geometry()
        self.top_drawer.sync_geometry()
        self.bottom_drawer.sync_geometry()

    def resizeEvent(self, event) -> None:  # type: ignore[override]
        super().resizeEvent(event)
        self._sync_drawers()


def main() -> None:
    app = QApplication(sys.argv)
    base_font = app.font()
    if base_font.pointSize() <= 0:
        base_font.setPointSize(10)
        app.setFont(base_font)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
