-- Game sounds. Roblox built-in sounds (rbxasset://) are used for now.
-- To use cooler sounds: find a sound in the Creator Store and enter
-- "rbxassetid://<ID>" in place of the current value.
-- repeat is how many times to play in a row (for the siren), gap is the pause between repeats.

return {
	craft = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	rare = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 0.7, ["repeat"] = 3, gap = 0.15 },
	alarm = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, pitch = 0.5, ["repeat"] = 4, gap = 0.25 },
	-- Slapper (client/SlapFx.luau plays these in 3D on the character). All Creator Store free sounds
	-- by Pro Sound Effects (Hand Slap Claps 3 and 10, Wet Newspaper Slap Hit, Wood Whoosh Quick Swings 4).
	-- slap is also the plain sound of a lost battle round (BattleView).
	slap = { id = "rbxassetid://9114771792", volume = 1 },
	slapHit = { id = "rbxassetid://9114771792", alt = "rbxassetid://9114772106", volume = 1 },
	slapThud = { id = "rbxassetid://9120647258", volume = 0.8, pitch = 0.9 },
	slapMiss = { id = "rbxassetid://9120972321", volume = 0.75, pitch = 1.2 },
	success = { id = "rbxasset://sounds/button.wav", volume = 0.8, pitch = 1.4 },
	lose = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6 },
	levelup = { id = "rbxasset://sounds/button.wav", volume = 0.8, pitch = 1.8, ["repeat"] = 2, gap = 0.12 },
	event = { id = "rbxasset://sounds/swoosh.wav", volume = 0.8 },
	lock = { id = "rbxasset://sounds/clickfast.wav", volume = 0.8 },
	coins = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5, pitch = 1.6 },
}
