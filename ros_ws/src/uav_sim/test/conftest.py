"""pytest configuration — add uav_sim package to sys.path."""

import sys
from pathlib import Path

# Allow importing uav_sim without a colcon install
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
