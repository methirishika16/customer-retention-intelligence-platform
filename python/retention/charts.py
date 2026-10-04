"""
Static charts (PNG) for the docs. One hue for single-series charts, a second hue only to
highlight; light, recessive grid; values labelled where useful.
"""

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from .config import CHART_DIR  # noqa: E402

BLUE = "#2a78d6"        # series 1
ORANGE = "#eb6834"      # highlight
GRAY = "#c3c2b7"        # de-emphasised marks
TEXT = "#0b0b0b"
TEXT_2 = "#52514e"
GRID = "#e6e5e0"
SURFACE = "#fcfcfb"

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "axes.edgecolor": GRID, "axes.labelcolor": TEXT_2, "text.color": TEXT,
    "xtick.color": TEXT_2, "ytick.color": TEXT_2, "font.size": 10,
    "axes.titlesize": 12, "axes.titleweight": "bold", "axes.titlelocation": "left",
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8,
})


def _save(fig, name: str):
    CHART_DIR.mkdir(parents=True, exist_ok=True)
    path = CHART_DIR / f"{name}.png"
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return path


def bar(categories, values, title, ylabel, name, fmt="{:.1%}", highlight=None, subtitle=None,
        reference=None, reference_label=None):
    fig, ax = plt.subplots(figsize=(8, 4.2))
    colors = [ORANGE if highlight is not None and i in highlight else BLUE for i in range(len(values))]
    bars = ax.bar([str(c) for c in categories], values, color=colors, width=0.6, zorder=3)
    ax.grid(axis="x", visible=False)
    for b, v in zip(bars, values):
        ax.annotate(fmt.format(v), (b.get_x() + b.get_width() / 2, b.get_height()),
                    xytext=(0, 3), textcoords="offset points", ha="center", va="bottom",
                    fontsize=9, color=TEXT_2)
    if reference is not None:
        ax.axhline(reference, color=TEXT_2, linewidth=1, linestyle="--", zorder=4)
        if reference_label:
            ax.annotate(f"{reference_label} ({fmt.format(reference)})", (1.0, reference),
                        xycoords=("axes fraction", "data"), xytext=(0, 4), textcoords="offset points",
                        ha="right", va="bottom", fontsize=9, color=TEXT_2, zorder=5)
    if subtitle:
        ax.set_title(title, pad=22)
        ax.text(0, 1.015, subtitle, transform=ax.transAxes, fontsize=9, color=TEXT_2, va="bottom")
    else:
        ax.set_title(title)
    if "%" in fmt:
        ax.yaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1.0, decimals=1 if max(values) < 0.05 else 0))
    ax.set_ylabel(ylabel)
    ax.margins(y=0.15)
    return _save(fig, name)


def hbar(labels, values, title, xlabel, name, fmt="{:.2f}", center=None, colors=None):
    fig, ax = plt.subplots(figsize=(8, 0.45 * len(labels) + 1.4))
    y = np.arange(len(labels))[::-1]
    left = center if center is not None else 0
    widths = np.asarray(values) - left
    ax.barh(y, widths, left=left, color=colors or BLUE, height=0.55, zorder=3)
    ax.set_yticks(y, labels)
    ax.grid(axis="y", visible=False)
    if center is not None:
        ax.axvline(center, color=TEXT_2, linewidth=1, zorder=4)
    for yi, v in zip(y, values):
        ax.annotate(fmt.format(v), (v, yi), xytext=(4 if v >= left else -4, 0), textcoords="offset points",
                    ha="left" if v >= left else "right", va="center", fontsize=9, color=TEXT_2)
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    if "," in fmt:
        ax.xaxis.set_major_formatter(matplotlib.ticker.StrMethodFormatter("{x:,.0f}"))
    ax.margins(x=0.15)
    return _save(fig, name)


def histogram(values, bins, title, xlabel, name, marker=None, marker_label=None):
    fig, ax = plt.subplots(figsize=(8, 4.2))
    ax.hist(values, bins=bins, color=BLUE, edgecolor=SURFACE, linewidth=1, zorder=3)
    ax.grid(axis="x", visible=False)
    if marker is not None:
        ax.axvline(marker, color=ORANGE, linewidth=2, zorder=4)
        if marker_label:
            ax.annotate(marker_label, (marker, ax.get_ylim()[1] * 0.92), xytext=(6, 0),
                        textcoords="offset points", fontsize=9, color=TEXT)
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Repeat purchases")
    return _save(fig, name)


def concentration_curve(share_customers, share_revenue, title, name, mark_at=0.2):
    fig, ax = plt.subplots(figsize=(6.5, 4.8))
    ax.plot(share_customers, share_revenue, color=BLUE, linewidth=2, zorder=3)
    ax.plot([0, 1], [0, 1], color=GRAY, linewidth=1, linestyle="--", zorder=2)
    idx = np.searchsorted(share_customers, mark_at)
    ax.scatter([share_customers[idx]], [share_revenue[idx]], s=40, color=ORANGE, zorder=4,
               edgecolor=SURFACE, linewidth=2)
    ax.annotate(f"Top {mark_at:.0%} of customers\n= {share_revenue[idx]:.0%} of revenue",
                (share_customers[idx], share_revenue[idx]), xytext=(12, -28),
                textcoords="offset points", fontsize=9, color=TEXT)
    ax.annotate("equal spend", (0.72, 0.66), fontsize=9, color=TEXT_2, rotation=33)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.xaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1.0))
    ax.yaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1.0))
    ax.set_xlabel("Customers, ranked by revenue (highest first)")
    ax.set_ylabel("Share of total revenue")
    ax.set_title(title)
    return _save(fig, name)
