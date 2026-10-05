-- Звуки игры. Сейчас стоят встроенные звуки Roblox (rbxasset://).
-- Чтобы поставить звуки покруче: найди звук в Creator Store и впиши
-- "rbxassetid://<ID>" вместо текущего значения.
-- repeat — сколько раз проиграть подряд (для сирены), gap — пауза между повторами.

return {
	craft = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	rare = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 0.7, ["repeat"] = 3, gap = 0.15 },
	alarm = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, pitch = 0.5, ["repeat"] = 4, gap = 0.25 },
	slap = { id = "rbxasset://sounds/snap.wav", volume = 1 },
	success = { id = "rbxasset://sounds/button.wav", volume = 0.8, pitch = 1.4 },
	lose = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6 },
	levelup = { id = "rbxasset://sounds/button.wav", volume = 0.8, pitch = 1.8, ["repeat"] = 2, gap = 0.12 },
	event = { id = "rbxasset://sounds/swoosh.wav", volume = 0.8 },
	lock = { id = "rbxasset://sounds/clickfast.wav", volume = 0.8 },
	coins = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5, pitch = 1.6 },
}
