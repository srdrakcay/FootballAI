from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math


SIZE = 1024
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "iap" / "promotional-images"


def gradient_background() -> Image.Image:
    image = Image.new("RGB", (SIZE, SIZE))
    pixels = image.load()
    for y in range(SIZE):
        for x in range(SIZE):
            nx = x / (SIZE - 1)
            ny = y / (SIZE - 1)
            purple = max(0.0, 1.0 - math.hypot(nx - 0.30, ny - 0.25) * 1.8)
            cyan = max(0.0, 1.0 - math.hypot(nx - 0.88, ny - 0.78) * 2.2)
            pixels[x, y] = (
                int(7 + 66 * purple),
                int(5 + 26 * purple + 29 * cyan),
                int(17 + 70 * purple + 55 * cyan),
            )
    return image


def render(pack_size: int) -> None:
    base = gradient_background()
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((210, 210, 814, 814), fill=(155, 92, 255, 120))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    base = Image.alpha_composite(base.convert("RGBA"), glow)

    art = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)
    center = (512, 500)

    for radius, alpha, width in ((300, 45, 3), (238, 70, 3), (170, 90, 2)):
        draw.ellipse(
            (
                center[0] - radius,
                center[1] - radius,
                center[0] + radius,
                center[1] + radius,
            ),
            outline=(184, 125, 255, alpha),
            width=width,
        )

    dot_count = pack_size
    orbit_radius = 260
    for index in range(dot_count):
        angle = -math.pi / 2 + (2 * math.pi * index / dot_count)
        x = center[0] + math.cos(angle) * orbit_radius
        y = center[1] + math.sin(angle) * orbit_radius
        radius = 13 if pack_size == 5 else 10
        color = (255, 79, 216, 255) if index % 2 == 0 else (40, 231, 255, 255)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)

    # Text-free lightning mark; Apple recommends avoiding overlaid copy.
    bolt = [
        (545, 290),
        (402, 520),
        (492, 520),
        (455, 710),
        (625, 450),
        (530, 450),
    ]
    draw.polygon(bolt, fill=(255, 255, 255, 255))

    halo = art.filter(ImageFilter.GaussianBlur(25))
    base = Image.alpha_composite(base, halo)
    base = Image.alpha_composite(base, art)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(
        OUTPUT / f"footballai_credits_{pack_size}.jpg",
        quality=96,
        dpi=(72, 72),
        subsampling=0,
    )


for amount in (5, 10):
    render(amount)
