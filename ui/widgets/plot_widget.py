"""Placeholder matplotlib plot widget."""


class PlotWidget:
    """Embeds a matplotlib figure in the Qt window.

    Placeholder class. Replace with a FigureCanvasQTAgg subclass to
    display live plots of modelling results or logged flight data.
    """

    def plot(self, x, y, title: str = "") -> None:
        """Plot x vs y data with optional title."""
        raise NotImplementedError
