#!/usr/bin/env python3
"""Builds assets/content/lessons.json from tools/base_lessons.json plus the
text files in tools/content/ (one file per language+level, e.g. en_beginner.txt).

Text format (blank lines and lines starting with // are ignored):
  ## Lesson title | difficulty(1-3)
  English item : target | bangla | english gloss | example
  Japanese item: target | romaji | bangla | english gloss | example (English) | alt1,alt2

Each lesson must have exactly 3 items. Run: python3 tools/build_lessons.py
Exits non-zero (and writes nothing) if validation fails.
"""
import json, re, sys, copy
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BASE = json.loads((ROOT / "base_lessons.json").read_text(encoding="utf-8"))
OUT = ROOT.parent / "assets" / "content" / "lessons.json"

HIRA = re.compile(r"^[ぁ-ゖ]+$")
KATA = re.compile(r"^[ァ-ヺー]+$")
KANA = re.compile(r"^[ぁ-ゖァ-ヺー]+$")

errors = []
def err(msg): errors.append(msg)

def parse(path):
    lang, level = path.stem.split("_", 1)
    lessons, cur = [], None
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("//"):
            continue
        if line.startswith("##"):
            title, _, diff = line[2:].partition("|")
            cur = {"language": lang, "level": level, "title": title.strip(),
                   "difficulty": int(diff.strip() or 1), "items": []}
            lessons.append(cur)
            continue
        if cur is None:
            err(f"{path.name}:{n} item before any lesson header"); continue
        p = [x.strip() for x in line.split("|")]
        if lang == "en":
            if len(p) != 4: err(f"{path.name}:{n} expected 4 fields, got {len(p)}: {line}"); continue
            cur["items"].append({"target": p[0], "meaningBn": p[1], "meaningEn": p[2], "example": p[3]})
        else:
            if len(p) not in (5, 6): err(f"{path.name}:{n} expected 5-6 fields, got {len(p)}: {line}"); continue
            alts = [a.strip() for a in p[5].split(",") if a.strip()] if len(p) == 6 else []
            cur["items"].append({"target": p[0], "reading": p[1], "meaningBn": p[2],
                                 "meaningEn": p[3], "example": p[4], "alternatives": alts})
    return lessons

out = copy.deepcopy(BASE)
lessons = out["lessons"]
next_order = {}
for l in lessons:
    k = (l["language"], l["level"])
    next_order[k] = max(next_order.get(k, 0), l["order"])

level_ids = {lang["id"]: [lv["id"] for lv in lang["levels"]] for lang in out["languages"]}
for path in sorted((ROOT / "content").glob("*.txt")):
    for les in parse(path):
        k = (les["language"], les["level"])
        if les["level"] not in level_ids.get(les["language"], []):
            err(f"{path.name}: unknown level {k}"); continue
        next_order[k] = next_order.get(k, 0) + 1
        les["order"] = next_order[k]
        les["id"] = f"{les['language']}_{les['level']}_{les['order']:02d}"
        ordered = {key: les[key] for key in ("id", "language", "level", "order", "title", "difficulty", "items")}
        lessons.append(ordered)

# ---- validation over the full set ----
seen_target, seen_bn, seen_ids = {}, {}, set()
def norm(s): return re.sub(r"[\s.,!?;:'\"。、！？]", "", s.lower())
for l in lessons:
    if l["id"] in seen_ids: err(f"duplicate lesson id {l['id']}")
    seen_ids.add(l["id"])
    if len(l["items"]) != 3: err(f"{l['id']} has {len(l['items'])} items (need 3)")
    if l["difficulty"] not in (1, 2, 3): err(f"{l['id']} bad difficulty")
    for it in l["items"]:
        for f in ("target", "meaningBn", "meaningEn"):
            if not it.get(f): err(f"{l['id']} empty {f}: {it}")
        t, bn = norm(it["target"]), it["meaningBn"].strip()
        key = (l["language"], t)
        if key in seen_target: err(f"duplicate target '{it['target']}' in {l['id']} and {seen_target[key]}")
        seen_target[key] = l["id"]
        key = (l["language"], bn)
        if key in seen_bn: err(f"duplicate Bangla meaning '{bn}' ({it['target']}) in {l['id']} and {seen_bn[key]}")
        seen_bn[key] = l["id"]
        if not re.search(r"[ঀ-৿]", bn): err(f"{l['id']} Bangla meaning has no Bengali letters: {bn}")
        if l["language"] == "ja":
            tg = it["target"]
            if l["level"] == "hiragana" and not HIRA.match(tg): err(f"{l['id']} hiragana level target not pure hiragana: {tg}")
            elif l["level"] == "katakana" and not KATA.match(tg): err(f"{l['id']} katakana level target not pure katakana: {tg}")
            elif not KANA.match(tg.replace("ー", "ー")) and l["level"] in ("n5", "n4"):
                err(f"{l['id']} target must be kana only (put kanji in alternatives): {tg}")
            if not re.match(r"^[a-z' ]+$", it.get("reading", "")): err(f"{l['id']} bad romaji: {it.get('reading')}")
            if not re.search(r"[぀-ヿ]", it.get("example", "")): err(f"{l['id']} example has no Japanese: {it}")
        else:
            if not it.get("example"): err(f"{l['id']} missing example for {it['target']}")

if errors:
    print(f"{len(errors)} problem(s):")
    for e in errors[:80]: print(" -", e)
    sys.exit(1)

OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
from collections import Counter
c = Counter((l["language"], l["level"]) for l in lessons)
total = len(lessons)
print(f"OK: {total} lessons, {total*9} tasks (3 activities x 3 questions each)")
for k, v in sorted(c.items()): print(f"  {k[0]}/{k[1]}: {v}")
