#!/usr/bin/env python3
"""Отрицательный тест таблицы перевода: пропуск en/ru/kk должен ронять проверку словаря.
Запуск: python -X utf8 tests/test_translations_negative.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run

real = run.translation_rows()


def failing(mutate):
    rows = [dict(r) for r in real]
    mutate(rows)
    run.translation_rows = lambda: rows
    return run.check_dictionary() == 1


cases = {
    "kk пустой": lambda rows: rows[5].update(kk=""),
    "ru пустой": lambda rows: rows[5].update(ru=""),
    "kk без параметра": lambda rows: rows[1].update(kk="Монета жеткіліксіз"),
    "kk с кириллицей в Source": lambda rows: rows[2].update(Source="Привет {title} {level}"),
}
bad = [name for name, mutate in cases.items() if not failing(mutate)]
run.translation_rows = lambda: real
assert run.check_dictionary() == 0, "исходная таблица должна проходить"
if bad:
    print("❌ не упало:", bad)
    sys.exit(1)
print(f"✅ Отрицательный тест: {len(cases)} поломок таблицы пойманы, исходная таблица проходит")
