#!/usr/bin/env python3
"""Отрицательный тест урока 7: Theme.show без ключа, плашка с ✕ без show, пустой набор и ключ nil должны ронять
проверку check_show_keys; чистый набор и закомментированный вызов без ключа её проходят.
Запуск: python -X utf8 tests/test_show_keys_negative.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run

PLATE = "src/client/Ui/Plate.luau"
OK = "Theme.closable(frame)\nTheme.show(frame, visible, key)\n"

cases = {
    "show без ключа": {PLATE: "Theme.closable(frame)\nTheme.show(frame, true)\n"},
    "ключ nil": {PLATE: "Theme.closable(frame)\nTheme.show(frame, true, nil)\n"},
    "плашка с ✕ без show": {PLATE: OK + "Theme.closable(other)\n"},
    "пустой набор": {},
    "нет ни одной плашки с ✕": {PLATE: "Theme.show(frame, visible, key)\n"},
    "вызов на нескольких строках без ключа": {PLATE: "Theme.closable(frame)\nTheme.show(\n\tframe,\n\tf(a, b)\n)\n"},
}
bad = [name for name, files in cases.items() if run.check_show_keys(files) != 1]
good = run.check_show_keys({PLATE: OK + "-- Theme.show(frame, true) only in a comment\nTheme.show(x, f(a, b), g(c))\n",
                            "src/client/Ui/Theme.luau": "function Theme.show(frame, visible, key)"})
if bad or good != 0:
    print("❌ не упало:", bad, "чистый набор:", good)
    sys.exit(1)
print(f"✅ Отрицательный тест урока 7: {len(cases)} поломок пойманы, чистый набор проходит")
