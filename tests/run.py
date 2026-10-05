#!/usr/bin/env python3
"""Собирает shared-модули в один файл с заглушками Roblox и запускает тесты через luau CLI.
Использование: python3 tests/run.py [путь к luau]"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
MODULES = ["Config/Rarities", "Config/Creatures", "Config/Mutations", "Config/Capsules",
           "Config/Levels", "Config/Upgrades", "Config/Rebirths", "Config/Monetization",
           "Config/Events", "Config/Daily",
           "Util/Format", "Util/Formulas"]

out = [open(os.path.join(ROOT, "tests", "stubs.luau")).read()]
for name in MODULES:
    src = open(os.path.join(ROOT, "src", "shared", name + ".luau")).read()
    out.append(f'__defs["{name}"] = function(script)\n{src}\nend\n')
out.append(open(os.path.join(ROOT, "tests", "economy.spec.luau")).read())

bundle = os.path.join(ROOT, "tests", ".bundle.luau")
open(bundle, "w").write("\n".join(out))
sys.exit(subprocess.call([LUAU, bundle]))
