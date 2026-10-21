"""Renders the NinetyLens app icon (Pitch Night palette) at 1024x1024.

The mark is a lens ring whose inside is a pitch seen from above: halfway line,
centre circle and kick-off spot, with a small glint on the glass.
Usage: python3 render_app_icon.py [output.png]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
SS = 4  # supersampling
W = SIZE * SS
BG = (10, 13, 11)
SURFACE = (19, 24, 21)
ACCENT = (200, 240, 74)
ACCENT_BRIGHT = (226, 255, 138)
ACCENT_DEEP = (112, 150, 30)
CX = CY = W // 2 - 22 * SS  # optical centring: the handle extends toward the lower right


def s(v: float) -> int:
    return round(v * SS)


def radial_glow(radius: float, color: tuple, alpha: int, center=(CX, CY)) -> Image.Image:
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(
        (center[0] - s(radius), center[1] - s(radius), center[0] + s(radius), center[1] + s(radius)),
        fill=color + (alpha,),
    )
    return layer.filter(ImageFilter.GaussianBlur(s(radius * 0.45)))


def ring_mask(outer: float, inner: float) -> Image.Image:
    mask = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((CX - s(outer), CY - s(outer), CX + s(outer), CY + s(outer)), fill=255)
    d.ellipse((CX - s(inner), CY - s(inner), CX + s(inner), CY + s(inner)), fill=0)
    return mask


def gradient(top: tuple, bottom: tuple) -> Image.Image:
    base = Image.new("RGB", (W, W))
    px = ImageDraw.Draw(base)
    for y in range(W):
        t = y / (W - 1)
        px.line((0, y, W, y), fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return base


def main(output: Path) -> None:
    canvas = Image.new("RGBA", (W, W), BG + (255,))
    canvas.alpha_composite(radial_glow(380, ACCENT, 46))

    # Lens glass: slightly lighter disc behind the pitch lines.
    glass = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(glass).ellipse((CX - s(300), CY - s(300), CX + s(300), CY + s(300)), fill=SURFACE + (255,))
    canvas.alpha_composite(glass)

    # Pitch markings inside the lens, clipped to the glass.
    pitch = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pitch)
    line = ACCENT + (150,)
    pd.line((CX, CY - s(300), CX, CY + s(300)), fill=line, width=s(14))  # halfway line (vertical)
    pd.ellipse((CX - s(150), CY - s(150), CX + s(150), CY + s(150)), outline=line, width=s(14))  # centre circle
    clip = Image.new("L", (W, W), 0)
    ImageDraw.Draw(clip).ellipse((CX - s(290), CY - s(290), CX + s(290), CY + s(290)), fill=255)
    pitch.putalpha(ImageChops.multiply(pitch.getchannel("A"), clip))
    canvas.alpha_composite(pitch)

    # Kick-off spot with glow.
    canvas.alpha_composite(radial_glow(70, ACCENT_BRIGHT, 200))
    spot = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(spot).ellipse((CX - s(46), CY - s(46), CX + s(46), CY + s(46)), fill=ACCENT_BRIGHT + (255,))
    canvas.alpha_composite(spot)

    # Lens ring: vertical lime gradient with a soft outer glow.
    ring = ring_mask(352, 300)
    canvas.alpha_composite(radial_glow(380, ACCENT, 70))
    ringed = gradient(ACCENT_BRIGHT, ACCENT_DEEP).convert("RGBA")
    ringed.putalpha(ring)
    canvas.alpha_composite(ringed)

    # Glint on the upper-left of the glass.
    glint = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glint)
    box = (CX - s(255), CY - s(255), CX + s(255), CY + s(255))
    gd.arc(box, start=205, end=250, fill=(240, 255, 200, 150), width=s(16))
    canvas.alpha_composite(glint.filter(ImageFilter.GaussianBlur(s(1.5))))

    # Lens handle toward the lower right, rounded, tying the mark to "lens".
    handle = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    hd = ImageDraw.Draw(handle)
    angle = math.radians(45)
    start = (CX + math.cos(angle) * s(340), CY + math.sin(angle) * s(340))
    end = (CX + math.cos(angle) * s(452), CY + math.sin(angle) * s(452))
    hd.line((*start, *end), fill=ACCENT + (255,), width=s(62))
    for p in (start, end):
        hd.ellipse((p[0] - s(31), p[1] - s(31), p[0] + s(31), p[1] + s(31)), fill=ACCENT + (255,))
    canvas.alpha_composite(handle)

    icon = canvas.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    output.parent.mkdir(parents=True, exist_ok=True)
    icon.save(output, "PNG")
    print(f"wrote {output}")


if __name__ == "__main__":
    default = Path(__file__).resolve().parents[2] / "FootballAIApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else default)
