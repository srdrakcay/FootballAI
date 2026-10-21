"""Renders the localized App Store visuals (Pitch Night design) for every locale.

Inputs : AppStoreAssets/i18n/<locale>.json        copy (screens, tagline, name)
         AppStoreAssets/raw/<locale>/*.png        1320x2868 captures (capture_localized_screenshots.sh);
                                                  locales without captures reuse RAW_FALLBACK / en-US.
Outputs: AppStoreAssets/final/<locale>/NN-<screen>.jpg                          1320x2868 screenshots
         AppStoreAssets/creative/<locale>/product-page-header-21x9.png          3840x1646
         AppStoreAssets/creative/<locale>/search-result-3x2.png                 3840x2560
         (new creative asset types from Apple Developer News, 5 Oct 2026; no alpha channel)

Text is laid out by render_text (CoreText) so every script and right-to-left
language shapes correctly; Pillow only composites.
Run: python3 render_store_assets.py [locale ...]
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT.parent / "FootballAIApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
TEXT_TOOL_SRC = Path(__file__).resolve().parent / "render_text.swift"
TEXT_TOOL = Path(tempfile.gettempdir()) / "ninetylens_render_text"

BG = (10, 13, 11)
LINE = (38, 48, 42)
TEXT = (242, 245, 241)
MUTED = (154, 166, 159)
ACCENT = (200, 240, 74)

SCREENS = ["matches", "detail", "history", "profile", "onboarding-welcome"]
RTL = {"ar-SA", "he"}
NON_LATIN = {"ar-SA", "he", "hi", "th", "ja", "ko", "zh-Hans", "zh-Hant", "ru", "uk", "el"}
# Locales without their own captures show the UI of the closest captured language.
RAW_FALLBACK = {"es-MX": "es-ES", "ca": "es-ES", "fr-CA": "fr-FR"}


def ensure_text_tool():
    if not TEXT_TOOL.exists() or TEXT_TOOL.stat().st_mtime < TEXT_TOOL_SRC.stat().st_mtime:
        subprocess.run(["swiftc", "-O", str(TEXT_TOOL_SRC), "-o", str(TEXT_TOOL)], check=True)


def raw_dir(locale):
    for candidate in (locale, RAW_FALLBACK.get(locale), "en-US"):
        if candidate and (ROOT / "raw" / candidate / "matches.png").exists():
            return ROOT / "raw" / candidate
    raise FileNotFoundError(locale)


def rounded(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def background(width, height, glow_at):
    canvas = Image.new("RGBA", (width, height), BG + (255,))
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    r = int(min(width, height) * 0.42)
    ImageDraw.Draw(glow).ellipse((glow_at[0] - r, glow_at[1] - r, glow_at[0] + r, glow_at[1] + r), fill=ACCENT + (46,))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(r // 2)))
    return canvas


def phone(screen, width, radius_ratio=0.075):
    """Screen with rounded corners, a hairline bezel and a soft shadow."""
    height = round(screen.height * width / screen.width)
    shot = screen.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
    radius = round(width * radius_ratio)
    pad = round(width * 0.09)
    layer = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((pad, pad + pad // 3, pad + width, pad + pad // 3 + height), radius=radius, fill=(0, 0, 0, 200))
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(pad // 2)))
    border = round(width * 0.008)
    ImageDraw.Draw(layer).rounded_rectangle(
        (pad - border, pad - border, pad + width + border, pad + height + border), radius=radius + border, fill=LINE + (255,))
    layer.paste(shot, (pad, pad), rounded(shot.size, radius))
    return layer


def icon_tile(size):
    icon = Image.open(ICON).convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    tile.paste(icon, (0, 0), rounded((size, size), round(size * 0.2237)))
    return tile


def descriptor(name):
    return name.split(":", 1)[1].strip() if ":" in name else name.replace("NinetyLens", "").strip(" :-")


def text_items(locale, data, out_dir):
    """Every text block the locale needs, as render_text manifest entries."""
    base = {"rtl": locale in RTL, "latin": locale not in NON_LATIN}
    items = []

    def add(key, text, kind, size, max_width, color, **extra):
        entry = {"out": str(out_dir / f"{locale}-{key}.png"), "text": text, "kind": kind, "size": size,
                 "maxWidth": max_width, "color": list(color), **base}
        entry.update(extra)
        items.append(entry)

    for screen in SCREENS:
        headline, subhead = data["screens"][screen]
        add(f"{screen}-h", headline, "display", 132, 1128, TEXT, lineSpacing=2, minSize=60)
        add(f"{screen}-s", subhead, "text", 40, 1128, MUTED, lineSpacing=10, maxLines=2, minSize=26)
    add("kicker", "NINETYLENS", "kicker", 38, 600, ACCENT, rtl=False, latin=True)
    for layout, unit in (("wide", 1646 / 100.0), ("tall", 2560 / 100.0)):
        width = int(unit * (62 if layout == "wide" else 54))
        add(f"{layout}-tag", data["tagline"], "display", round(unit * 13.5), width, TEXT, lineSpacing=round(unit * 1.2), minSize=40)
        add(f"{layout}-brand", "NinetyLens", "display", round(unit * (9 if layout == "wide" else 6.4)), int(unit * 40), TEXT, rtl=False, latin=True)
        add(f"{layout}-desc", descriptor(data["name"]), "kicker", round(unit * (4.4 if layout == "wide" else 3.4)), int(unit * 40), ACCENT, maxLines=1, minSize=20)
    return items


def render_locale(locale, texts_dir):
    rtl = locale in RTL
    raws = raw_dir(locale)

    # Screenshots (1320x2868)
    for index, screen in enumerate(SCREENS, start=1):
        width, height = 1320, 2868
        canvas = background(width, height, (width // 2, 380))
        margin = 96
        kicker = Image.open(texts_dir / f"{locale}-kicker.png")
        canvas.alpha_composite(kicker, ((width - margin - kicker.width) if rtl else margin, 84))
        head = Image.open(texts_dir / f"{locale}-{screen}-h.png")
        canvas.alpha_composite(head, ((width - margin - head.width + 4) if rtl else margin - 4, 142))
        sub = Image.open(texts_dir / f"{locale}-{screen}-s.png")
        canvas.alpha_composite(sub, ((width - margin - sub.width + 4) if rtl else margin - 2, 142 + head.height + 14))
        shot = phone(Image.open(raws / f"{screen}.png"), 1040)
        canvas.alpha_composite(shot, ((width - shot.width) // 2, 640))
        out = ROOT / "final" / locale
        out.mkdir(parents=True, exist_ok=True)
        canvas.convert("RGB").save(out / f"{index:02d}-{screen}.jpg", quality=95, subsampling=0)

    # Wide creative assets
    for layout, (width, height, name) in {"wide": (3840, 1646, "product-page-header-21x9.png"), "tall": (3840, 2560, "search-result-3x2.png")}.items():
        unit = height / 100.0
        canvas = background(width, height, (int(width * (0.72 if rtl else 0.28)), int(height * 0.5)))
        shot_w = round(unit * (36 if layout == "wide" else 38))
        first = phone(Image.open(raws / "matches.png"), shot_w)
        second = phone(Image.open(raws / "detail.png"), shot_w)
        if rtl:  # mirror: phones on the left, copy on the right
            x1 = round(width * 0.05)
            x2 = x1 + round(shot_w * 0.78)
            text_right = width - round(width * 0.06)
        else:
            x2 = width - second.width - round(width * 0.05)
            x1 = x2 - round(shot_w * 0.78)
            text_left = round(width * (0.06 if layout == "wide" else 0.07))
        canvas.alpha_composite(first, (x1, round(unit * 12)))
        canvas.alpha_composite(second, (x2, round(unit * 30)))

        tile = icon_tile(round(unit * (17 if layout == "wide" else 15)))
        brand = Image.open(texts_dir / f"{locale}-{layout}-brand.png")
        desc = Image.open(texts_dir / f"{locale}-{layout}-desc.png")
        tag = Image.open(texts_dir / f"{locale}-{layout}-tag.png")
        brand_y = round(unit * 14.5)
        desc_y = round(unit * (14.5 + (9.5 if layout == "wide" else 7)))
        if rtl:
            canvas.alpha_composite(tile, (text_right - tile.width, round(unit * 14)))
            block_right = text_right - tile.width - round(unit * 3)
            canvas.alpha_composite(brand, (block_right - brand.width, brand_y))
            canvas.alpha_composite(desc, (block_right - desc.width, desc_y))
            canvas.alpha_composite(tag, (text_right - tag.width, round(unit * 42)))
        else:
            canvas.alpha_composite(tile, (text_left, round(unit * 14)))
            block_left = text_left + tile.width + round(unit * 3)
            canvas.alpha_composite(brand, (block_left, brand_y))
            canvas.alpha_composite(desc, (block_left, desc_y))
            canvas.alpha_composite(tag, (text_left, round(unit * 42)))
        out = ROOT / "creative" / locale
        out.mkdir(parents=True, exist_ok=True)
        canvas.convert("RGB").save(out / name, "PNG", optimize=True)


def main(argv):
    locales = argv or sorted(p.stem for p in (ROOT / "i18n").glob("*.json"))
    ensure_text_tool()
    with tempfile.TemporaryDirectory() as tmp:
        texts_dir = Path(tmp)
        manifest = []
        for locale in locales:
            data = json.loads((ROOT / "i18n" / f"{locale}.json").read_text(encoding="utf-8"))
            manifest += text_items(locale, data, texts_dir)
        manifest_path = texts_dir / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
        subprocess.run([str(TEXT_TOOL), str(manifest_path)], check=True)
        for locale in locales:
            render_locale(locale, texts_dir)
            print("rendered", locale)


if __name__ == "__main__":
    main(sys.argv[1:])
