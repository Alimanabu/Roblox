#!/usr/bin/env python3
"""Собирает модули в один файл с заглушками Roblox и запускает тесты через luau CLI.
Использование: python3 tests/run.py [путь к luau]"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
MODULES = ["Config/Rarities", "Config/Creatures", "Config/Mutations", "Config/Capsules",
           "Config/Seasons", "Config/Levels", "Config/Upgrades", "Config/Rebirths", "Config/Monetization",
           "Config/Events", "Config/Daily", "Config/Achievements", "Config/Codes", "Config/Skins", "Config/Battles",
           "Util/Format", "Util/Formulas"]


def read(*path):
    return open(os.path.join(ROOT, *path)).read()


def run(spec, extra=()):
    out = [read("tests", "stubs.luau")]
    for name in MODULES:
        src = read("src", "shared", name + ".luau")
        out.append(f'__defs["{name}"] = function(script)\n{src}\nend\n')
    out.extend(extra)
    out.append(read("tests", spec))

    bundle = os.path.join(ROOT, "tests", ".bundle.luau")
    open(bundle, "w").write("\n".join(out))
    return subprocess.call([LUAU, bundle])


economy = run("economy.spec.luau")

services = []
for name in ["DataService", "MonetizationService"]:
    src = read("src", "server", "Services", name + ".luau")
    services.append(f'__defs["Services/{name}"] = function(script)\n{src}\nend\n')
# PlotService строит мир и в тесте не запускается: проверяем только его подписку на покупки.
plot = read("src", "server", "Services", "PlotService.luau")
services.append(f"__plotServiceSource = [=====[{plot}]=====]\n")
purchases = run("purchases.spec.luau", services)

sys.exit(economy or purchases)
