-- Game sounds. All are free Creator Store sounds by ProSoundEffects (public domain, checked 14.11.2026 with
-- economy.roblox.com/v2/assets/<id>/details: AssetTypeId 3, IsPublicDomain true). The old built-in "rbxasset"
-- sound files are not in the Roblox client, so those sounds were silent.
-- To use other sounds: find one in the Creator Store and enter "rbxassetid://<ID>" in place of the current value.
-- repeat is how many times to play in a row (for the siren), gap is the pause between repeats.
--   9126073001 / 9126073026  Synth Sparkle Tone High Pitch Bell Tone Ding (1.2 s)
--   9113880475               Computer Keyboard Beep 3 (0.4 s)
--   9120412125               Video Game Buttons 22 (0.6 s)
--   9113085764               Alarm Buzzer 5 (1.4 s)
--   9119740811               Swoosh Pack High End Multiple Variations 22 (0.7 s)
--   9119717523 / 9119717529  Switch Click On Or Off Toggle Button 2 / 1 (0.4 s / 0.5 s)

return {
	craft = { id = "rbxassetid://9126073001", volume = 0.5 },
	rare = { id = "rbxassetid://9126073001", volume = 0.8, pitch = 0.7, ["repeat"] = 3, gap = 0.3 },
	alarm = { id = "rbxassetid://9113880475", volume = 0.9, pitch = 0.8, ["repeat"] = 4, gap = 0.3 },
	-- Slapper (client/SlapFx.luau plays these in 3D on the character). All Creator Store free sounds
	-- by Pro Sound Effects (Hand Slap Claps 3 and 10, Wet Newspaper Slap Hit, Wood Whoosh Quick Swings 4).
	-- slap is also the plain sound of a lost battle round (BattleView).
	slap = { id = "rbxassetid://9114771792", volume = 1 },
	slapHit = { id = "rbxassetid://9114771792", alt = "rbxassetid://9114772106", volume = 1 },
	slapThud = { id = "rbxassetid://9120647258", volume = 0.8, pitch = 0.9 },
	slapMiss = { id = "rbxassetid://9120972321", volume = 0.75, pitch = 1.2 },
	success = { id = "rbxassetid://9120412125", volume = 0.8, pitch = 1.4 },
	lose = { id = "rbxassetid://9113085764", volume = 0.5 },
	levelup = { id = "rbxassetid://9126073026", volume = 0.8, pitch = 1.3, ["repeat"] = 2, gap = 0.25 },
	event = { id = "rbxassetid://9119740811", volume = 0.8 },
	lock = { id = "rbxassetid://9119717523", volume = 0.8 },
	coins = { id = "rbxassetid://9119717529", volume = 0.5, pitch = 1.6 },
}
