-- Фоновая музыка. Плейлист играет по кругу.
-- Как добавить трек: Creator Store → Audio → найди трек (у Roblox много бесплатной
-- лицензированной музыки) → скопируй ID → впиши "rbxassetid://ID".
-- Сейчас здесь бесплатные треки автора APMOfficial, откуда они, см. docs/LAUNCH.md, раздел 7.

return {
	Volume = 0.25,
	LoadTimeout = 15, -- секунд ждём загрузку трека, потом пропускаем его
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
