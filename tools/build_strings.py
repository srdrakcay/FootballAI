"""Builds Sources/AppUI/Resources/Localizable.xcstrings and checks it against the Swift sources."""
import glob, json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from strings_table import S

ROOT = Path(__file__).resolve().parent.parent
LANGS = ["en", "tr", "de", "es", "fr"]

def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}

def entry(values):
    localizations = {}
    for lang, value in zip(LANGS, values):
        if isinstance(value, tuple):
            one, other = value
            localizations[lang] = {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}
        else:
            localizations[lang] = unit(value)
    return {"extractionState": "manual", "localizations": localizations}

def normalize(key):
    return re.sub(r"%(?:\d\$)?(?:lld|@)", "#", key)

# 1. every row is complete and placeholders agree across languages
errors = []
for key, values in S.items():
    if len(values) != len(LANGS):
        errors.append(f"{key}: expected {len(LANGS)} languages")
        continue
    expected = len(re.findall(r"%(?:\d\$)?(?:lld|@)", key))
    for lang, value in zip(LANGS, values):
        for text in (value if isinstance(value, tuple) else (value,)):
            count = len(re.findall(r"%(?:\d\$)?(?:lld|@)", text))
            if count != expected and not (isinstance(value, tuple) and count <= expected):
                errors.append(f"{key} [{lang}]: {count} placeholders, key has {expected}")

# 2. every key used in Swift exists
used = set()
for path in glob.glob(str(ROOT / "Sources/AppUI/**/*.swift"), recursive=True):
    source = open(path).read()
    for match in re.finditer(r'(?:Text|String)\((?:localized: )?"((?:[^"\\]|\\.)*)"(?:, bundle: \.module)', source):
        key = match.group(1)
        # replace each \( ... ) interpolation (balanced parentheses) with #
        out, depth, i = "", 0, 0
        while i < len(key):
            if key.startswith("\\(", i) and depth == 0:
                depth, i = 1, i + 2
                while depth and i < len(key):
                    depth += {"(": 1, ")": -1}.get(key[i], 0)
                    i += 1
                out += "#"
            else:
                out += key[i]; i += 1
        used.add(out)
table = {normalize(k): k for k in S}
missing = sorted(used - set(table))
unused = sorted(set(table) - used)
errors += [f"missing translation for key used in Swift: {k}" for k in missing]
if errors:
    print("\n".join(errors)); sys.exit(1)

catalog = {"sourceLanguage": "en", "version": "1.0", "strings": {k: entry(v) for k, v in sorted(S.items())}}
target = ROOT / "Sources/AppUI/Resources/Localizable.xcstrings"
target.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
print(f"wrote {len(S)} keys x {len(LANGS)} languages; unused keys: {unused or 'none'}")
