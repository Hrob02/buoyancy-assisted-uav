"""Entry point for the buoyancy-assisted UAV desktop UI.

Requires PyQt6 or PySide6. Install with:
    pip install PyQt6
"""

import sys


def main() -> None:
    align_center = None
    try:
        from PyQt6.QtCore import Qt
        from PyQt6.QtWidgets import QApplication, QLabel, QMainWindow

        align_center = Qt.AlignmentFlag.AlignCenter
    except ImportError:
        try:
            from PySide6.QtCore import Qt  # type: ignore[no-redef]
            from PySide6.QtWidgets import (  # type: ignore[no-redef]
                QApplication,
                QLabel,
                QMainWindow,
            )

            align_center = Qt.AlignCenter
        except ImportError:
            print("PyQt6 or PySide6 is required to run the UI.\n" "Install with: pip install PyQt6")
            sys.exit(1)

    app = QApplication(sys.argv)

    window = QMainWindow()
    window.setWindowTitle("Buoyancy-Assisted UAV")
    window.setMinimumSize(800, 600)

    label = QLabel("Buoyancy-Assisted UAV — UI Placeholder\n\nReplace with real widgets.", window)
    label.setAlignment(align_center)
    window.setCentralWidget(label)

    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
