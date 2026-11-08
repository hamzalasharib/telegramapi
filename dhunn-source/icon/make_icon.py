#!/usr/bin/env python3
"""Dhunn launcher icon (v2.17) — generated artwork.

Design: deep green-black background with an emerald glow, a bold
pair of beamed eighth notes (a "dhun" — a melody) in an emerald
sweep, a faint vinyl ring behind them, and five small equalizer
bars. Original motif (no brand logos). Drawn at 2048 and
downscaled for crisp edges at every density.
"""
from PIL import Image, ImageDraw, ImageFilter
import math, os

ROOT = os.path.join(os.path.dirname(__file__), "..")
S = 2048  # master size


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgrad(size, top, bottom):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(top, bottom, y / size))
    return img


def glow(size, cx, cy, radius, color, peak=110):
    g = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(g)
    steps = 24
    for i in range(steps, 0, -1):
        r = radius * i / steps
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=int(peak * (1 - i / steps) ** 1.6) + 4)
    g = g.filter(ImageFilter.GaussianBlur(size // 16))
    tint = Image.new("RGB", (size, size), color)
    return tint, g


def ring_gradient(size, box, width, c1, c2):
    """Ring whose colour sweeps c1 -> c2 around the circle."""
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    x0, y0, x1, y1 = box
    for a in range(-90, 270):
        col = lerp(c1, c2, (a + 90) / 360.0)
        d.arc([x0, y0, x1, y1], start=a, end=a + 2, fill=col + (255,), width=width)
    return ring


def play_triangle(size, cx, cy, w, h, blur_shadow=True):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = [(cx - w / 2, cy - h / 2), (cx - w / 2, cy + h / 2), (cx + w / 2, cy)]
    if blur_shadow:
        sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ds = ImageDraw.Draw(sh)
        ds.polygon([(x + size * 0.008, y + size * 0.014) for x, y in pts], fill=(0, 0, 0, 120))
        layer.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size // 90)))
    d.polygon(pts, fill=(255, 255, 255, 255))
    return layer


PALETTES = {
    # name: (bg_top, bg_bottom, glow_rgb, note_hi, note_lo, bar_from, bar_to)
    "emerald": ((13, 42, 24), (3, 8, 6), (24, 190, 100), (64, 255, 158), (7, 166, 92), (27, 224, 110), (0, 194, 255)),
    "ocean": ((10, 28, 52), (2, 6, 14), (30, 130, 230), (96, 224, 255), (0, 102, 214), (64, 200, 255), (130, 110, 255)),
    "sunset": ((48, 12, 36), (14, 3, 10), (235, 90, 90), (255, 196, 86), (238, 62, 110), (255, 166, 66), (255, 84, 150)),
    "violet": ((32, 12, 54), (8, 3, 18), (140, 80, 235), (216, 158, 255), (116, 58, 232), (186, 120, 255), (255, 110, 190)),
}
PAL = PALETTES["emerald"]


def eq_bars(size, cx, base_y, scale=1.0):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    heights = [0.34, 0.62, 1.0, 0.55, 0.8]
    bw = size * 0.030 * scale
    gap = size * 0.026 * scale
    total = bw * 5 + gap * 4
    x = cx - total / 2
    maxh = size * 0.085 * scale
    for i, hf in enumerate(heights):
        h = maxh * hf
        col = lerp(PAL[5], PAL[6], i / 4.0)
        d.rounded_rectangle([x, base_y - h, x + bw, base_y], radius=bw / 2, fill=col + (235,))
        x += bw + gap
    return layer


def _note_mask(size):
    """White silhouette of two beamed eighth notes (the 'dhun')."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    heads = [(0.365, 0.600), (0.650, 0.538)]  # (cx, cy) ratios
    hw, hh = size * 0.140, size * 0.116
    stem_w = size * 0.054
    tops = []
    for (hx, hy) in heads:
        sx = hx * size + hw * 0.62
        top = hy * size - size * 0.345
        tops.append((sx, top))
        d.rectangle([sx - stem_w / 2, top, sx + stem_w / 2, hy * size + hh * 0.18], fill=255)
    (x1, y1), (x2, y2) = tops
    bt = size * 0.108
    d.polygon([(x1 - stem_w / 2, y1), (x2 + stem_w / 2, y2),
               (x2 + stem_w / 2, y2 + bt), (x1 - stem_w / 2, y1 + bt)], fill=255)
    for (hx, hy) in heads:
        head = Image.new("L", (int(hw * 2), int(hh * 2)), 0)
        ImageDraw.Draw(head).ellipse([hw * 0.15, hh * 0.28, hw * 1.85, hh * 1.72], fill=255)
        head = head.rotate(22, resample=Image.BICUBIC, expand=False)
        m.paste(head, (int(hx * size - hw), int(hy * size - hh)), head)
    return m


def motif(size, disc_cy_ratio=0.44, with_bars=True):
    """Transparent layer: beamed notes + faint vinyl ring (+ bars)."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = size / 2
    cy = size * disc_cy_ratio
    d = ImageDraw.Draw(layer)
    R = size * 0.335
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(255, 255, 255, 30),
              width=max(2, int(size * 0.010)))
    r2 = R * 0.80
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], outline=(255, 255, 255, 20),
              width=max(2, int(size * 0.007)))
    mask = _note_mask(size)
    bbox = mask.getbbox()
    if bbox:
        nx = int(cx - (bbox[0] + bbox[2]) / 2)
        ny = int(cy - (bbox[1] + bbox[3]) / 2)
        shifted = Image.new("L", (size, size), 0)
        shifted.paste(mask, (nx, ny))
        mask = shifted
    grad = Image.new("RGB", (size, size))
    gd = ImageDraw.Draw(grad)
    steps = 64
    for i in range(steps):
        t = i / (steps - 1)
        col = lerp(PAL[3], PAL[4], t)
        x0 = int(size * t)
        gd.rectangle([x0, 0, int(size * (t + 1 / steps)) + 2, size], fill=col)
    note = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    note.paste(grad, (0, 0), mask)
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sh.paste((0, 0, 0, 130), (int(size * 0.008), int(size * 0.016)), mask)
    layer.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size // 90)))
    layer.alpha_composite(note)
    if with_bars:
        layer.alpha_composite(eq_bars(size, cx, size * (disc_cy_ratio + 0.335)))
    return layer


def full_icon(master=1024):
    img = vgrad(S, PAL[0], PAL[1]).convert("RGBA")
    tint, mask = glow(S, S * 0.30, S * 0.22, S * 0.62, PAL[2])
    img = Image.composite(tint, img, mask.point(lambda v: int(v * 0.55)))
    img.alpha_composite(motif(S, disc_cy_ratio=0.415))
    return img.resize((master, master), Image.LANCZOS)


def adaptive_foreground(master=1024):
    """Adaptive-icon foreground: motif inside the safe zone (~62%)."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = motif(S, disc_cy_ratio=0.44, with_bars=True)
    k = 0.74
    m = m.resize((int(S * k), int(S * k)), Image.LANCZOS)
    layer.alpha_composite(m, (int(S * (1 - k) / 2), int(S * (1 - k) / 2)))
    return layer.resize((master, master), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", path, img.size)


def _write_set(icon, suffix):
    """suffix '' for the default (emerald) names; '_ocean' etc. else."""
    save(icon.resize((512, 512), Image.LANCZOS),
         os.path.join(ROOT, "assets", f"icon{suffix}.png"))
    dens = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dname, px in dens.items():
        save(icon.resize((px, px), Image.LANCZOS),
             os.path.join(ROOT, "android/app/src/main/res", f"mipmap-{dname}", f"ic_launcher{suffix}.png"))
        m = Image.new("L", (px * 4, px * 4), 0)
        ImageDraw.Draw(m).ellipse([0, 0, px * 4, px * 4], fill=255)
        m = m.resize((px, px), Image.LANCZOS)
        rnd = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        rnd.paste(icon.resize((px, px), Image.LANCZOS), (0, 0), m)
        save(rnd, os.path.join(ROOT, "android/app/src/main/res", f"mipmap-{dname}", f"ic_launcher{suffix}_round.png"))


for _name, _pal in PALETTES.items():
    PAL = _pal
    _sfx = "" if _name == "emerald" else f"_{_name}"
    _write_set(full_icon(), _sfx)
    save(adaptive_foreground(),
         os.path.join(ROOT, "android/app/src/main/res/drawable", f"ic_launcher_foreground{_sfx}.png"))
print("done")
