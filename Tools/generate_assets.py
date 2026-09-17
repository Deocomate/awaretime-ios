#!/usr/bin/env python3
"""Generates AwareTime's PNG assets without any third-party dependency.

Run from the repository root:

    python3 Tools/generate_assets.py

Produces:
  * AwareTime/Assets.xcassets/AppIcon.appiconset/AppIcon.png   (1024, opaque)
  * ShieldConfigurationExtension/Assets.xcassets/ShieldIcon.imageset/*.png
"""

from __future__ import annotations

import math
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

INK = (0.07, 0.09, 0.16)
DEEP = (0.10, 0.13, 0.28)
CALM = (0.27, 0.53, 0.96)
AMBER = (0.98, 0.68, 0.16)
WHITE = (1.0, 1.0, 1.0)


# --------------------------------------------------------------------------- #
# PNG writer
# --------------------------------------------------------------------------- #

def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: pathlib.Path, width: int, height: int, rows, alpha: bool) -> None:
    color_type = 6 if alpha else 2
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    header = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    blob = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(raw, 9))
        + _chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(blob)


# --------------------------------------------------------------------------- #
# Tiny vector helpers (signed distance fields, 2x2 supersampled)
# --------------------------------------------------------------------------- #

def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def over(dst, src, alpha):
    """Source-over compositing on premultiplied-free tuples."""
    return tuple(src[i] * alpha + dst[i] * (1 - alpha) for i in range(3))


def coverage(distance: float, feather: float) -> float:
    """1 inside, 0 outside, smooth in between."""
    if feather <= 0:
        return 1.0 if distance <= 0 else 0.0
    return max(0.0, min(1.0, 0.5 - distance / feather))


def rounded_rect_sdf(x, y, cx, cy, half_w, half_h, radius):
    dx = abs(x - cx) - (half_w - radius)
    dy = abs(y - cy) - (half_h - radius)
    dx_c, dy_c = max(dx, 0.0), max(dy, 0.0)
    return math.hypot(dx_c, dy_c) + min(max(dx, dy), 0.0) - radius


def ring_sdf(x, y, cx, cy, radius, thickness):
    return abs(math.hypot(x - cx, y - cy) - radius) - thickness / 2


def arc_coverage(x, y, cx, cy, radius, thickness, start_deg, end_deg, feather):
    d = ring_sdf(x, y, cx, cy, radius, thickness)
    if d > feather:
        return 0.0
    angle = math.degrees(math.atan2(y - cy, x - cx)) % 360
    start, end = start_deg % 360, end_deg % 360
    inside = (start <= angle <= end) if start <= end else (angle >= start or angle <= end)
    if not inside:
        # Soften the arc caps a little instead of hard-clipping them.
        gap = min(
            abs((angle - start + 180) % 360 - 180),
            abs((angle - end + 180) % 360 - 180),
        )
        if gap > 2:
            return 0.0
    return coverage(d, feather)


# --------------------------------------------------------------------------- #
# The mark: a ring with a pause glyph, plus a progress arc
# --------------------------------------------------------------------------- #

def shade_app_icon(x, y, size):
    """Returns an opaque RGB tuple for one sample point."""
    u, v = x / size, y / size
    # Diagonal background gradient.
    color = mix(DEEP, INK, (u * 0.35 + v * 0.65))
    glow = max(0.0, 1.0 - math.hypot(u - 0.3, v - 0.22) * 1.7)
    color = mix(color, CALM, glow * 0.55)

    cx = cy = size / 2
    feather = size / 340

    outer_r = size * 0.285
    ring_t = size * 0.045

    # Progress arc: amber from -90° sweeping ~250°.
    a = arc_coverage(x, y, cx, cy, outer_r, ring_t, -95, 150, feather)
    if a > 0:
        color = over(color, AMBER, a)

    # Remaining part of the ring in translucent white.
    r = coverage(ring_sdf(x, y, cx, cy, outer_r, ring_t), feather)
    if r > 0:
        color = over(color, WHITE, r * 0.22 * (1 - a))

    # Pause glyph.
    bar_half_w = size * 0.032
    bar_half_h = size * 0.105
    bar_radius = bar_half_w
    offset = size * 0.062
    for sign in (-1, 1):
        d = rounded_rect_sdf(x, y, cx + sign * offset, cy, bar_half_w, bar_half_h, bar_radius)
        c = coverage(d, feather)
        if c > 0:
            color = over(color, WHITE, c)

    return color


def shade_shield_icon(x, y, size):
    """Returns (RGB, alpha) for the shield extension glyph (white on clear)."""
    cx = cy = size / 2
    feather = size / 160
    alpha = 0.0

    outer_r = size * 0.36
    ring_t = size * 0.058
    alpha = max(alpha, coverage(ring_sdf(x, y, cx, cy, outer_r, ring_t), feather) * 0.9)

    bar_half_w = size * 0.042
    bar_half_h = size * 0.135
    offset = size * 0.08
    for sign in (-1, 1):
        d = rounded_rect_sdf(x, y, cx + sign * offset, cy, bar_half_w, bar_half_h, bar_half_w)
        alpha = max(alpha, coverage(d, feather))

    return WHITE, min(1.0, alpha)


def render(size, shader, alpha_channel):
    """2x2 supersampled render."""
    rows = []
    offsets = (0.25, 0.75)
    for py in range(size):
        row = bytearray()
        for px in range(size):
            acc_r = acc_g = acc_b = acc_a = 0.0
            for oy in offsets:
                for ox in offsets:
                    sx, sy = px + ox, py + oy
                    if alpha_channel:
                        (r, g, b), a = shader(sx, sy, size)
                    else:
                        r, g, b = shader(sx, sy, size)
                        a = 1.0
                    acc_r += r
                    acc_g += g
                    acc_b += b
                    acc_a += a
            n = 4.0
            row.append(int(max(0, min(255, round(acc_r / n * 255)))))
            row.append(int(max(0, min(255, round(acc_g / n * 255)))))
            row.append(int(max(0, min(255, round(acc_b / n * 255)))))
            if alpha_channel:
                row.append(int(max(0, min(255, round(acc_a / n * 255)))))
        rows.append(row)
    return rows


def main() -> None:
    app_icon = ROOT / "AwareTime/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    print(f"rendering {app_icon.name} (1024x1024, opaque)…")
    write_png(app_icon, 1024, 1024, render(1024, shade_app_icon, False), alpha=False)

    shield_dir = ROOT / "ShieldConfigurationExtension/Assets.xcassets/ShieldIcon.imageset"
    for scale, size in ((1, 120), (2, 240), (3, 360)):
        name = f"ShieldIcon@{scale}x.png" if scale > 1 else "ShieldIcon.png"
        print(f"rendering {name} ({size}x{size}, alpha)…")
        write_png(shield_dir / name, size, size, render(size, shade_shield_icon, True), alpha=True)

    print("done")


if __name__ == "__main__":
    main()
