#!/usr/bin/env python3
"""Отрицательный тест урока 10(в): старая логика воронки обучения (шаг уходит один раз после действия, сравнением
«было-стало», только последний) склеивает шаги 4 и 5, когда награда дня забрана заранее. tests/funnel.spec.luau
на такой логике должен упасть именно на проверке «шаги 4 и 5»; на настоящем коде — пройти.
Файлы проекта не меняются: подмена идёт в собранном для luau тексте. Запуск: python -X utf8 tests/test_funnel_glue_negative.py [luau]
[--old-only]: только старая логика (так зовёт run.py: настоящий код там уже проверяет funnel.spec)."""
import os, subprocess, sys, tempfile
OLD_ONLY = "--old-only" in sys.argv
sys.argv = [a for a in sys.argv if a != "--old-only"]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run

ANALYTICS = os.path.join("Services", "AnalyticsService.luau")
TUTORIAL = os.path.join("Services", "TutorialService.luau")
# Старая отправка: только последний шаг (так было до a5a1361, AnalyticsService.luau:100-107 на 91c8e8e).
ONE_STEP_NEW = """	while funnel.onboarding < target do
		local step = funnel.onboarding + 1
		funnel.onboarding = step
		safe(Analytics.LogOnboardingFunnelStepEvent, player, step, Funnels.ONBOARDING[step])
	end"""
ONE_STEP_OLD = """	if funnel.onboarding < target then
		funnel.onboarding = target
		safe(Analytics.LogOnboardingFunnelStepEvent, player, target, Funnels.ONBOARDING[target])
	end"""
# Старый вызов: не из finishStep по каждому шагу, а один раз после действия (сравнение «было-стало»).
CALL = "\tAnalyticsService.onboardingTo(player, data, tutorial.step)\n"
AFTER_ACTION = "\tTutorialService.settle(player, data)\nend"


def mutate(path, text):
    norm = text.replace("\r\n", "\n")
    if path.endswith(ANALYTICS):
        assert norm.count(ONE_STEP_NEW) == 1, "в AnalyticsService не найден цикл отправки шагов обучения"
        return norm.replace(ONE_STEP_NEW, ONE_STEP_OLD)
    if path.endswith(TUTORIAL):
        assert norm.count(CALL) == 1, "в TutorialService не найден вызов воронки из finishStep"
        assert norm.count(AFTER_ACTION) == 1, "в TutorialService не найден конец onAction"
        norm = norm.replace(CALL, "")
        return norm.replace(AFTER_ACTION, "\tTutorialService.settle(player, data)\n" + CALL + "end")
    return text


def funnel(old_logic):
    """Прогон funnel.spec.luau (en-us): (код, вывод). old_logic=True — со старой логикой воронки."""
    original_read, original_run = run.read, run.run

    def read(*path):
        text = original_read(*path)
        return mutate(os.path.join(*path), text) if old_logic else text

    def capture(spec, extra=()):
        parts = [read("tests", "stubs.luau")]
        parts += [run.module_def(name, "src", "shared", name + ".luau") for name in run.MODULES]
        parts += list(extra) + [read("tests", spec)]
        handle, bundle = tempfile.mkstemp(suffix=".luau", prefix="funnel_glue_")
        with os.fdopen(handle, "w", encoding="utf-8") as file:
            file.write("\n".join(parts))
        try:
            done = subprocess.run([run.LUAU, bundle], capture_output=True, text=True, encoding="utf-8", errors="replace")
        finally:
            os.remove(bundle)
        return done.returncode, done.stdout + done.stderr

    run.read, run.run = read, capture
    try:
        return run.world("funnel.spec.luau", "en-us")
    finally:
        run.read, run.run = original_read, original_run


def main():
    code_old, out_old = funnel(True)
    code_new = 0 if OLD_ONLY else funnel(False)[0]
    glued = [line for line in out_old.splitlines() if line.startswith("❌ шаги 4 и 5")]
    fails = [line for line in out_old.splitlines() if line.startswith("❌ ") and "провалено" not in line]
    if code_old == 0 or not glued or code_new != 0:
        print("❌ Склейка шагов 4 и 5 не поймана: старая логика код", code_old, "строк «шаги 4 и 5»", len(glued),
              "| настоящий код", code_new)
        print("\n".join(fails[:10]))
        return 1
    tail = "настоящий код проверяет funnel.spec в run.py" if OLD_ONLY else "настоящий код проходит"
    print(f"✅ Отрицательный тест воронки: старая логика «было-стало» роняет funnel.spec ({len(fails)} ❌, среди них {glued[0]}), {tail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
