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
WORLD_MODULES = ["Remotes", "Config/Admins", "Config/Music", "Config/Social", "Config/Sounds", "Config/Tutorial", "Config/Funnels",
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

# Присвоение в текстовое поле: "Text = ..." или "X.Text = ..." (не RichText, не PlaceholderText).
TEXT_ASSIGN = re.compile(r"(?<![A-Za-z])(Text|ObjectText|ActionText|ToolTip)\s*=(?!=)\s*(.+)")
# Что возвращает таблицу-сообщение, а не строку: S.m, S.join и функции, которые их возвращают.
MESSAGE_CALLS = re.compile(r"(?<!\w)S\.(?:m|join)\(|(?<!\w)labelText\(")
STRING_WRAPPERS = ("S.t(", "S.text(", "S.forPlayer(")


def strip_wrapped(rhs):
    """Убирает из выражения вызовы S.t(...)/S.text(...): внутри них таблица-сообщение законна."""
    for wrapper in STRING_WRAPPERS:
        while wrapper in rhs:
            start = rhs.index(wrapper)
            depth, i = 0, start + len(wrapper) - 1
            while i < len(rhs):
                depth += {"(": 1, ")": -1}.get(rhs[i], 0)
                if depth == 0:
                    break
                i += 1
            rhs = rhs[:start] + "_" + rhs[i + 1:]
    return rhs


def check_text_assignments(files=None):
    """В Text, ObjectText, ActionText, ToolTip нельзя писать таблицу-сообщение S.m (ошибка Roblox
    "string expected, got table", PlotService:611, 10.11): её отдают в S.t/S.text или S.apply.
    files: {имя: текст} для отрицательного теста. Печатает список всех присвоений с отметкой."""
    problems, listing = [], []
    if files is None:
        files = {}
        for path, _, names in os.walk(os.path.join(ROOT, "src")):
            for name in names:
                if name.endswith(".luau"):
                    full = os.path.join(path, name)
                    files[os.path.relpath(full, ROOT).replace(os.sep, "/")] = open(full, encoding="utf-8").read()
    for name, text in sorted(files.items()):
        for number, line in enumerate(text.splitlines(), 1):
            code = line.split("--")[0]
            match = TEXT_ASSIGN.search(code)
            if not match:
                continue
            bad = bool(MESSAGE_CALLS.search(strip_wrapped(match.group(2))))
            listing.append(f"{name}:{number} {'ОШИБКА' if bad else 'проверено'}")
            if bad:
                problems.append(f"{name}:{number}: в {match.group(1)} пишется таблица-сообщение, нужна S.apply или S.t/S.text")
    for problem in problems:
        print("❌ " + problem)
    if not problems:
        print(f"✅ Присвоения Text: {len(listing)} мест в src, таблицы-сообщения вместо строки нет")
    if os.environ.get("TEXT_LIST"):
        print("\n".join(listing))
    return 1 if problems else 0


FUNNEL_CALLS = ("LogFunnelStepEvent", "LogOnboardingFunnelStepEvent")
FRAME_LOOPS = ("Heartbeat", "RenderStepped", "Stepped", "PreSimulation", "PostSimulation")


def check_funnel_calls(files=None):
    """Вызовы воронок аналитики стоят только в AnalyticsService, а сам он не подписан на кадры
    (Heartbeat и подобные): шаг воронки шлётся по событию, а не каждый кадр.
    files: {имя: текст} для отрицательного теста. Печатает таблицу вызовов."""
    problems, listing = [], []
    if files is None:
        files = {}
        for path, _, names in os.walk(os.path.join(ROOT, "src")):
            for name in names:
                if name.endswith(".luau"):
                    full = os.path.join(path, name)
                    files[os.path.relpath(full, ROOT).replace(os.sep, "/")] = open(full, encoding="utf-8").read()
    for name, text in sorted(files.items()):
        is_service = name.endswith("Services/AnalyticsService.luau")
        for number, line in enumerate(text.splitlines(), 1):
            code = line.split("--")[0]
            if any(call in code for call in FUNNEL_CALLS):
                listing.append(f"{name}:{number}")
                if not is_service:
                    problems.append(f"{name}:{number}: вызов воронки вне AnalyticsService")
            if is_service and any(loop in code for loop in FRAME_LOOPS):
                problems.append(f"{name}:{number}: AnalyticsService подписан на кадр")
    # Проверка не имеет права пройти на пустом наборе: сервис найден, оба метода воронок в нём есть.
    service = [name for name in files if name.endswith("Services/AnalyticsService.luau")]
    if not files:
        problems.append("набор файлов пуст: проверять нечего")
    elif not service:
        problems.append("Services/AnalyticsService.luau не найден")
    else:
        in_service = [name for name in listing if name.startswith(service[0] + ":")]
        if len(in_service) < len(FUNNEL_CALLS):
            problems.append(f"в AnalyticsService {len(in_service)} вызовов воронок, нужно не меньше {len(FUNNEL_CALLS)}")
        for call in FUNNEL_CALLS:
            if not any(call in files[service[0]].splitlines()[int(n.rsplit(":", 1)[1]) - 1] for n in in_service):
                problems.append(f"в AnalyticsService нет вызова {call}")
    for problem in problems:
        print("❌ " + problem)
    if not problems:
        print(f"✅ Вызовы воронок: {len(listing)} мест ({', '.join(listing)}), все в AnalyticsService, кадровых циклов нет")
    return 1 if problems else 0


SHOW_CALL = "Theme.show("
CLOSABLE_CALL = "Theme.closable("


def call_args(text, start):
    """Аргументы вызова верхнего уровня, начиная со скобки text[start] == "(": список строк."""
    depth, args, current, i = 0, [], "", start
    while i < len(text):
        ch = text[i]
        if ch in "([{":
            depth += 1
            if depth == 1:
                i += 1
                continue
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                args.append(current.strip())
                return args
        elif ch == "," and depth == 1:
            args.append(current.strip())
            current = ""
            i += 1
            continue
        current += ch
        i += 1
    return args


def check_show_keys(files=None):
    """Урок 7: у каждой плашки с ✕ флаг «закрыто» привязан к причине показа. Сверка по каждой плашке:
    для каждого Theme.closable(X) в файле есть Theme.show(X, видна, ключ) в том же файле с непустым ключом,
    и каждый Theme.show передаёт ключ. Общее число вызовов не считается: лишний show в одном файле
    не прикрывает плашку без show в другом. Пустой набор не проходит (урок 11). files: {имя: текст}."""
    problems, listing, plates = [], [], 0
    if files is None:
        files = {}
        for path, _, names in os.walk(os.path.join(ROOT, "src", "client")):
            for name in names:
                if name.endswith(".luau"):
                    full = os.path.join(path, name)
                    files[os.path.relpath(full, ROOT).replace(os.sep, "/")] = open(full, encoding="utf-8").read()

    def calls(code, call):
        out, at = [], code.find(call)
        while at >= 0:
            out.append((code.count("\n", 0, at) + 1, call_args(code, at + len(call) - 1)))
            at = code.find(call, at + 1)
        return out

    for name, text in sorted(files.items()):
        if name.endswith("Ui/Theme.luau"):
            continue  # там определения, а не вызовы
        code = "\n".join(line.split("--")[0] for line in text.splitlines())
        keyed = set()
        for number, args in calls(code, SHOW_CALL):
            if len(args) < 3 or args[2] in ("", "nil"):
                problems.append(f"{name}:{number}: Theme.show без ключа причины показа (урок 7)")
            elif args:
                keyed.add(args[0])
        for number, args in calls(code, CLOSABLE_CALL):
            plates += 1
            frame = args[0] if args else ""
            if frame in keyed:
                listing.append(f"{frame} ({name}:{number})")
            else:
                problems.append(f"{name}:{number}: плашка {frame} с ✕ без Theme.show({frame}, видна, ключ) в том же файле")
    if plates == 0:
        problems.append("не найдено ни одной плашки Theme.closable: проверять нечего")
    for problem in problems:
        print("❌ " + problem)
    if not problems:
        print(f"✅ Плашки с ✕: {plates}, у каждой Theme.show с ключом: {', '.join(listing)}")
    return 1 if problems else 0


def negative_show_keys():
    """Отрицательный тест урока 7 (tests/test_show_keys_negative.py) в общем прогоне."""
    return subprocess.call([sys.executable, "-X", "utf8", os.path.join(ROOT, "tests", "test_show_keys_negative.py")])


def main():
    economy = run("economy.spec.luau")
    dictionary = check_dictionary()
    text_assign = check_text_assignments()
    funnel_calls = check_funnel_calls()
    show_keys = check_show_keys()
    show_keys_negative = negative_show_keys()

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
    funnel = world("funnel.spec.luau", "en-us")
    frames = world("frames.spec.luau", "en-us")
    loading = world("loading.spec.luau", "en-us")
    retention = world("retention.spec.luau", "en-us")
    retention_ru = world("retention.spec.luau", "ru-ru")
    retention_kk = world("retention.spec.luau", "kk-kz")
    layout = world("layout.spec.luau", "en-us")
    layout_ru = world("layout.spec.luau", "ru-ru")
    layout_kk = world("layout.spec.luau", "kk-kz")
    onboarding = world("onboarding.spec.luau", "en-us")
    onboarding_ru = world("onboarding.spec.luau", "ru-ru")
    onboarding_kk = world("onboarding.spec.luau", "kk-kz")

    return (economy or purchases or dictionary or text_assign or funnel_calls or strings or music or screens or screens_ru or screens_kk or steal or policy or trade or trade_ru or trade_kk
            or rejoin or funnel or frames or loading or retention or retention_ru or retention_kk or layout or layout_ru or layout_kk
            or show_keys or show_keys_negative or onboarding or onboarding_ru or onboarding_kk)


if __name__ == "__main__":
    sys.exit(main())
