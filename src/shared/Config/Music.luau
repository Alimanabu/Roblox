-- Background music. The playlist loops.
-- How to add a track: Creator Store -> Audio -> find a track (Roblox has a lot of free
-- licensed music) -> copy the ID -> enter "rbxassetid://ID".
-- These are currently free tracks by the author APMOfficial; for where they come from see docs/LAUNCH.md, section 7.

return {
	Volume = 0.25,
	LoadTimeout = 15, -- seconds we wait for a track to load, then skip it
	Playlist = {
		"rbxassetid://1836913959", -- World of Robots
		"rbxassetid://1835725225", -- Disco Sapiens
		"rbxassetid://1836914156", -- Life in a Glitch
		"rbxassetid://9040344598", -- Call Me (b)
		"rbxassetid://1841069706", -- Daring Disco
		"rbxassetid://1837768323", -- Final Boss (a)
		"rbxassetid://1836913665", -- Best of Life
	},
}
