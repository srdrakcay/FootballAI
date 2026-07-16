from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 1320, 2868
SCREEN_WIDTH = 1080
SCREEN_TOP = 500
RADIUS = 72

COPY = {
    "en-US": [
        ("onboarding", "See every match\ndifferently", "Fixtures, form and team context in one intelligent hub."),
        ("matches", "Plan matchday\nby date", "Browse supported fixtures with a fast daily calendar."),
        ("history", "Keep every\ninsight close", "Favorites and analysis history stay connected to your account."),
        ("credits", "Credits, not\nsubscriptions", "Choose 5 or 10 credits whenever you need more analyses."),
        ("profile", "Your football hub,\nyour control", "Manage credits, privacy, account data and legal documents."),
    ],
    "tr": [
        ("onboarding", "Maçlara farklı\nbir gözle bak", "Fikstür, form ve takım bağlamı tek bir akıllı merkezde."),
        ("matches", "Maç gününü\ntakvimle planla", "Desteklenen fikstürleri hızlı günlük takvimle keşfet."),
        ("history", "Her analiz\nelinin altında", "Favorilerin ve analiz geçmişin hesabınla birlikte saklanır."),
        ("credits", "Abonelik değil,\nihtiyacın kadar kredi", "Daha fazla analiz gerektiğinde 5 veya 10 kredi seç."),
        ("profile", "Futbol merkezin,\nkontrol sende", "Kredileri, gizliliği, hesap verilerini ve belgeleri yönet."),
    ],
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    return ImageFont.load_default()


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def render(locale: str, source_name: str, headline: str, subhead: str, index: int) -> None:
    source = ROOT / "raw" / locale / f"{source_name}.png"
    if not source.exists():
        raise FileNotFoundError(source)

    screenshot = Image.open(source).convert("RGB")
    screen_height = round(screenshot.height * SCREEN_WIDTH / screenshot.width)
    screenshot = screenshot.resize((SCREEN_WIDTH, screen_height), Image.Resampling.LANCZOS)

    canvas = Image.new("RGB", (WIDTH, HEIGHT), "#070511")
    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((-250, -350, 850, 760), fill=(146, 78, 255, 110))
    glow_draw.ellipse((760, 1650, 1600, 2850), fill=(30, 219, 255, 55))
    glow = glow.filter(ImageFilter.GaussianBlur(150))
    canvas.paste(glow.convert("RGB"), (0, 0), glow)

    draw = ImageDraw.Draw(canvas)
    draw.text((92, 70), "NINETY LENS", font=font(34, True), fill="#C7A7FF", spacing=8)
    draw.multiline_text((92, 132), headline, font=font(92, True), fill="white", spacing=4)
    draw.multiline_text((94, 350), subhead, font=font(35), fill="#B9B4C8", spacing=8)

    x = (WIDTH - SCREEN_WIDTH) // 2
    shadow = Image.new("RGBA", (SCREEN_WIDTH + 120, screen_height + 120), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((60, 50, SCREEN_WIDTH + 60, screen_height + 50), radius=RADIUS, fill=(0, 0, 0, 210))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas.paste(shadow.convert("RGB"), (x - 60, SCREEN_TOP - 50), shadow)

    mask = rounded_mask(screenshot.size, RADIUS)
    canvas.paste(screenshot, (x, SCREEN_TOP), mask)
    draw.rounded_rectangle(
        (x - 2, SCREEN_TOP - 2, x + SCREEN_WIDTH + 2, SCREEN_TOP + screen_height + 2),
        radius=RADIUS + 2,
        outline="#6E4DA0",
        width=4,
    )

    output_dir = ROOT / "final" / locale
    output_dir.mkdir(parents=True, exist_ok=True)
    canvas.save(output_dir / f"{index:02d}-{source_name}.jpg", quality=96, subsampling=0)


for locale, entries in COPY.items():
    for index, entry in enumerate(entries, start=1):
        render(locale, *entry, index)
