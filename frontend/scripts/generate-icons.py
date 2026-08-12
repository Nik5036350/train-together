#!/usr/bin/env python3
"""Generate the app icon set and the iOS launch images from a single source PNG.

    python3 scripts/generate-icons.py            # regenerate everything
    python3 scripts/generate-icons.py --check    # verify, write nothing

The source (`assets/icon-source.png`) is a red badge drawn on a white field with
its own rounded corners. iOS applies its own squircle mask to home screen icons,
so shipping the artwork as-drawn produces a white ring nested inside that mask.
Everything here exists to hand each platform a full-bleed, opaque square and let
it do the rounding.

Needs Pillow (`pip install pillow`); it is a dev-time tool, not an app dependency.
"""

import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "icon-source.png"
PUBLIC = ROOT / "public"
SPLASH_DIR = PUBLIC / "splash"

RED = (0xBE, 0x20, 0x1C)  # badge red, sampled from the source
WHITE = (0xFF, 0xFF, 0xFF)
BACKGROUND = (0xF4, 0xF5, 0xF7)  # matches manifest background_color

# Distinct portrait viewports across the supported iPhone range. Several models
# share a viewport (13 mini and 11 Pro are both 375x812@3), so one file serves
# each. iOS ignores a launch image whose dimensions don't match exactly.
IPHONE_VIEWPORTS = [
    (440, 956, 3),  # 16 Pro Max / 15 Pro Max / 14 Pro Max
    (430, 932, 3),  # 16 Plus / 15 Plus / 14 Plus
    (402, 874, 3),  # 16 Pro / 15 Pro
    (393, 852, 3),  # 16 / 15 / 14 Pro
    (390, 844, 3),  # 14 / 13 / 12
    (375, 812, 3),  # 13 mini / 12 mini / 11 Pro / XS / X
    (414, 896, 3),  # 11 Pro Max / XS Max
    (414, 896, 2),  # 11 / XR
    (414, 736, 3),  # 8 Plus / 7 Plus
    (375, 667, 2),  # SE 2nd/3rd gen / 8 / 7
    (320, 568, 2),  # SE 1st gen
]

SPLASH_LOGO_CSS_PX = 200
IOS_CORNER_RADIUS = 0.222  # fraction of width; approximates the iOS squircle
MASKABLE_SAFE_SCALE = 0.8  # artwork occupies the inner 80% safe zone


def build_base(path: Path, inset: int = 8) -> Image.Image:
    """Turn the source badge into a full-bleed, opaque, noise-free square."""
    img = Image.open(path).convert("RGB")
    width, height = img.size
    px = img.load()
    seed = px[width // 2, height // 2]

    def is_badge(pixel):
        return sum(abs(a - b) for a, b in zip(pixel, seed)) < 90

    # 1. Crop to the badge, biting `inset` px inside it so the white margin and
    #    the antialiased boundary row are both discarded.
    cols = [x for x in range(width) if any(is_badge(px[x, y]) for y in range(0, height, 2))]
    rows = [y for y in range(height) if any(is_badge(px[x, y]) for x in range(0, width, 2))]
    badge = img.crop((cols[0] + inset, rows[0] + inset, cols[-1] - inset + 1, rows[-1] - inset + 1))

    # The source badge is a few px off square; centre-crop to the shorter side.
    side = min(badge.size)
    left, top = (badge.width - side) // 2, (badge.height - side) // 2
    badge = badge.crop((left, top, left + side, top + side))

    # 2. Flood-fill the four exterior corner regions with the badge colour. They
    #    are disconnected from the white pictogram, which the badge encloses.
    bw, bh = badge.size
    bp = badge.load()
    for corner in ((0, 0), (bw - 1, 0), (0, bh - 1), (bw - 1, bh - 1)):
        if is_badge(bp[corner]):
            continue
        queue = deque([corner])
        bp[corner] = seed
        while queue:
            x, y = queue.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < bw and 0 <= ny < bh and not is_badge(bp[nx, ny]):
                    bp[nx, ny] = seed
                    queue.append((nx, ny))

    # 3. The source carries JPEG-style mottling across what should be flat
    #    colour. Remap every pixel onto the exact red-to-white axis, using the
    #    green channel as the blend factor: antialiasing survives, noise doesn't.
    #    Skipping this triples the encoded size of the larger icons.
    green = badge.split()[1]
    low = seed[1]
    blend = green.point(lambda v: 0 if v <= low else min(255, int((v - low) * 255 / (255 - low))))
    out = Image.new("RGB", badge.size, RED)
    out.paste(Image.new("RGB", badge.size, WHITE), (0, 0), blend)

    # 4. Force the outer frame to solid red so no stray light pixel survives on
    #    the edge, where it would read as a white fringe against a dark wallpaper.
    ImageDraw.Draw(out).rectangle((0, 0, bw - 1, bh - 1), outline=RED, width=2)
    return out


def save(img: Image.Image, path: Path, colors: int = 64) -> int:
    """Write an opaque paletted PNG. No alpha: iOS composites it to black."""
    quantized = img.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
    quantized.save(path, optimize=True)
    return path.stat().st_size


def rounded(img: Image.Image, radius_frac: float = IOS_CORNER_RADIUS) -> Image.Image:
    """Pre-round the corners — iOS does not mask launch images."""
    size = img.size[0]
    supersampled = size * 4
    mask = Image.new("L", (supersampled, supersampled), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, supersampled - 1, supersampled - 1),
        radius=int(supersampled * radius_frac),
        fill=255,
    )
    mask = mask.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img.convert("RGBA"), (0, 0), mask)
    return out


def maskable(base: Image.Image, size: int) -> Image.Image:
    """Artwork inside the inner 80%, on a red field Android is free to crop."""
    canvas = Image.new("RGB", (size, size), RED)
    inner = int(size * MASKABLE_SAFE_SCALE)
    canvas.paste(base.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2,) * 2)
    return canvas


def main() -> int:
    check_only = "--check" in sys.argv
    if not SOURCE.exists():
        print(f"error: source image not found at {SOURCE}", file=sys.stderr)
        return 1

    base = build_base(SOURCE)

    # The edge is what makes or breaks the iPhone home screen icon, so assert it.
    bp = base.load()
    w, h = base.size
    stray = sum(
        1
        for i in range(w)
        for (x, y) in ((i, 0), (i, h - 1), (0, i), (w - 1, i))
        if sum(abs(a - b) for a, b in zip(bp[x, y], RED)) > 10
    )
    if stray:
        print(f"error: {stray} non-red pixels on the outer edge; icon would show a fringe", file=sys.stderr)
        return 1
    print(f"base: {base.size[0]}x{base.size[1]}, edge clean, {len(base.getcolors(maxcolors=1 << 20))} colours")

    if check_only:
        print("--check: nothing written")
        return 0

    SPLASH_DIR.mkdir(parents=True, exist_ok=True)
    total = 0

    for name, size in (("apple-touch-icon", 180), ("icon-192", 192), ("icon-512", 512)):
        total += save(base.resize((size, size), Image.LANCZOS), PUBLIC / f"{name}.png")
    for size in (192, 512):
        total += save(maskable(base, size), PUBLIC / f"icon-{size}-maskable.png")
    for size in (16, 32):
        total += save(base.resize((size, size), Image.LANCZOS), PUBLIC / f"favicon-{size}.png")

    base.resize((48, 48), Image.LANCZOS).save(
        PUBLIC / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)]
    )
    total += (PUBLIC / "favicon.ico").stat().st_size
    print(f"icons:    8 files, {total / 1024:.1f} KB")

    # Launch images are a flat background plus the logo, so a 4-colour palette is
    # indistinguishable from 16 here and encodes an order of magnitude smaller.
    splash_total = 0
    for css_w, css_h, dpr in IPHONE_VIEWPORTS:
        px_w, px_h = css_w * dpr, css_h * dpr
        canvas = Image.new("RGB", (px_w, px_h), BACKGROUND)
        logo_px = SPLASH_LOGO_CSS_PX * dpr
        logo = rounded(base.resize((logo_px, logo_px), Image.LANCZOS))
        canvas.paste(logo, ((px_w - logo_px) // 2, (px_h - logo_px) // 2), logo)
        splash_total += save(canvas, SPLASH_DIR / f"apple-splash-{px_w}x{px_h}.png", colors=4)
    print(f"splashes: {len(IPHONE_VIEWPORTS)} files, {splash_total / 1024:.1f} KB")
    print(f"total:    {(total + splash_total) / 1024:.1f} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
