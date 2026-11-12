#!/usr/bin/env python3
"""Генератор tests/text_widths.luau — ширина знаков в долях кегля (em = TextSize) для проверки текста в layout.spec.luau.

Замер Pillow по файлам шрифтов установленного Roblox (%LOCALAPPDATA%/Roblox/Versions/<версия>/content/fonts):
  - знак есть в FredokaOne-Regular.ttf (шрифт игры) — его ширина;
  - эмодзи и значки (U+2190 и выше) — большее из TwemojiMozilla.ttf и RobloxEmoji.ttf;
  - остальное (кириллица, казахские буквы) — большее из SourceSansPro-Regular.ttf (запасной шрифт Roblox: этот файл стоит
    в списке запасных шрифтов внутри RobloxStudioBeta.exe) и Arimo-Regular.ttf (шире, для страховки);
  - знака нет ни в одном из этих шрифтов — 1,2 (широкий значок) с пометкой в таблице.
Знаки берутся из всех строк таблицы перевода (en, ru, kk) и цифр со знаками препинания. Классы (строчная и заглавная
латиница, кириллица, казахские, цифры, знаки, значки) получают коэффициент самого широкого знака класса — для знаков,
которых нет в таблице.

Запуск: python tests/gen_text_widths.py [--fonts <папка content/fonts>] [--date ГГГГ-ММ-ДД] [--check]
  --check — не писать, а сверить с tests/text_widths.luau (код 1, если отличается).
Нужны Pillow и fontTools (есть у Python314 на ПК офиса). Ширина в движке Roblox этим не мерится: у ключа Open Cloud нет права
luau-execution (13.11), поэтому источник — файлы шрифтов.
"""
import argparse, csv, datetime, glob, os, re, sys

from PIL import ImageFont
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "text_widths.luau")
EM = 1000
GAME = "FredokaOne-Regular.ttf"
EMOJI = ("TwemojiMozilla.ttf", "RobloxEmoji.ttf")
FALLBACK = ("SourceSansPro-Regular.ttf", "Arimo-Regular.ttf")
KAZAKH = "әғқңөұүһіӘҒҚҢӨҰҮҺІ"


def default_fonts():
    """Папка шрифтов самой новой версии Roblox, где есть FredokaOne."""
    pattern = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions", "*", "content", "fonts")
    found = [p for p in glob.glob(pattern) if os.path.exists(os.path.join(p, GAME))]
    if not found:
        sys.exit("Нет папки шрифтов Roblox с " + GAME + ": укажи --fonts")
    return max(found, key=os.path.getmtime)


def klass(ch):
    if ch.isdigit():
        return "digit"
    if ch == " ":
        return "space"
    if ch in KAZAKH:
        return "kk"
    if "а" <= ch.lower() <= "я" or ch.lower() == "ё":
        return "cyr_upper" if ch.isupper() else "cyr_lower"
    if "a" <= ch.lower() <= "z":
        return "latin_upper" if ch.isupper() else "latin_lower"
    if ord(ch) >= 0x2190:
        return "symbol"
    return "punct"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fonts", default=None)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    fonts = a.fonts or default_fonts()
    version = os.path.basename(os.path.dirname(os.path.dirname(fonts)))
    faces, cmaps = {}, {}
    for name in (GAME,) + EMOJI + FALLBACK:
        path = os.path.join(fonts, name)
        if os.path.exists(path):
            faces[name] = ImageFont.truetype(path, EM)
            cmaps[name] = TTFont(path, fontNumber=0).getBestCmap()

    def has(name, ch):
        return ord(ch) in cmaps.get(name, {})

    def width(ch):
        code = ord(ch)
        if code in (0xFE0F, 0x200D):
            return 0.0, "невидимый"
        if has(GAME, ch):
            return faces[GAME].getlength(ch) / EM, "FredokaOne"
        if code >= 0x2190:
            ws = [faces[n].getlength(ch) / EM for n in EMOJI if has(n, ch)]
            if ws:
                return max(ws), "эмодзи"
        ws = [faces[n].getlength(ch) / EM for n in FALLBACK if has(n, ch)]
        if ws:
            return max(ws), "SourceSansPro/Arimo"
        return 1.2, "нет в шрифтах (1,2)"

    texts = []
    with open(os.path.join(ROOT, "src", "localization", "Translations.csv"), encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            texts += [row["Source"], row["ru"], row["kk"]]
    chars = sorted({c for t in texts for c in t} | set("0123456789:/.,!?+-$%() •"))
    table, classes = {}, {}
    for ch in chars:
        if ch in "\r\n\t{}\"\\":
            continue
        w, src = width(ch)
        table[ch] = (w, src)
        classes.setdefault(klass(ch), []).append(w)

    # Сверка: строка целиком (с кернингом, по прогонам одного шрифта) против суммы знаков.
    worst = (0.0, "")
    for t in texts:
        t = re.sub(r"\{\w+\}", "", t).replace("\n", " ")
        if not t.strip():
            continue
        total = sum(table.get(c, (1.2, ""))[0] for c in t)
        runs, cur, curf = [], "", None
        for c in t:
            f = GAME if has(GAME, c) else None
            if f != curf and cur:
                runs.append((curf, cur))
                cur = ""
            curf = f
            cur += c
        if cur:
            runs.append((curf, cur))
        real = sum(faces[f].getlength(s) / EM if f else sum(table.get(c, (1.2, ""))[0] for c in s) for f, s in runs)
        if total > 0 and (real - total) / total > worst[0]:
            worst = ((real - total) / total, t)

    lines = ["-- Ширина знаков в долях кегля (em = TextSize). СГЕНЕРИРОВАНО tests/gen_text_widths.py, не править руками: замер " + a.date + ",",
             "-- Pillow по файлам шрифтов Roblox " + version + "\\content\\fonts: FredokaOne-Regular.ttf; знаков без FredokaOne —",
             "-- большее из SourceSansPro-Regular.ttf (запасной шрифт Roblox по списку в RobloxStudioBeta.exe) и Arimo-Regular.ttf;",
             "-- эмодзи — большее из TwemojiMozilla.ttf и RobloxEmoji.ttf. Не замер в движке: у ключа нет права luau-execution.",
             "-- Сверка: строка целиком с кернингом шире суммы знаков самое большее на %.2f %%." % (worst[0] * 100),
             "-- Знака нет в таблице — коэффициент его класса (самый широкий знак класса).",
             "return {", '\tdate = "' + a.date + '",',
             '\tsource = "Pillow, Roblox ' + version + ', FredokaOne + max(SourceSansPro, Arimo), эмодзи max(Twemoji, RobloxEmoji)",',
             "\tclasses = {"]
    for k in sorted(classes):
        lines.append("\t\t%s = %.4f, -- %d знаков, средний %.4f" % (k, max(classes[k]), len(classes[k]), sum(classes[k]) / len(classes[k])))
    lines += ["\t},", "\tchars = {"]
    for ch, (w, src) in table.items():
        lit = ch.replace("\\", "\\\\").replace('"', '\\"')
        lines.append('\t\t["%s"] = %.4f, -- %s' % (lit, w, src))
    lines += ["\t},", "}", ""]
    text = "\n".join(lines)
    missing = [ch for ch, (w, src) in table.items() if src.startswith("нет")]
    print("шрифты:", fonts)
    print("знаков %d, без шрифта %d: %s" % (len(table), len(missing), " ".join("%s U+%04X" % (c, ord(c)) for c in missing)))
    if a.check:
        old = open(OUT, encoding="utf-8").read().replace("\r\n", "\n")
        same = old == text
        print("сверка с tests/text_widths.luau:", "совпадает" if same else "ОТЛИЧАЕТСЯ")
        return 0 if same else 1
    open(OUT, "w", encoding="utf-8", newline="\n").write(text)
    print("записано", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
