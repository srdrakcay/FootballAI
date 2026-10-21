"""Validates AppStoreAssets/i18n/<locale>.json and writes the fastlane metadata.

One JSON file per App Store locale is the single source of truth for text:
    name, subtitle, keywords, promotional_text, description, release_notes,
    screens{matches,detail,history,profile,onboarding-welcome: [headline, subhead]},
    tagline (wide creative assets).

Limits (UTF-16 code units, the strictest reading of Apple's character counts):
name 30, subtitle 30, keywords 100, promotional text 170, description 4000,
release notes 4000. ASO rules (appeeky/aso-skills): keywords comma separated
without spaces, no entry already contained in name/subtitle, no duplicates,
no betting vocabulary, no league/club trademarks.

Usage:
    python3 write_metadata.py --check FILE.json [FILE.json ...]   validate only
    python3 write_metadata.py                                      validate all and write metadata
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
I18N = ROOT / "AppStoreAssets" / "i18n"
TARGETS = [ROOT / "AppStoreAssets" / "metadata", ROOT / "fastlane" / "metadata"]

LIMITS = dict(name=30, subtitle=30, keywords=100, promotional_text=170, description=4000, release_notes=4000)
SCREENS = ["matches", "detail", "history", "profile", "onboarding-welcome"]
TEXT_FIELDS = list(LIMITS)
BANNED = re.compile(
    r"\b(bet|bets|betting|bettor|odds|tips|tipster|gambling|wager|bahis|iddaa|wette|wetten|paris|apuesta|apuestas|scommesse|aposta|apostas)\b",
    re.I,
)
TRADEMARKS = re.compile(
    r"(premier league|la ?liga|bundesliga|serie a|ligue 1|champions league|uefa|fifa|süper lig|real madrid|barcelona|manchester)",
    re.I,
)
# Locales whose pages are hosted; everything else points at the English pages.
HOSTED_URL_LOCALES = {"tr": "tr", "de-DE": "de", "fr-FR": "fr", "es-ES": "es"}
BASE_URL = "https://footballai-40789.web.app"


def units(text: str) -> int:
    return len(text.encode("utf-16-le")) // 2


def validate(data: dict) -> list:
    locale = data.get("locale", "?")
    problems = []
    for key in TEXT_FIELDS:
        value = data.get(key)
        if not isinstance(value, str) or not value.strip():
            problems.append(f"{locale}.{key}: missing")
            continue
        if units(value.strip()) > LIMITS[key]:
            problems.append(f"{locale}.{key}: {units(value.strip())}/{LIMITS[key]}")
    if problems:
        return problems

    if " " in data["keywords"] or ",," in data["keywords"] or data["keywords"].startswith(",") or data["keywords"].endswith(","):
        problems.append(f"{locale}.keywords: spaces or empty entries (use a,b,c)")
    entries = data["keywords"].split(",")
    if len(set(e.lower() for e in entries)) != len(entries):
        problems.append(f"{locale}.keywords: duplicates")
    haystack = unicodedata.normalize("NFC", (data["name"] + " " + data["subtitle"]).lower())
    repeated = [e for e in entries if unicodedata.normalize("NFC", e.lower()) in haystack]
    if repeated:
        problems.append(f"{locale}.keywords repeats name/subtitle text: {repeated}")
    if "NinetyLens" not in data["name"]:
        problems.append(f"{locale}.name: must contain the brand NinetyLens")
    if "ninetylens" in data["keywords"].lower():
        problems.append(f"{locale}.keywords: must not contain the brand")
    for key in ("name", "subtitle", "keywords", "promotional_text"):
        for pattern, label in ((BANNED, "betting term"), (TRADEMARKS, "trademark")):
            hit = pattern.search(data[key])
            if hit:
                problems.append(f"{locale}.{key}: {label} {hit.group(0)!r}")
    hit = TRADEMARKS.search(data["description"])
    if hit:
        problems.append(f"{locale}.description: trademark {hit.group(0)!r}")
    if "NinetyLens" not in data["description"]:
        problems.append(f"{locale}.description: brand missing")

    screens = data.get("screens", {})
    for screen in SCREENS:
        pair = screens.get(screen)
        if not (isinstance(pair, list) and len(pair) == 2 and all(isinstance(p, str) and p.strip() for p in pair)):
            problems.append(f"{locale}.screens.{screen}: need [headline, subhead]")
            continue
        headline, subhead = pair
        if headline.count("\n") != 1:
            problems.append(f"{locale}.screens.{screen}: headline must have exactly 2 lines (one \\n)")
        if max(units(line) for line in headline.split("\n")) > 26:
            problems.append(f"{locale}.screens.{screen}: headline line over 26 chars")
        if units(subhead) > 90:
            problems.append(f"{locale}.screens.{screen}: subhead over 90 chars")
    tagline = data.get("tagline", "")
    if not isinstance(tagline, str) or tagline.count("\n") != 1 or max(units(l) for l in tagline.split("\n")) > 28:
        problems.append(f"{locale}.tagline: exactly 2 lines, each <= 28 chars")
    return problems


def url_files(locale: str) -> dict:
    page = HOSTED_URL_LOCALES.get(locale)
    prefix = f"{BASE_URL}/{page}" if page else BASE_URL  # English pages live at the site root
    return {
        "marketing_url": prefix,
        "support_url": f"{prefix}/support",
        "privacy_url": f"{prefix}/privacy",
    }


def main(argv: list) -> int:
    if argv and argv[0] == "--check":
        files = [Path(a) for a in argv[1:]]
        write = False
    else:
        files = sorted(I18N.glob("*.json"))
        write = True
    all_problems = []
    loaded = []
    for file in files:
        data = json.loads(file.read_text(encoding="utf-8"))
        if data.get("locale") != file.stem:
            all_problems.append(f"{file.name}: locale field must equal the file name")
        all_problems += validate(data)
        loaded.append(data)
    if all_problems:
        print("\n".join(all_problems))
        return 1
    for data in loaded:
        counts = " ".join(f"{k}={units(data[k].strip())}/{LIMITS[k]}" for k in ("name", "subtitle", "keywords", "promotional_text", "description"))
        print(f"{data['locale']}: {counts}")
        if not write:
            continue
        for target in TARGETS:
            directory = target / data["locale"]
            directory.mkdir(parents=True, exist_ok=True)
            for key in TEXT_FIELDS:
                (directory / f"{key}.txt").write_text(data[key].strip() + "\n", encoding="utf-8")
            for key, value in url_files(data["locale"]).items():
                (directory / f"{key}.txt").write_text(value + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
