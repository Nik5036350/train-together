#!/usr/bin/env python3
"""Generate the app icon set and the iOS launch images from a single source PNG.

    python3 scripts/generate-icons.py            # regenerate everything
    python3 scripts/generate-icons.py --check    # verify the source, write nothing

The source (`assets/icon-source.png`) is a full-bleed 1024x1024 square: a kraft
pictogram on a textured red field, with no drawn corners and no outer margin.
That shape is deliberate — iOS applies its own squircle mask to home screen
icons, so artwork carrying its own rounded corners shows a ring nested inside
that mask. This script validates the source, then hands each platform the square
it expects and lets it do the rounding.

Needs Pillow (`pip install pillow`); it is a dev-time tool, not an app dependency.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "icon-source.png"
PUBLIC = ROOT / "public"
SPLASH_DIR = PUBLIC / "splash"

BACKGROUND = (0xF1, 0xE6, 0xD0)  # Paper — matches manifest background_color

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
SPLASH_JPEG_QUALITY = 88
IOS_CORNER_RADIUS = 0.222  # fraction of width; approximates the iOS squircle
MASKABLE_PAD = 0.083  # widen the field by this much per side, see maskable()

# The source's luminance histogram is cleanly bimodal — red field 48-95, kraft
# pictogram 144-223 — so this threshold sits in an empty valley. The median
# filter first removes the bright speckles the paper texture sprays across the
# red, which would otherwise read as pictogram.
PICTOGRAM_LUMA = 120
DESPECKLE = 5


def pictogram_mask(img: Image.Image) -> Image.Image:
    """Binary mask of the kraft pictogram, with the paper grain filtered out."""
    grey = img.convert("L").filter(ImageFilter.MedianFilter(DESPECKLE))
    return grey.point(lambda v: 255 if v > PICTOGRAM_LUMA else 0)


def load_source(path: Path) -> Image.Image:
    """Load the source and assert the properties every output depends on."""
    img = Image.open(path)

    if img.size[0] != img.size[1]:
        raise ValueError(f"source must be square, got {img.size[0]}x{img.size[1]}")
    if "A" in img.getbands():
        # iOS composites a transparent apple-touch-icon against black, so a
        # stray alpha channel turns the corners into black notches.
        raise ValueError("source must have no alpha channel")

    img = img.convert("RGB")
    width, height = img.size

    # Full-bleed check: the artwork must run to all four edges. A source with a
    # white margin or its own rounded corners fails here rather than shipping a
    # light ring inside the iOS mask.
    mask = pictogram_mask(img).load()
    edge = sum(
        1
        for i in range(width)
        for x, y in ((i, 0), (i, height - 1), (0, i), (width - 1, i))
        if mask[x, y]
    )
    if edge:
        raise ValueError(
            f"{edge} non-field pixels on the outer edge; the source is not full-bleed"
        )

    return img


def save(img: Image.Image, path: Path, colors: int = 64) -> int:
    """Write an opaque paletted PNG. No alpha: iOS composites it to black."""
    quantized = img.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
    quantized.save(path, optimize=True)
    return path.stat().st_size


def rounded(img: Image.Image) -> Image.Image:
    """Corner mask for the launch images — iOS does not mask those itself."""
    size = img.size[0]
    supersampled = size * 4
    mask = Image.new("L", (supersampled, supersampled), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, supersampled - 1, supersampled - 1),
        radius=int(supersampled * IOS_CORNER_RADIUS),
        fill=255,
    )
    return mask.resize((size, size), Image.LANCZOS)


def maskable(src: Image.Image, size: int, pad_frac: float = MASKABLE_PAD) -> Image.Image:
    """Widen the red field by mirroring it outward.

    Android crops a maskable icon to at worst a circle of 40% radius, and the
    pictogram reaches 43.1% of width in the source. Padding pulls it back to
    37%. Reflecting the source's own border is what keeps this invisible: the
    field is textured and unevenly lit, so padding with a flat colour would
    leave a ring and a hard seam. The tightest margin around the pictogram is
    13.7% of width, so the mirrored band is drawn purely from empty field.
    """
    width = src.size[0]
    pad = int(width * pad_frac)
    padded = Image.new("RGB", (width + 2 * pad, width + 2 * pad))

    padded.paste(src, (pad, pad))
    padded.paste(src.crop((0, 0, pad, width)).transpose(Image.FLIP_LEFT_RIGHT), (0, pad))
    padded.paste(
        src.crop((width - pad, 0, width, width)).transpose(Image.FLIP_LEFT_RIGHT),
        (width + pad, pad),
    )
    full = padded.size[0]
    padded.paste(padded.crop((0, pad, full, 2 * pad)).transpose(Image.FLIP_TOP_BOTTOM), (0, 0))
    padded.paste(
        padded.crop((0, width, full, width + pad)).transpose(Image.FLIP_TOP_BOTTOM),
        (0, width + pad),
    )

    return padded.resize((size, size), Image.LANCZOS)


def safe_zone_radius(img: Image.Image) -> float:
    """Furthest pictogram pixel from the centre, as a fraction of width."""
    mask = pictogram_mask(img)
    width, height = mask.size
    px = mask.load()
    cx, cy = (width - 1) / 2, (height - 1) / 2
    worst = 0.0
    for y in range(height):
        for x in range(width):
            if px[x, y]:
                worst = max(worst, ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5)
    return worst / width


def main() -> int:
    check_only = "--check" in sys.argv
    if not SOURCE.exists():
        print(f"error: source image not found at {SOURCE}", file=sys.stderr)
        return 1

    try:
        base = load_source(SOURCE)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    bare = safe_zone_radius(base)
    padded = safe_zone_radius(maskable(base, base.size[0]))
    print(f"source:   {base.size[0]}x{base.size[1]}, full-bleed, no alpha")
    print(f"maskable: pictogram at {bare:.1%} of width, {padded:.1%} after padding (limit 40.0%)")
    if padded > 0.40:
        print("error: padded artwork still exceeds the Android safe zone", file=sys.stderr)
        return 1

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

    # The launch images are fully opaque — the rounded logo is composited onto
    # the background before writing — so JPEG applies. The artwork's paper grain
    # is incompressible noise: a PNG faithful enough to avoid banding runs about
    # twice the size of q88 4:4:4.
    splash_total = 0
    for css_w, css_h, dpr in IPHONE_VIEWPORTS:
        px_w, px_h = css_w * dpr, css_h * dpr
        canvas = Image.new("RGB", (px_w, px_h), BACKGROUND)
        logo_px = SPLASH_LOGO_CSS_PX * dpr
        logo = base.resize((logo_px, logo_px), Image.LANCZOS)
        canvas.paste(logo, ((px_w - logo_px) // 2, (px_h - logo_px) // 2), rounded(logo))
        path = SPLASH_DIR / f"apple-splash-{px_w}x{px_h}.jpg"
        canvas.save(path, "JPEG", quality=SPLASH_JPEG_QUALITY, optimize=True, subsampling=0)
        splash_total += path.stat().st_size
    print(f"splashes: {len(IPHONE_VIEWPORTS)} files, {splash_total / 1024:.1f} KB")
    print(f"total:    {(total + splash_total) / 1024:.1f} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
