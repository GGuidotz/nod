#!/usr/bin/env python3
"""Controlla le traduzioni: ogni L("…") nei sorgenti deve avere una voce in en/fr/es Localizable.strings.
    python3 tools/check-strings.py            elenca le chiavi mancanti (esce con 1 se ce ne sono)
    python3 tools/check-strings.py --keys     stampa tutte le chiavi (JSON)
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ["en", "fr", "es"]
CALL = re.compile(r'(?<![\w.])L\(\s*"((?:[^"\\]|\\.)*)"')

def keys():
    found = {}
    for name in sorted(os.listdir(os.path.join(ROOT, "Sources"))):
        if name.endswith(".swift"):
            text = open(os.path.join(ROOT, "Sources", name), encoding="utf-8").read()
            for m in CALL.finditer(text):
                found.setdefault(m.group(1), name)
    return found

def table(lang):
    path = os.path.join(ROOT, "Localization", f"{lang}.lproj", "Localizable.strings")
    if not os.path.exists(path):
        return {}
    text = open(path, encoding="utf-8").read()
    return {m.group(1): m.group(2) for m in re.finditer(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', text, re.M)}

def placeholders(s):
    return sorted(re.findall(r"%(?:\.\d+)?[@dlf]+", s))

if __name__ == "__main__":
    k = keys()
    if "--keys" in sys.argv:
        print(json.dumps(sorted(k), ensure_ascii=False, indent=1))
        sys.exit(0)
    bad = 0
    for lang in LANGS:
        t = table(lang)
        for key in sorted(k):
            if key not in t:
                print(f"{lang}: manca \"{key}\" ({k[key]})"); bad += 1
            elif placeholders(key) != placeholders(t[key]):
                print(f"{lang}: segnaposto diversi in \"{key}\""); bad += 1
        for extra in sorted(set(t) - set(k)):
            print(f"{lang}: chiave non usata \"{extra}\"")
    print(f"{len(k)} chiavi, {bad} problemi")
    sys.exit(1 if bad else 0)
