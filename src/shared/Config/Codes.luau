-- Промокоды. Регистр не важен: «sixseven» = «SIXSEVEN».
-- Каждый код игрок может ввести один раз.
-- expires — до какой даты код работает (os.time в секундах, UTC), nil = навсегда.
-- Новые коды удобно раздавать в описании игры, в группе и у ютуберов.

return {
	SIXSEVEN = { luckMinutes = 30, text = "🤌" },
	BRAINROT = { coinsMinutes = 10 },
	RIZZ = { creatureRarity = "rizz" },
	SIGMA = { coinsMinutes = 5, luckMinutes = 10 },
	RELEASE = { coinsMinutes = 15, luckMinutes = 15 },
}
