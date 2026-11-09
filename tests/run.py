#!/usr/bin/env python3
"""Собирает модули в один файл с заглушками Roblox и запускает тесты через luau CLI.
Использование: python3 tests/run.py [путь к luau]"""
import csv, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
MODULES = ["Strings", "Config/Rarities", "Config/Creatures", "Config/Mutations", "Config/Capsules",
           "Config/Seasons", "Config/Levels", "Config/Upgrades", "Config/Rebirths", "Config/Monetization",
           "Config/Events", "Config/Daily", "Config/Achievements", "Config/Codes", "Config/Skins", "Config/Battles",
           "Util/Format", "Util/Formulas"]
# Всё остальное из shared: нужно, только когда запускается вся игра (world).
WORLD_MODULES = ["Remotes", "Config/Admins", "Config/Music", "Config/Social", "Config/Sounds", "Config/Tutorial",
                 "Util/CreatureModel"]


CYRILLIC = re.compile("[А-Яа-яЁё]")
# Языки перевода (09.11): английский — исходный текст, ru и kk — колонки таблицы. У каждого ключа есть все.
LANGS = ("ru", "kk")
PARAM = re.compile(r"\{(\w+)\}")
LITERAL = re.compile(r'"(?:[^"\\\n]|\\.)*"')
# Кириллицы в src нет нигде, кроме колонки ru таблицы перевода (09.11: язык продукта английский).
# Ключи, которые код собирает сам: "creature." .. id и т.п.
DYNAMIC_KEYS = ("creature.", "rarity.", "mutation.", "capsule.", "achievement.", "quest.", "wheel.", "event.", "level.",
                "rebirth.", "skin.", "tutorial.", "upgrade.", "floor.", "pass.", "product.", "season.", "battle.rank.")
NOT_KEYS = ("rbxassetid.",)


def read(*path):
    return open(os.path.join(ROOT, *path), encoding="utf-8").read()


def module_def(name, *path):
    return f'__defs["{name}"] = function(script)\n{read(*path)}\nend\n'


def run(spec, extra=()):
    out = [read("tests", "stubs.luau")]
    for name in MODULES:
        out.append(module_def(name, "src", "shared", name + ".luau"))
    out.extend(extra)
    out.append(read("tests", spec))

    bundle = os.path.join(ROOT, "tests", ".bundle.luau")
    open(bundle, "w", encoding="utf-8").write("\n".join(out))
    return subprocess.call([LUAU, bundle])


def folder_defs(folder, prefix):
    """Все модули папки src/<folder> как __defs["<prefix>путь"]."""
    defs = []
    base = os.path.join(ROOT, "src", folder)
    for path, _, names in os.walk(base):
        for name in names:
            if name.endswith(".luau"):
                rel = os.path.relpath(os.path.join(path, name), base).replace(os.sep, "/")
                module = rel.replace(".server.luau", "").replace(".client.luau", "").replace(".luau", "")
                defs.append(module_def(prefix + module, path, name))
    return defs


def lua(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def translation_rows():
    path = os.path.join(ROOT, "src", "localization", "Translations.csv")
    with open(path, encoding="utf-8", newline="") as file:
        return list(csv.DictReader(file))


def translation_entries():
    rows = ["{ Key = %s, Source = %s, Values = { %s } }"
            % (lua(r["Key"]), lua(r["Source"]), ", ".join("%s = %s" % (lang, lua(r[lang])) for lang in LANGS))
            for r in translation_rows()]
    return "__translationEntries = {\n" + ",\n".join(rows) + "\n}\n"


def world(spec, locale):
    """Запускает spec с настоящими сервером и клиентом на заглушке мира."""
    extra = [f'__LOCALE = "{locale}"\n', translation_entries(), read("tests", "world.luau")]
    extra += [module_def(name, "src", "shared", name + ".luau") for name in WORLD_MODULES]
    extra += folder_defs("server", "") + folder_defs("client", "client/")
    return run(spec, extra)


def check_dictionary():
    """Словарь и таблица перевода совпадают, в коде нет текстов мимо словаря."""
    problems = []
    entry = re.compile(r'^\t\["([^"]+)"\] = "((?:[^"\\]|\\.)*)",$', re.M)
    source = {key: text.replace('\\"', '"').replace("\\n", "\n")
              for key, text in entry.findall(read("src", "shared", "Strings.luau"))}
    rows = {row["Key"]: row for row in translation_rows()}
    if set(source) != set(rows):
        problems.append(f"словарь и таблица не совпадают: {sorted(set(source) ^ set(rows))}")
    seen = set()
    for key, row in rows.items():
        if key in source and row["Source"] != source[key]:
            problems.append(f"{key}: в таблице другой английский текст")
        if None in row:
            problems.append(f"{key}: лишнее поле в таблице, текст с запятой нужен в кавычках")
        for lang in LANGS:
            if not (row.get(lang) or "").strip():
                problems.append(f"{key}: нет перевода {lang}")
            elif set(PARAM.findall(row["Source"])) != set(PARAM.findall(row[lang])):
                problems.append(f"{key}: параметры перевода {lang} не совпадают")
            elif row["Source"].count(chr(10)) != row[lang].count(chr(10)):
                problems.append(f"{key}: число переносов строки в {lang} не совпадает")
        if CYRILLIC.search(row["Source"]):
            problems.append(f"{key}: русский текст в английском оригинале")
        pair = (row["Source"], row["Context"])
        if pair in seen:
            problems.append(f"{key}: Roblox не примет два одинаковых текста без Context")
        seen.add(pair)

    used = set()
    for path, _, names in os.walk(os.path.join(ROOT, "src")):
        for name in names:
            if not name.endswith(".luau"):
                continue
            lines = open(os.path.join(path, name), encoding="utf-8").read().splitlines()
            for number, line in enumerate(lines, 1):
                masked = LITERAL.sub(lambda m: "_" * len(m.group(0)), line)
                cut = masked.find("--")
                code = line if cut < 0 else line[:cut]
                used.update(re.findall(r'"([a-z]\w*(?:\.\w+)+)"', code))
                if CYRILLIC.search(line):
                    problems.append(f"{name}:{number}: текст мимо словаря")
    for key in used:
        if key not in source and not key.startswith(NOT_KEYS):
            problems.append(f"{key}: нет в словаре")
    unused = [key for key in source if key not in used and not key.startswith(DYNAMIC_KEYS)]
    if unused:
        problems.append(f"лишние строки в словаре: {unused}")

    for problem in problems:
        print("❌ " + problem)
    if not problems:
        print(f"✅ Словарь и таблица перевода: {len(source)} строк совпадают, текстов мимо словаря нет")
    return 1 if problems else 0


def main():
    economy = run("economy.spec.luau")
    dictionary = check_dictionary()

    services = []
    for name in ["DataService", "MonetizationService", "PolicyService"]:
        services.append(module_def("Services/" + name, "src", "server", "Services", name + ".luau"))
    # PlotService строит мир и в тесте не запускается: проверяем только его подписку на покупки.
    plot = read("src", "server", "Services", "PlotService.luau")
    services.append(f"__plotServiceSource = [=====[{plot}]=====]\n")
    purchases = run("purchases.spec.luau", services)

    strings = world("strings.spec.luau", "en-us")
    music = world("music.spec.luau", "en-us")
    screens = world("screens.spec.luau", "en-us")
    screens_ru = world("screens.spec.luau", "ru-ru")
    screens_kk = world("screens.spec.luau", "kk-kz")
    steal = world("steal.spec.luau", "en-us")
    policy = world("policy.spec.luau", "en-us")
    trade = world("trade.spec.luau", "en-us")
    trade_ru = world("trade.spec.luau", "ru-ru")
    trade_kk = world("trade.spec.luau", "kk-kz")
    rejoin = world("rejoin.spec.luau", "en-us")
    frames = world("frames.spec.luau", "en-us")
    loading = world("loading.spec.luau", "en-us")
    retention = world("retention.spec.luau", "en-us")
    retention_ru = world("retention.spec.luau", "ru-ru")
    retention_kk = world("retention.spec.luau", "kk-kz")

    return (economy or purchases or dictionary or strings or music or screens or screens_ru or screens_kk or steal or policy or trade or trade_ru or trade_kk
            or rejoin or frames or loading or retention or retention_ru or retention_kk)


if __name__ == "__main__":
    sys.exit(main())
