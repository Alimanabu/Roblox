#!/usr/bin/env python3
"""Отрицательный тест вызовов воронок: вызов вне AnalyticsService и кадровый цикл в нём должны ронять проверку.
Запуск: python -X utf8 tests/test_funnel_calls_negative.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run

SERVICE = "src/server/Services/AnalyticsService.luau"
OK = f"local ok = pcall(method, Analytics, ...)\nsafe(Analytics.LogFunnelStepEvent, player)\n"

cases = {
    "вызов воронки в другом сервисе": {SERVICE: OK, "src/server/Services/FactoryService.luau": "Analytics:LogFunnelStepEvent(player)"},
    "вызов воронки обучения в клиенте": {SERVICE: OK, "src/client/Main.luau": "x:LogOnboardingFunnelStepEvent(p, 1, 'a')"},
    "Heartbeat в AnalyticsService": {SERVICE: OK + "RunService.Heartbeat:Connect(function() end)"},
    "RenderStepped в AnalyticsService": {SERVICE: OK + "RunService.RenderStepped:Connect(f)"},
}
bad = [name for name, files in cases.items() if run.check_funnel_calls(files) != 1]
good = run.check_funnel_calls({SERVICE: OK, "src/server/Services/FactoryService.luau": "-- LogFunnelStepEvent only in a comment"})
if bad or good != 0:
    print("❌ не упало:", bad, "исходный набор:", good)
    sys.exit(1)
print(f"✅ Отрицательный тест: {len(cases)} поломок пойманы, чистый набор проходит")
