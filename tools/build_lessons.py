#!/usr/bin/env python3
"""Builds assets/content/lessons.json from tools/base_lessons.json plus the
text files in tools/content/ (one file per language+level, e.g. en_beginner.txt).

Text format (blank lines and lines starting with // are ignored):
  ## Lesson title | difficulty(1-3)
  English item : target | bangla | english gloss | example
  Japanese item: target | romaji | bangla | english gloss | example (English) | alt1,alt2

An item line may end with an optional emoji field written as "@🍎" (used by the kids levels).
Each lesson must have exactly 3 items. Run: python3 tools/build_lessons.py

The script also decides, for every lesson, which kind of task each question is
(see KINDS / PATTERNS below) and writes it to the "tasks" field, so the app and
the Cloud Function only read the result and never re-implement the rules.
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
        emoji = None
        if p and p[-1].startswith("@"):
            emoji = p.pop()[1:].strip()
        if lang == "en":
            if len(p) != 4: err(f"{path.name}:{n} expected 4 fields, got {len(p)}: {line}"); continue
            item = {"target": p[0], "meaningBn": p[1], "meaningEn": p[2], "example": p[3]}
            if emoji: item["emoji"] = emoji
            cur["items"].append(item)
        else:
            if len(p) not in (5, 6): err(f"{path.name}:{n} expected 5-6 fields, got {len(p)}: {line}"); continue
            alts = [a.strip() for a in p[5].split(",") if a.strip()] if len(p) == 6 else []
            item = {"target": p[0], "reading": p[1], "meaningBn": p[2],
                    "meaningEn": p[3], "example": p[4], "alternatives": alts}
            if emoji: item["emoji"] = emoji
            cur["items"].append(item)
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


def norm(s): return re.sub(r"[\s.,!?;:'\"。、！？]", "", s.lower())

# ---- derived fields: sentence, cloze, tier, tasks ----
# Task kinds. The app (lib/data/catalog) and the Cloud Function (functions/src/evaluate.ts)
# know how to build and check each kind; they just read lesson["tasks"].
#   speaking : readAloud | translateSpeak | sentenceSpeak
#   listening: meaning | word | sentenceBlank | sentenceWord
#   writing  : dictation | translateType | cloze | unscramble | sentenceDictation
PATTERNS = {
    "speaking": {1: ["readAloud", "readAloud", "readAloud"],
                 2: ["readAloud", "readAloud", "translateSpeak"],
                 3: ["readAloud", "translateSpeak", "sentenceSpeak"],
                 4: ["translateSpeak", "sentenceSpeak", "translateSpeak"],
                 5: ["sentenceSpeak", "translateSpeak", "sentenceSpeak"]},
    "listening": {1: ["meaning", "word", "meaning"],
                  2: ["word", "meaning", "sentenceBlank"],
                  3: ["sentenceBlank", "meaning", "sentenceWord"],
                  4: ["sentenceWord", "word", "sentenceWord"],
                  5: ["sentenceWord", "meaning", "sentenceWord"]},
    "writing": {1: ["dictation", "dictation", "translateType"],
                2: ["dictation", "translateType", "cloze"],
                3: ["translateType", "cloze", "unscramble"],
                4: ["cloze", "unscramble", "sentenceDictation"],
                5: ["unscramble", "sentenceDictation", "translateType"]},
}
# Each activity starts on a different item so the same sentence is not repeated
# in Speaking, Listening and Writing at the same question number.
ITEM_SHIFT = {"speaking": 0, "listening": 1, "writing": 2}
# Where a level starts on the 1..5 difficulty ladder (it then rises inside the level).
LEVEL_BASE = {"kids": 0, "beginner": 0, "hiragana": 0, "katakana": 0,
              "elementary": 1, "n5": 1, "intermediate": 2, "n4": 2, "mext": 2,
              "advanced": 3, "ielts": 2, "n3": 3, "n2": 4, "n1": 4}
BLANK = {"en": "_____", "ja": "＿＿＿"}
JA_SENTENCE = re.compile(r"^[ぁ-ゖァ-ヺー、。！？\s…「」・]+$")

def sentence_of(lang, example):
    return example.split(" (")[0].strip() if lang == "ja" else example.strip()

def make_cloze(lang, target, sentence):
    if lang == "en":
        if len(target.split()) > 3: return None
        core = target.rstrip(".?!")
        m = re.search(r"(?<![A-Za-z'])" + re.escape(core) + r"(?![A-Za-z'])", sentence, re.I)
        if not m or not core: return None
        out = sentence[:m.start()] + BLANK["en"] + sentence[m.end():]
    else:
        i = sentence.find(target)
        if i < 0: return None
        out = sentence[:i] + BLANK["ja"] + sentence[i + len(target):]
    rest = out.replace(BLANK[lang], "")
    return out if len(re.sub(r"[\s.,!?。、！？]", "", rest)) >= 1 else None

def n_words(sentence): return len(sentence.split())

def resolve(kind, lang, it):
    """Falls back to an easier kind when the item cannot support the wanted one."""
    sent, cloze = it["sentence"], it.get("cloze")
    same = norm(sent) == norm(it["target"])
    while True:
        if kind == "sentenceSpeak" and (same or (lang == "en" and n_words(sent) < 3)): kind = "translateSpeak"
        elif kind in ("sentenceBlank", "sentenceWord") and (not cloze): kind = "word"
        elif kind == "cloze" and not cloze: kind = "translateType"
        elif kind == "unscramble" and not (lang == "en" and 3 <= n_words(sent) <= 12): kind = "cloze"
        elif kind == "sentenceDictation" and (same or (lang == "en" and n_words(sent) < 3)): kind = "translateType"
        else: return kind

by_level = {}
for l in lessons: by_level.setdefault((l["language"], l["level"]), []).append(l)
for (lang, level), group in by_level.items():
    group.sort(key=lambda x: x["order"])
    n = len(group)
    for pos, l in enumerate(group):
        for it in l["items"]:
            it["sentence"] = sentence_of(lang, it["example"])
            c = make_cloze(lang, it["target"], it["sentence"])
            if c: it["cloze"] = c
        tier = 1 + min(4, LEVEL_BASE.get(level, 0) + (3 * pos) // max(n, 1))
        l["tier"] = tier
        l["difficulty"] = 1 if tier <= 2 else (2 if tier <= 4 else 3)
        l["tasks"] = {
            act: [{"kind": resolve(PATTERNS[act][tier][i], lang, l["items"][(i + ITEM_SHIFT[act]) % 3]),
                   "item": (i + ITEM_SHIFT[act]) % 3} for i in range(3)]
            for act in ("speaking", "listening", "writing")
        }

# ---- validation over the full set ----
seen_target, seen_bn, seen_ids = {}, {}, set()
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
            elif not KANA.match(tg) and l["level"] in ("n5", "n4", "mext", "kids"):
                err(f"{l['id']} target must be kana only (put kanji in alternatives): {tg}")
            if not re.match(r"^[a-z' ]+$", it.get("reading", "")): err(f"{l['id']} bad romaji: {it.get('reading')}")
            if not re.search(r"[぀-ヿ]", it.get("example", "")): err(f"{l['id']} example has no Japanese: {it}")
            if not JA_SENTENCE.match(it["sentence"]): err(f"{l['id']} Japanese example must be kana only (no kanji/latin): {it['sentence']}")
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
