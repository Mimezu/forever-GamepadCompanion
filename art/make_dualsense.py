"""Draws the DualSense line art for the Controller page: art/DualSense.tga.

1024 x 1024, RGBA, uncompressed (WoW reads it as is). The drawing uses the
top 1024 x 680; ControllerModel.lua's ART table holds the same coordinates.
Run: python art/make_dualsense.py (needs Pillow).
"""
import math
import os
from PIL import Image, ImageDraw

SS = 4                      # supersampling
W, H = 1024, 1024
LINE = (240, 222, 178, 255)  # Forever gold
SOFT = (240, 222, 178, 150)
FILL = (16, 11, 6, 170)
PAD_FILL = (30, 22, 12, 120)


def s(v):
    return v * SS


def spline(points, steps=24):
    """Closed Catmull-Rom curve through points."""
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    return out


def mirror(half):
    """Right half (top centre to bottom centre, clockwise) -> whole outline."""
    left = [(1024 - x, y) for x, y in reversed(half[1:-1])]
    return half + left


def poly(d, pts, width, color=LINE, fill=None):
    pts = [(s(x), s(y)) for x, y in pts]
    if fill:
        d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=color, width=int(width * SS), joint="curve")


def circle(d, cx, cy, r, width, color=LINE, fill=None):
    box = [s(cx - r), s(cy - r), s(cx + r), s(cy + r)]
    d.ellipse(box, outline=color, width=int(width * SS), fill=fill)


def rrect(d, x0, y0, x1, y1, r, width, color=LINE, fill=None):
    d.rounded_rectangle([s(x0), s(y0), s(x1), s(y1)], radius=s(r), outline=color, width=int(width * SS), fill=fill)


def line(d, pts, width, color=LINE):
    d.line([(s(x), s(y)) for x, y in pts], fill=color, width=int(width * SS), joint="curve")


def main():
    img = Image.new("RGBA", (s(W), s(H)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Triggers (L2 / R2), behind the shoulders
    for sx in (1, -1):
        cx = 512 + sx * 300
        pts = spline([(cx - 70, 92), (cx - 62, 40), (cx - 30, 14), (cx + 30, 14), (cx + 62, 40), (cx + 70, 92)], 16)
        poly(d, pts, 3, SOFT, FILL)
    # Shoulders (L1 / R1)
    for sx in (1, -1):
        cx = 512 + sx * 300
        rrect(d, cx - 82, 62, cx + 82, 104, 20, 3, LINE, FILL)

    # Body
    half = [(512, 96), (640, 92), (730, 84), (800, 80), (880, 88), (940, 116), (978, 176), (996, 262),
            (1004, 360), (1006, 460), (994, 560), (962, 630), (912, 660), (860, 652), (820, 612),
            (784, 548), (740, 500), (680, 476), (600, 470), (512, 472)]
    body = spline(mirror(half), 14)
    poly(d, body, 4, LINE, FILL)
    # The black centre piece's edge (touchpad sides, around the sticks)
    for sx in (1, -1):
        pts = [(512 + sx * x, y) for x, y in [(176, 98), (172, 200), (172, 276), (196, 318), (214, 392), (204, 446), (184, 472)]]
        line(d, spline_open(pts), 2, SOFT)

    # Touchpad
    pad = [(352, 104), (672, 104), (664, 262), (648, 280), (376, 280), (360, 262)]
    rrect_poly(d, pad, 3, LINE, PAD_FILL)
    # Create / Options
    for sx in (1, -1):
        cx = 512 + sx * 204
        rrect(d, cx - 7, 106, cx + 7, 142, 7, 2.5, LINE, FILL)

    # D-pad: four arrow keys
    dc = (232, 262)
    for ang in (0, 90, 180, 270):
        key = [(0, -22), (24, -22), (48, 0), (24, 22), (0, 22)]
        key = [(x + 18, y) for x, y in key]
        rot = [rot_pt(p, ang) for p in key]
        poly(d, [(dc[0] + x, dc[1] + y) for x, y in rot], 3, LINE, FILL)

    # Face buttons
    fc = (792, 262)
    for dx, dy in ((0, -62), (62, 0), (0, 62), (-62, 0)):
        circle(d, fc[0] + dx, fc[1] + dy, 30, 3, LINE, FILL)

    # Sticks
    for cx in (382, 642):
        circle(d, cx, 392, 62, 3, LINE, FILL)
        circle(d, cx, 392, 44, 2, SOFT)

    # PS button and mic mute
    circle(d, 512, 372, 18, 3, LINE, FILL)
    rrect(d, 490, 414, 534, 428, 7, 2, SOFT)

    # Speaker grille dots
    for i in range(-3, 4):
        circle(d, 512 + i * 12, 450, 2, 0, SOFT, SOFT)

    out = img.resize((W, H), Image.LANCZOS)
    here = os.path.dirname(os.path.abspath(__file__))
    out.save(os.path.join(here, "DualSense.tga"))
    print("ok")


def rot_pt(p, ang):
    a = math.radians(ang)
    return (p[0] * math.cos(a) - p[1] * math.sin(a), p[0] * math.sin(a) + p[1] * math.cos(a))


def spline_open(points, steps=20):
    pts = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(steps + 1):
            t = k / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    return out


def rrect_poly(d, pts, width, color, fill):
    """A polygon with softly rounded corners."""
    rounded = []
    n = len(pts)
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        for t in (0.0,):
            pass
        a = lerp(p1, p0, 0.12 if dist(p1, p0) > 60 else 0.3)
        b = lerp(p1, p2, 0.12 if dist(p1, p2) > 60 else 0.3)
        for k in range(9):
            t = k / 8
            q0, q1 = lerp(a, p1, t), lerp(p1, b, t)
            rounded.append(lerp(q0, q1, t))
    poly(d, rounded, width, color, fill)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


if __name__ == "__main__":
    main()
