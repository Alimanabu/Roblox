-- All game texts: one dictionary. Here is the English original, the translation lives in the
-- Roblox localization table (src/localization/Translations.csv, columns ru and kk). New text = a line here
-- and a line in the table; tests/run.py checks that they match and that the code has no stray texts.
--
-- Parameters in the text go in curly braces: "Sold for {coins}".
-- S.t(key, args)        ready text in the player's language (English on the server);
-- S.m(key, args)        message: the server sends it to the client, the client shows it in the player's language;
-- S.text(value)         text from a message or a plain string; args may be messages too;
-- S.join(parts, sep)    a message made of several parts;
-- S.apply(obj, prop, v) world label: the server writes English, the client replaces it (see client/WorldText);
-- S.forPlayer(p, key)   text in the player's language on the server: only where the client is already gone (Kick).

local Strings = {}

Strings.TAG = "LocalizedText"
Strings.ATTRIBUTE_PREFIX = "Text_"

local Source = {
	-- General
	["common.wait"] = "Hold on a couple of seconds",
	["common.not_enough_coins"] = "Not enough coins: you need {cost}",
	["common.title_level"] = "{title} • lvl {level}",
	["common.per_second"] = "{coins}/s",

	-- Numbers and time
	["format.hours"] = "{hours} h {minutes} min",

	-- Top bar and menu
	["hud.rewards"] = "🎁 Rewards",
	["hud.factory"] = "🏭 Factory",
	["hud.base"] = "🧠 Base",
	["hud.upgrades"] = "⬆️ Upgrades",
	["hud.rebirth"] = "♻️ Rebirth",
	["hud.index"] = "📖 Index",
	["hud.achievements"] = "🏆 Achievements",
	["hud.trade"] = "🤝 Trade",
	["hud.battles"] = "⚔️ Battles",
	["hud.skins"] = "🎨 Skins",
	["hud.shop"] = "🛒 Shop",
	["hud.help"] = "❓ How to Play",
	["hud.admin"] = "🛠 Test",
	["hud.luck"] = "🍀 Luck x{luck}",
	["hud.boost"] = "Boost x2: {time}",
	["hud.vip"] = "👑 VIP: x2 coins",

	-- Window titles
	["panel.factory"] = "🏭 Brainrot Capsule Factory",
	["panel.base"] = "🧠 My Base",
	["panel.upgrades"] = "⬆️ Factory Upgrades",
	["panel.index"] = "📖 Brainrot Index",
	["panel.rewards"] = "🎁 Rewards and Quests",
	["panel.trade"] = "🤝 Brainrot Trade",
	["panel.settings"] = "⚙️ Settings",
	["panel.odds"] = "📊 Odds",
	["panel.skins"] = "🎨 Brainrot Skins",
	["panel.admin"] = "🛠 Test Commands",

	-- Factory
	["factory.announce"] = "🚨 {player} crafted {name} [{rarity}]!",
	["factory.capsule_locked"] = "This capsule is still locked!",
	["factory.season_over_auto"] = "The season is over, Auto Factory turned off",
	["factory.season_over"] = "This season is over 🎃",
	["factory.base_full"] = "Your base is full! Sell or fuse brainrots, or build a floor 🏗",
	["factory.pity"] = "🎯 Guaranteed drop!",
	["factory.sold"] = "Sold for {coins}",
	["factory.sold_many"] = "Sold {count} for {coins}",
	["factory.fuse_need"] = "You need {count} brainrots of the same rarity",
	["factory.fuse_paid"] = "🔒 Need {count} brainrots not from Robux. Open capsules with earned coins",
	["factory.need_auto"] = "You need the “{pass}” game pass",
	["factory.stats"] = "🍀 Luck x{luck}  •  ⏱ Machine: {time} s  •  Spots: {used}/{slots}",
	["factory.hint"] = "The more popular the trend, the rarer the drop. Luck boosts your rare odds!",
	["factory.secret"] = "??? secret",
	["factory.pity_left"] = "🎯 {rarity} guaranteed in {left}",
	["factory.craft"] = "Craft {cost}",
	["factory.auto_on"] = "🤖 Auto: ON",
	["factory.auto"] = "🤖 Auto",
	["factory.need_level"] = "🔒 Level {level}",
	["factory.need_rebirths"] = "{need} + {rebirths} rebirths",
	["odds.open"] = "📊 Odds details",
	["odds.rounded"] = "Odds per try. Long numbers are rounded, so the total can differ slightly from 100%.",
	["odds.intro"] = "Your odds right now, with luck x{luck}. They update live when a boost or event is on.",
	["odds.rule"] = "How luck works: it multiplies the odds weight of every rarity except the most common one in the capsule, and the secret SIX SEVEN chance (up to {secret}). Mutations grow with luck up to x{mutation}. The wheel doesn't depend on luck.",
	["odds.columns"] = "Numbers below, left to right: {columns}",
	["odds.now"] = "now",
	["odds.both"] = "both",
	["odds.region"] = "Paid luck doesn't work in your region. Only free bonuses count.",
	["odds.pool"] = "{count} brainrots, {each} each",
	["odds.mutations"] = "✨ Mutations (rolled for every craft and fusion)",
	["odds.no_mutation"] = "No mutation",
	["odds.fuse"] = "🧬 Fusion: {count} brainrots of one rarity always give 1 random brainrot of the next rarity, each of them with equal odds, plus a mutation roll. Luck changes only the mutation.",
	["odds.pity"] = "🎯 Guarantee: after a streak without the capsule's top rarity, the next try gives it. The streak length doesn't depend on luck. On that try the odds here show the guaranteed result.",
	["odds.pool_title"] = "🧠 Brainrots by rarity (equal odds inside a rarity, on the wheel too)",
	["odds.example"] = "🍀 {capsule}, {rarity}: now {now}, {pass} {lucky}, {product} {boost}",

	-- Base window
	["base.perks"] = "{slots} spots, ❤️{hp}",
	["base.perks_income"] = "{perks}, income x{income}",
	["base.floor_now"] = "🏗 Now: {floor} ({slots} spots)\nNext {next}: {perks}",
	["base.complete"] = "🏆 Base complete: {slots} spots\nUp top ❤️{hp} and income x{income}",
	["base.build"] = "Build {cost}",
	["base.stats"] = "Spots: {used}/{slots}  •  Income: {income}/s",
	["base.friends"] = "👥 Friends on server: {friends}/4 (+{bonus}%)",
	["base.group_on"] = "⭐ Group +10%",
	["base.group_off"] = "⭐ Join the group: +10%",
	["base.empty"] = "Nothing here yet! Go to the 🏭 Factory and craft your first brainrot.",
	["base.sell_all"] = "💰 Sell all",
	["base.confirm"] = "Sure? Tap again",
	["base.hint"] = "Fusing takes the weakest ones. “Sell all” leaves mutants alone.",
	["base.on_floor2"] = "⭐ Floor 2",
	["base.sell"] = "Sell {coins}",
	["base.confirm_sell"] = "Really sell?",

	-- Upgrades window
	["upgrades.level"] = "lvl {level}/{max}",
	["upgrades.max"] = "MAX",

	-- Upgrades
	["upgrade.speed.name"] = "Machine Speed",
	["upgrade.speed.desc"] = "The machine crafts brainrots faster.",
	["upgrade.luck.name"] = "Luck Beam",
	["upgrade.luck.desc"] = "+8% luck per level. Rare trends drop more often.",
	["upgrade.trap.name"] = "Thief Trap",
	["upgrade.trap.desc"] = "A thief who grabs a brainrot is stunned for 1.5 s per level.",

	-- Rebirth
	["rebirth.1.title"] = "Sigma",
	["rebirth.2.title"] = "Alpha",
	["rebirth.3.title"] = "Gigachad",
	["rebirth.4.title"] = "Aura Farmer",
	["rebirth.5.title"] = "Ohio Final Boss",
	["rebirth.6.title"] = "Brainrot Emperor",
	["rebirth.7.title"] = "Legend 67 🤌",
	["rebirth.8.title"] = "Meme Deity",
	["rebirth.9.title"] = "Lord of Brainrot",
	["rebirth.10.title"] = "ABSOLUTE 67 🤌🤌",
	["rebirth.count"] = "Rebirths so far: {count}",
	["rebirth.next_title"] = "Next title: {title}",
	["rebirth.quoted"] = "“{title}”",
	["rebirth.gain"] = "You gain forever:",
	["rebirth.bonus"] = "+{income}% income  •  +{luck}% luck",
	["rebirth.lose"] = "You lose:",
	["rebirth.lose_list"] = "coins, brainrots on your base and upgrades",
	["rebirth.keep"] = "(level, Index and base floors stay)",
	["rebirth.level_req"] = "Level {need} (you have {level})",
	["rebirth.button"] = "♻️ REBIRTH",
	["rebirth.confirm"] = "⚠️ Sure? Tap again",

	-- Index
	["index.count"] = "Unlocked: {found} / {total}  (new brainrot = x3 XP)",

	-- Shop
	["shop.luck_boost_on"] = "🍀 Luck Boost x2 activated!",
	["shop.spins_added"] = "🎡 +{count} wheel spins!",
	["shop.purchased"] = "✅ Purchased: {name}",
	["shop.passes"] = "Game Passes (forever)",
	["shop.owned"] = "✅ Owned",
	["shop.region"] = "Not available in your region",
	["shop.checking"] = "⏳ Checking...",
	["policy.checking"] = "⏳ We're still checking what's allowed. Try again in a minute",
	["shop.bought_coins"] = "🔒 Earn {coins} more. Bought coins only work on floors, skins, basic upgrades",
	["shop.soon"] = "Soon",
	["shop.boosts"] = "Boosts",

	-- Rewards
	["rewards.hint"] = "Log in every day: day 7 is a mega reward!",
	["rewards.day"] = "Day {day}",
	["rewards.wheel_odds"] = "🎡 Wheel odds: {odds}",
	["rewards.spin_free"] = "🎡 Spin the wheel (free!)",
	["rewards.spin"] = "🎡 Spin the wheel ({count})",
	["rewards.spin_tomorrow"] = "🎡 Free spin tomorrow",
	["rewards.spins_blocked"] = "Purchase unavailable",
	["rewards.spins_buy"] = "+3 spins R$ {price}",
	["rewards.spins_soon"] = "+3 spins (soon)",
	["rewards.gifts"] = "⏰ Playtime gifts (you've played {minutes} min today)",
	["rewards.gift_done"] = "✅ {minutes} min",
	["rewards.gift_claim"] = "🎁 Claim!\n{reward}",
	["rewards.gift_wait"] = "⏰ in {minutes} min\n{reward}",
	["rewards.code_placeholder"] = "🎟️ Code (for example, SIXSEVEN)",
	["rewards.code_enter"] = "Redeem code",
	["rewards.claim_day"] = "🎁 Claim day {day}",
	["rewards.come_back"] = "✅ Next reward in {time}",
	["rewards.quests"] = "📋 Today's quests (new ones in {time})",
	["rewards.received"] = "✅ Claimed",

	-- Rewards description
	["reward.luck_short"] = "🍀x2 {minutes}m",
	["reward.luck"] = "🍀 x2 luck for {minutes} min",
	["reward.skin"] = "🎨 skin",
	["reward.coins_base_full"] = "💰 {coins} (base is full)",
	["reward.creature"] = "🧠 {name}",

	-- Quests
	["quest.craft25.text"] = "Craft 25 brainrots",
	["quest.craft80.text"] = "Craft 80 brainrots",
	["quest.fuse3.text"] = "Fuse brainrots 3 times",
	["quest.sell10.text"] = "Sell 10 brainrots",
	["quest.steal1.text"] = "Steal 1 brainrot",
	["quest.slap3.text"] = "Slap 3 players",
	["quest.slapThief.text"] = "Slap a thief",
	["quest.lock3.text"] = "Lock your base 3 times",
	["quest.mutant1.text"] = "Get a mutated brainrot",
	["quest.sigma5.text"] = "Get 5 brainrots of Sigma rarity or rarer",
	["quest.index1.text"] = "Unlock a new brainrot in the Index",
	["quest.done"] = "📋 Quest complete: {text}! Claim your reward 🎁",
	["quest.daily_claimed"] = "Today's reward is already claimed. Come back tomorrow!",
	["quest.daily_reward"] = "🎁 Day {day}: {reward}",
	["quest.daily_ready"] = "🎁 Your daily reward is ready: day {day} of {total}! Open 🎁 Rewards",
	["quest.reward"] = "📋 Quest reward: {reward}",

	-- Gifts
	["gift.not_ready"] = "This gift isn't ready yet ⏰",
	["gift.claimed"] = "🎁 {minutes} min gift: {reward}",

	-- Lucky wheel
	["wheel.1.name"] = "💰 5 min of income",
	["wheel.2.name"] = "🍀 x2 luck 10 min",
	["wheel.3.name"] = "💰 15 min of income",
	["wheel.4.name"] = "🧠 Sigma",
	["wheel.5.name"] = "🍀 x2 luck 30 min",
	["wheel.6.name"] = "🧠 Aura",
	["wheel.7.name"] = "🔥 Fire Skin",
	["wheel.8.name"] = "🧠 SKIBIDI!",
	["wheel.no_spins"] = "Out of spins. Next free one is tomorrow 🎡",
	["wheel.result"] = "🎡 Wheel: {name} → {reward}",
	["wheel.title"] = "🎡 LUCKY WHEEL",
	["wheel.spins_kept"] = "🎡 Bought spins don't work here. They stay on your account",

	-- Promo codes
	["code.skin67.text"] = "Skin 67 unlocked! Put it on in 🎨 Skins",
	["code.invalid"] = "❌ That code doesn't exist (or it has expired)",
	["code.used"] = "You've already used this code",
	["code.redeemed"] = "🎟️ Code {code}: {reward} {text}",

	-- How to play
	["help.1.body"] = "Buy meme capsules and craft brainrots. The more popular the trend, the rarer the drop: Normie → Low-key → Rizz → Sigma → Aura → Skibidi → Brainrot God → SIX SEVEN 🤌",
	["help.2.body"] = "Brainrots stand on your base and earn coins every second. When you run out of space, sell the weak ones or fuse 3 of the same rarity into 1 rarer one.",
	["help.3.body"] = "You start with 5 spots on the ground. Build Floor 1 for $100K (10 spots), then Floor 2 for $100M (10 more spots). The strongest brainrots move up: income is x2 there and they're harder to steal. Build at the yellow sign on your base or in ⬆️ Upgrades. Floors stay even after a rebirth.",
	["help.4.body"] = "Sometimes a brainrot comes out Golden (x2), Diamond (x3), Rainbow (x5) or with Mutation 67 (x6.7 income)!",
	["help.5.body"] = "Wild brainrots roam the map. Walk up and hold E: first to catch it keeps it! Rare ones show up now and then, and the whole server gets told.",
	["help.6.body"] = "In 🧠 Base, tap a brainrot's name and give it your own. Everyone will see it above your base.",
	["help.7.body"] = "In 🧠 Base, tap 🐾 on any brainrot and it will follow you around the map. Show off your legendary!",
	["help.8.body"] = "Walk up to someone else's brainrot and hit it with the Slapper until its ❤️ runs out (5 on the ground, 10 on Floor 1, 20 on Floor 2). When it's stunned 💫, hold F and run to your base within 60 seconds! If you get slapped, the brainrot goes back to its owner.",
	["help.9.body"] = "Stand on the blue lock button on your base to lock it for 60 seconds. You can slap a thief with the Slapper (key 1).",
	["help.10.body"] = "Challenge a player or train with a bot: your 3 strongest brainrots against their 3. Power depends on income, but upsets happen! You lose nothing, and wins give aura points, ranks and coins.",
	["help.11.body"] = "Every hour at :30 a giant brainrot boss comes to the plaza. Slap it with the whole server! Whoever hits it the most gets an Aura brainrot.",
	["help.12.body"] = "Every 15 minutes there's an event: luck, money, mutations or turbo. And every hour at minutes 6-7 comes MINUTE 67: SIX SEVEN chance x6.7!",
	["help.13.body"] = "Resets your coins and brainrots, but gives +50% income, +10% luck and a cool title forever.",
	["help.14.body"] = "Log in every day for a reward, day 7 is a mega reward. Complete 3 quests a day.",
	["help.3.title"] = "🏗 Floors",
	["help.4.title"] = "✨ Mutations",
	["help.5.title"] = "🦎 Wild Brainrots",
	["help.6.title"] = "✏️ Names",
	["help.7.title"] = "🐾 Pet",
	["help.8.title"] = "🦹 Stealing",
	["help.9.title"] = "🔒 Defense",
	["help.10.title"] = "⚔️ Aura Battles",
	["help.11.title"] = "👹 Boss",
	["help.12.title"] = "🎉 Events",

	-- Trade
	["trade.region_you"] = "Trading isn't available in your region",
	["trade.region_them"] = "Trading isn't available for this player",
	["trade.invite_cooldown"] = "Wait a little before sending another invite",
	["trade.busy"] = "One of you is already in a trade",
	["trade.invite_sent"] = "📨 Invite sent: {name}",
	["trade.declined"] = "{name} declined the trade",
	["trade.err_left"] = "a player left",
	["trade.err_missing"] = "a brainrot from the offer is gone",
	["trade.err_empty"] = "the trade is empty",
	["trade.err_past_life"] = "you can't take back your own brainrot from a past life (before rebirth)",
	["trade.err_random"] = "a Robux brainrot can't be traded, start again without it",
	["trade.random_you"] = "🔒 This brainrot came from Robux, so you can't trade it. Pick another brainrot",
	["trade.random_them"] = "🔒 {name} can't take brainrots from Robux. Pick another one",
	["trade.err_no_space"] = "{name} doesn't have enough base spots",
	["trade.cancelled"] = "❌ Trade cancelled: {reason}",
	["trade.done"] = "🤝 Trade complete!",
	["trade.partner_left"] = "Trade cancelled: {name} left the trade",
	["trade.server_restart"] = "Trade cancelled: the server is restarting",
	["trade.invite"] = "🤝 {name} wants to trade brainrots!",
	["trade.hint"] = "Pick a player and offer a trade. Each side puts in up to 6 brainrots, then both press “Ready”.",
	["trade.offer"] = "🤝 Offer",
	["trade.nobody"] = "Nobody else is on the server 😢",
	["trade.you_give"] = "You give ({count}/6)",
	["trade.they_give"] = "{name} gives",
	["trade.countdown"] = "⏳ Trading in {seconds} s...",
	["trade.you_ready"] = "✅ You're ready",
	["trade.you_not_ready"] = "You're not ready",
	["trade.they_ready"] = "✅ {name} is ready",
	["trade.they_not_ready"] = "{name} isn't ready",
	["trade.unready"] = "❌ Not ready",
	["trade.ready"] = "✅ Ready",
	["trade.leave"] = "🚪 Leave trade",

	-- Invitations
	["invite.accept"] = "✅ Accept",
	["invite.decline"] = "❌ No",

	-- Settings
	["settings.music"] = "🎵 Music",
	["settings.sfx"] = "🔊 Sounds",
	["settings.announcements"] = "📢 Server announcements (who dropped/stole what)",
	["settings.on"] = "ON",
	["settings.off"] = "OFF",

	-- Skins window
	["skins.hint"] = "Skins are just for looks. Pick a skin, then press “Put on” next to a brainrot.",
	["skins.selected"] = "✅ Selected",
	["skins.select"] = "Select",
	["skins.secret"] = "🔒 Secret",
	["skins.remove_mode"] = "✅ “Remove skin” mode",
	["skins.remove_select"] = "Remove skins (select)",
	["skins.put_on"] = "🎨 Put on",
	["skins.remove"] = "Remove",

	-- Skins
	["skin.fire.name"] = "🔥 Fire",
	["skin.ice.name"] = "🧊 Ice",
	["skin.toxic.name"] = "☢️ Toxic",
	["skin.shadow.name"] = "🌑 Shadow",
	["skin.gold.name"] = "👑 Pure Gold",
	["skin.galaxy.name"] = "🌌 Galaxy",
	["skin.rainbow.name"] = "🌈 Rainbow",
	["skin.sixseven.name"] = "🤌 Skin 67",
	["skin.owned"] = "You already own this skin",
	["skin.not_for_sale"] = "This skin can't be bought, you have to earn it 🤌",
	["skin.bought"] = "🎨 Skin {name} purchased! Put it on a brainrot",
	["skin.no_change_in_trade"] = "You can't change skins during a trade",
	["skin.cooldown"] = "You can change a skin once every {seconds} seconds",

	-- Battles window
	["battles.stats"] = "✨ {rank} • aura points: {points} • wins {wins} / losses {losses}",
	["battles.hint"] = "Your 3 strongest brainrots fight. You lose nothing! Win rewards left today: {left}",
	["battles.no_team"] = "Craft some brainrots at the 🏭 Factory first",
	["battles.train"] = "🤖 Train with a bot",
	["battles.challenge"] = "⚔️ Challenge",

	-- Aura battles
	["battle.rank.0"] = "No Aura",
	["battle.rank.100"] = "Aura Rookie",
	["battle.rank.300"] = "Aura Farmer",
	["battle.rank.700"] = "Aura Master",
	["battle.rank.1500"] = "Aura Legend",
	["battle.rank.3000"] = "Infinite Aura ♾️",
	["battle.reward_limit"] = "daily reward limit reached",
	["battle.need_brainrot"] = "You need at least one brainrot on your base",
	["battle.not_started"] = "Battle didn't start: someone has no brainrots",
	["battle.result"] = "⚔️ {winner} beat {loser} in an aura battle!",
	["battle.cooldown"] = "Catch your breath for a couple of seconds 😮‍💨",
	["battle.bot_name"] = "🤖 Coach Brainrot",
	["battle.rematch_wait"] = "You can fight this player again in a minute",
	["battle.challenge_sent"] = "⚔️ Challenge sent: {name}",
	["battle.declined"] = "{name} declined the challenge",
	["battle.invite"] = "⚔️ {name} challenges you to an aura battle!",
	["battle.empty"] = "— empty —",
	["battle.versus"] = "⚔️ You  vs  {name}",
	["battle.win"] = "🏆 VICTORY! Your aura is stronger!",
	["battle.loss"] = "😢 Defeat... your aura needs work",
	["battle.footer"] = "Aura points: {points} • {rank}",
	["battle.footer_reward"] = "Reward: {reward}   {footer}",

	-- Achievements window
	["achievements.count"] = "Unlocked: {count} / {total}",

	-- Achievements
	["achievement.first.name"] = "First Brainrot",
	["achievement.first.desc"] = "Craft your first brainrot",
	["achievement.craft100.name"] = "Meme Mill",
	["achievement.craft100.desc"] = "Craft 100 brainrots",
	["achievement.craft1000.name"] = "Factory of a Thousand Memes",
	["achievement.craft1000.desc"] = "Craft 1000 brainrots",
	["achievement.index10.name"] = "Collector",
	["achievement.index10.desc"] = "Unlock 10 brainrots in the Index",
	["achievement.index20.name"] = "Trend Expert",
	["achievement.index20.desc"] = "Unlock 20 brainrots in the Index",
	["achievement.indexAll.name"] = "Walking Index",
	["achievement.indexAll.desc"] = "Unlock ALL brainrots",
	["achievement.aura.name"] = "Aura Farmer",
	["achievement.aura.desc"] = "Get an Aura brainrot",
	["achievement.god.name"] = "Meeting God",
	["achievement.god.desc"] = "Get a Brainrot God",
	["achievement.sixseven.name"] = "SIX... SEVEN!!! 🤌",
	["achievement.sixseven.desc"] = "Get a SIX SEVEN (+ Skin 67)",
	["achievement.mutant.name"] = "Mutant",
	["achievement.mutant.desc"] = "Get a mutated brainrot",
	["achievement.mutant25.name"] = "Mutant Lab",
	["achievement.mutant25.desc"] = "Get 25 mutants",
	["achievement.fuse10.name"] = "Geneticist",
	["achievement.fuse10.desc"] = "Fuse brainrots 10 times",
	["achievement.thief.name"] = "First Heist",
	["achievement.thief.desc"] = "Steal a brainrot",
	["achievement.thief10.name"] = "Master Thief",
	["achievement.thief10.desc"] = "Steal 10 brainrots",
	["achievement.defender.name"] = "Base Defender",
	["achievement.defender.desc"] = "Slap a thief",
	["achievement.defender10.name"] = "Level 80 Security Guard",
	["achievement.defender10.desc"] = "Slap 10 thieves",
	["achievement.wild.name"] = "Brainrot Catcher",
	["achievement.wild.desc"] = "Catch a wild brainrot",
	["achievement.wild25.name"] = "Brainrot Ranger",
	["achievement.wild25.desc"] = "Catch 25 wild brainrots",
	["achievement.boss.name"] = "Boss Hunter",
	["achievement.boss.desc"] = "Defeat the brainrot boss",
	["achievement.boss10.name"] = "Terror of Ohio",
	["achievement.boss10.desc"] = "Defeat 10 bosses",
	["achievement.battle.name"] = "First Aura Win",
	["achievement.battle.desc"] = "Win an aura battle",
	["achievement.battle25.name"] = "Aura Champion",
	["achievement.battle25.desc"] = "Beat 25 players in aura battles",
	["achievement.auraLegend.name"] = "Aura Legend",
	["achievement.auraLegend.desc"] = "Reach 1500 aura points",
	["achievement.level10.name"] = "TikToker",
	["achievement.level10.desc"] = "Reach level 10",
	["achievement.level30.name"] = "Trend Legend",
	["achievement.level30.desc"] = "Reach level 30",
	["achievement.rebirth.name"] = "New Life",
	["achievement.rebirth.desc"] = "Rebirth once",
	["achievement.rebirth5.name"] = "Ohio Final Boss",
	["achievement.rebirth5.desc"] = "Rebirth 5 times",
	["achievement.million.name"] = "Millionaire",
	["achievement.million.desc"] = "Earn $1M in total",
	["achievement.billion.name"] = "Billionaire",
	["achievement.billion.desc"] = "Earn $1B in total",
	["achievement.trade.name"] = "Business Partner",
	["achievement.trade.desc"] = "Complete a trade",
	["achievement.streak7.name"] = "Loyal Fan",
	["achievement.streak7.desc"] = "Claim the day 7 reward",
	["achievement.season.desc"] = "Get a brainrot from the “{season}” season",
	["achievement.unlocked"] = "🏆 Unlocked “{name}”! {reward}",

	-- Test commands
	["admin.level"] = "Level {level}",
	["admin.given"] = "Given: {name}",
	["admin.given_mutant"] = "Given Mutant 67: {name}",
	["admin.event"] = "Started event {name} for 2 minutes",
	["admin.season_off"] = "Manual season turned off",
	["admin.season_on"] = "Season {name} on (until turned off)",
	["admin.wild"] = "A wild brainrot appeared",
	["admin.tutorial_skipped"] = "Tutorial skipped",
	["admin.floors_removed"] = "Floors removed: back to 5 spots on the ground",
	["admin.daily_reset"] = "Daily rewards and quests reset",
	["admin.progress_reset"] = "Progress reset",
	["admin.result"] = "🛠 {text}",
	["admin.level1"] = "⭐ +1 level",
	["admin.level10"] = "⭐ +10 levels",
	["admin.mutant"] = "Mutant 67",
	["admin.mutagen"] = "🧬 Mutagen",
	["admin.turbo"] = "⚡ Turbo",
	["admin.minute67"] = "🤌 Minute 67",
	["admin.wild_button"] = "🦎 Wild brainrot",
	["admin.season_halloween"] = "🎃 Halloween season",
	["admin.season_newyear"] = "🎄 New Year season",
	["admin.season_valentine"] = "💘 Valentine season",
	["admin.season_summer"] = "☀️ Summer season",
	["admin.season_off_button"] = "Turn off season",
	["admin.skip_tutorial"] = "📚 Skip tutorial",
	["admin.reset_daily"] = "🎁 Reset daily rewards",
	["admin.remove_floors"] = "🏗 Remove floors",
	["admin.reset"] = "⚠️ RESET PROGRESS",
	["admin.hint"] = "For testing the game only. Visible in Studio and to admins from Config/Admins.",

	-- Names
	["rename.title"] = "✏️ What will you name this brainrot?",
	["rename.placeholder"] = "For example: Vinny 🤌 (up to 20 characters)",
	["rename.ok"] = "✅ Done",
	["rename.cancel"] = "Cancel",

	-- Name check
	["name.too_long"] = "Names can be up to {max} characters",
	["name.filter_failed"] = "Couldn't check the name, please try again",
	["name.changed"] = "✏️ Its name is now “{name}”",
	["name.removed"] = "Name removed",

	-- New brainrot reveal
	["reveal.fused"] = "🧬 FUSED",
	["reveal.new"] = "✨ NEW!",

	-- Steal and lock status
	["status.carry"] = "🏃 Carry the brainrot to your base! {time}",
	["status.shield"] = "🛡️ Shield {time}",
	["status.locked"] = "🔒 Base locked {time}",
	["status.lock_ready"] = "⏳ Lock ready in {time}",
	["status.open"] = "🔓 Base is open!",

	-- Stealing
	["steal.carry_label"] = "🦹 {name}",
	["steal.reason_thief_left"] = "the thief left",
	["steal.reason_past_life"] = "you can't take back your own brainrot from a past life",
	["steal.reason_no_space"] = "no space on your base",
	["steal.reason_random"] = "it came from Robux, so it went back to its owner",
	["steal.random"] = "🔒 This brainrot came from Robux, so it can't be stolen. Pick another one",
	["steal.stolen"] = "🦹 Stolen: {name}!",
	["steal.announce"] = "🚨 {thief} stole {name} from {owner}!",
	["steal.lost"] = "😭 {thief} stole your {name}!",
	["steal.returned"] = "✅ {name} is back home!",
	["steal.failed"] = "❌ Steal failed: {reason}",
	["steal.hit_first"] = "👋 Knock out its ❤️ first: hit it with the Slapper!",
	["steal.base_locked"] = "🔒 This base is locked!",
	["steal.already_carrying"] = "You're already carrying a brainrot!",
	["steal.no_space"] = "No space on your base!",
	["steal.reason_defeated"] = "you were defeated",
	["steal.trap_thief"] = "⚡ Trap! You're stunned for {seconds} s",
	["steal.trap_owner"] = "⚡ Your trap went off! Go slap the thief!",
	["steal.carry"] = "🏃 Carry {name} to your base!",
	["steal.alarm"] = "⚠️ {thief} is stealing {name}! Chase them and slap!",
	["steal.already_locked"] = "Your base is already locked",
	["steal.lock_cooldown"] = "⏳ Lock is recharging: {seconds} s left",
	["steal.locked"] = "🔒 Base locked for {seconds} seconds",
	["steal.brainrot"] = "brainrot",
	["steal.stunned_thief"] = "💫 {name} is stunned! Hold F and grab it!",
	["steal.stunned_owner"] = "💫 {name} is stunned and about to be stolen! Go slap the thief!",
	["steal.being_hit"] = "⚠️ {player} is hitting your {name}! ❤️ {hp}",
	["steal.reason_slapped"] = "{name} slapped you!",
	["steal.slap_thief"] = "👋 Slap! The thief dropped the brainrot!",
	["steal.slapper"] = "Slapper",
	["steal.slapper_tip"] = "Slap a thief to make them drop the brainrot! Slap other players' brainrots to steal them.",
	["steal.reason_shutdown"] = "the server is shutting down",
	["steal.shield"] = "🛡️ Your base is protected for {seconds} seconds",
	["steal.reason_owner_left"] = "the owner left the game",
	["steal.reason_timeout"] = "time ran out",
	["steal.reason_too_fast"] = "you moved too fast",
	["steal.too_fast"] = "🚫 You moved too fast! Wait a moment and try again",

	-- Base labels
	["plot.machine"] = "🏭 MACHINE",
	["plot.open_factory"] = "Open factory",
	["plot.machine_object"] = "Brainrot Machine",
	["plot.free_base"] = "Free base",
	["plot.lock"] = "🔓 Lock",
	["plot.lock_action"] = "Lock base",
	["plot.lock_object"] = "Lock",
	["plot.build"] = "Build",
	["plot.floor1_sign"] = "FLOOR 1 • ❤️{hp}",
	["plot.floor2_sign"] = "⭐ FLOOR 2 • ❤️{hp} • income x{income}",
	["plot.perks"] = "{slots} spots • ❤️{hp}",
	["plot.perks_income"] = "{perks} • income x{income}",
	["plot.build_sign"] = "🏗 {floor}: {price}\n{perks}",
	["plot.build_object"] = "{floor} — {price}",
	["plot.built"] = "🏆 Base complete!",
	["plot.stunned"] = "💫 STUNNED!",
	["plot.hp"] = "❤️ {hp}/{max}",
	["plot.steal"] = "Steal!",
	["plot.slap"] = "Slap! ❤️{hp}",
	["plot.nickname"] = "“{nickname}”\n{name}",
	["plot.creature_label"] = "{name}\n<font color=\"#{color}\">{rarity}</font>\n<font color=\"#78ff78\">{income}/s</font>",
	["plot.locked_seconds"] = "🔒 {seconds} s",
	["plot.owner_base"] = "{name}'s base",

	-- Wild brainrots
	["wild.catch"] = "Catch",
	["wild.object"] = "Wild {name}",
	["wild.label"] = "🦎 Wild {name}\n[{rarity}]",
	["wild.announce"] = "🌟 A WILD {name} [{rarity}] appeared on the map! Catch it!",
	["wild.no_space"] = "No space on your base for a wild brainrot!",
	["wild.caught"] = "🦎 Caught a wild {name}!",
	["wild.caught_announce"] = "🦎 {player} caught a wild {name}!",

	-- Boss
	["boss.health"] = "👹 Orso Ohio — {hp} / {max}",
	["boss.arrived"] = "👹 The brainrot boss is on the plaza! Run and slap it!",
	["boss.escaped"] = "👹 The boss got away... Slap harder next time!",
	["boss.defeated_best"] = "🏆 Boss defeated! Top fighter: {name}",
	["boss.defeated"] = "🏆 Boss defeated!",
	["boss.reward"] = "👹 Boss reward: {reward}",

	-- Events
	["event.luck_storm.name"] = "🍀 Luck Storm",
	["event.luck_storm.desc"] = "x2 luck for everyone!",
	["event.money_rain.name"] = "💰 Money Rain",
	["event.money_rain.desc"] = "x2 income for everyone!",
	["event.mutant_fog.name"] = "🧬 Mutagen Fog",
	["event.mutant_fog.desc"] = "x3 mutation chance!",
	["event.turbo.name"] = "⚡ Turbo Factory",
	["event.turbo.desc"] = "Machines run 2x faster!",
	["event.minute67.name"] = "🤌 MINUTE 67",
	["event.minute67.desc"] = "SIX SEVEN and Mutation 67 chance x6.7!",
	["event.boss.name"] = "👹 BRAINROT BOSS",
	["event.boss.desc"] = "Slap the boss on the plaza, whole server!",
	["event.started"] = "🎉 New event: {name}: {desc}",
	["event.ended"] = "The event is over. Next one soon!",
	["event.soon"] = "⏰ In one minute: {name}!",
	["event.next"] = "Next event",
	["event.next_in"] = "{name} in {time}",

	-- Tutorial
	["tutorial.1.text"] = "Tap 🏭 Factory and craft your first brainrot!",
	["tutorial.2.text"] = "Brainrots earn coins every second! Craft 4 more",
	["tutorial.3.text"] = "Buy any upgrade in ⬆️ Upgrades",
	["tutorial.4.text"] = "Thieves never sleep! Stand on the blue 🔓 Lock button at your base",
	["tutorial.5.text"] = "Claim your daily reward in 🎁 Rewards",
	["tutorial.step_done"] = "✅ Nice! +{coins}",
	["tutorial.finished"] = "🎓 Tutorial complete! +{coins}. Now go get a SIX SEVEN 🤌",
	["tutorial.step"] = "📚 Tutorial {index}/{total}",

	-- Progress
	["progress.level_up"] = "⭐ New level: {level}!",
	["progress.new_title"] = "🏷️ New title: {title}",
	["progress.capsule_unlocked"] = "🔓 Capsule unlocked: {name}",
	["progress.upgrade_maxed"] = "This upgrade is already maxed out!",
	["progress.upgrade_level"] = "⬆️ {name}: level {level}",
	["progress.floors_done"] = "All floors are already built!",
	["progress.floor_built"] = "🏗 {floor} built! Spots now: {slots}",
	["progress.floor_announce"] = "🏗 {name} built their base up to {floor}!",
	["progress.being_robbed"] = "Someone is stealing your brainrot right now! Get it back first 👋",
	["progress.rebirth_level"] = "You need level {level} to rebirth",
	["progress.rebirth_coins"] = "You need {cost} to rebirth",
	["progress.rebirth_announce"] = "♻️ {name} was reborn as “{title}”!",
	["progress.overhead"] = "[{rebirth}]\n{title}",

	-- Income
	["income.offline"] = "💤 While you were away, your brainrots earned {coins}",

	-- Pet
	["pet.following"] = "🐾 This brainrot now follows you around!",

	-- Leaderboards
	["leaderboard.top_earned"] = "💰 Top Earners",
	["leaderboard.top_rebirths"] = "♻️ Top Rebirths",
	["leaderboard.loading"] = "Loading...",
	["leaderboard.published_only"] = "Leaderboards work\nin the published game",
	["leaderboard.empty"] = "Nothing here yet. Be the first!",
	["leaderboard.income"] = "Income/s",
	["leaderboard.rebirths"] = "Rebirths",

	-- Map
	["map.statue"] = "🤌 Legend: SIX SEVEN 🤌",

	-- Effects
	["fx.legendary"] = "🌟 LEGENDARY DROP! 🌟",

	-- Saves
	["data.load_failed"] = "Couldn't load your progress (you may still be connected to another server). Please rejoin in a minute!",
	["data.store_unavailable"] = "Saving is unavailable right now, so your progress would be lost. Please rejoin in a few minutes!",

	-- Brainrots
	["creature.bananito_ninjini.name"] = "Bananito Ninjini",
	["creature.bananito_ninjini.desc"] = "A banana ninja. Trying really hard.",
	["creature.tostino_volantino.name"] = "Tostino Volantino",
	["creature.tostino_volantino.desc"] = "A toaster that thinks it can fly.",
	["creature.lumacone_turbo.name"] = "Lumacone Turbo",
	["creature.lumacone_turbo.desc"] = "A turbocharged snail. Still slow.",
	["creature.calzino_perduto.name"] = "Calzino Perduto",
	["creature.calzino_perduto.desc"] = "A lost sock. Looking for its pair since 2019.",
	["creature.frigo_gatto.name"] = "Frigo Gatto",
	["creature.frigo_gatto.desc"] = "A fridge cat. The most chill low-key around.",
	["creature.pinguino_boombox.name"] = "Pinguino Boombox",
	["creature.pinguino_boombox.desc"] = "Wears a speaker where its belly should be.",
	["creature.cactusso_dancerino.name"] = "Cactusso Dancerino",
	["creature.cactusso_dancerino.desc"] = "It dances, but we don't recommend hugs.",
	["creature.burgerito_chillo.name"] = "Burgerito Chillo",
	["creature.burgerito_chillo.desc"] = "A burger on chill. The tastiest low-key.",
	["creature.squalo_sneakerino.name"] = "Squalo Sneakerino",
	["creature.squalo_sneakerino.desc"] = "A shark in limited-edition sneakers.",
	["creature.croissanto_samurai.name"] = "Croissanto Samurai",
	["creature.croissanto_samurai.desc"] = "A flaky warrior of honor.",
	["creature.polpo_rizzini.name"] = "Polpo Rizzini",
	["creature.polpo_rizzini.desc"] = "An octopus with eightfold rizz.",
	["creature.lamantino_rapper.name"] = "Lamantino Rapper",
	["creature.lamantino_rapper.desc"] = "Raps so slowly it counts as rizz.",
	["creature.gelato_gigachado.name"] = "Gelato Gigachado",
	["creature.gelato_gigachado.desc"] = "Ice cream with a square jaw.",
	["creature.tacchino_sigmone.name"] = "Tacchino Sigmone",
	["creature.tacchino_sigmone.desc"] = "A turkey that wakes up at 4 AM.",
	["creature.mollusco_mewing.name"] = "Mollusco Mewing",
	["creature.mollusco_mewing.desc"] = "Has been holding that jawline for 300 years.",
	["creature.criceto_palestra.name"] = "Criceto Palestra",
	["creature.criceto_palestra.desc"] = "A gym hamster. Only spins the wheel on max weight.",
	["creature.pizzarino_rocketto.name"] = "Pizzarino Rocketto",
	["creature.pizzarino_rocketto.desc"] = "Jet-powered pizza. +1000 aura.",
	["creature.drago_wifi.name"] = "Drago Wifi",
	["creature.drago_wifi.desc"] = "A dragon handing out free Wi-Fi.",
	["creature.fenicotto_auretto.name"] = "Fenicotto Auretto",
	["creature.fenicotto_auretto.desc"] = "A flamingo farming aura on one leg.",
	["creature.unicorno_neon.name"] = "Unicorno Neon",
	["creature.unicorno_neon.desc"] = "A unicorn that glows even in daylight. Aura: infinite.",
	["creature.elefantino_bass.name"] = "Elefantino Bass",
	["creature.elefantino_bass.desc"] = "An elephant DJ. You can hear the bass on the next server.",
	["creature.robottino_spaghetti.name"] = "Robottino Spaghetti",
	["creature.robottino_spaghetti.desc"] = "A robot made of pasta. The code is spaghetti too.",
	["creature.capibara_galattica.name"] = "Capibara Galattica",
	["creature.capibara_galattica.desc"] = "A capybara that saw the end of the universe. It's fine.",
	["creature.pinguoide_cosmo.name"] = "Pinguoide Cosmo",
	["creature.pinguoide_cosmo.desc"] = "A penguin astronaut. Flew to Mars for memes.",
	["creature.re_lasagnone.name"] = "Re Lasagnone",
	["creature.re_lasagnone.desc"] = "The lasagna king. All memes bow before him.",
	["creature.medusa_glitchina.name"] = "Medusa Glitchina",
	["creature.medusa_glitchina.desc"] = "A jellyfish from a broken texture.",
	["creature.orso_ohio.name"] = "Orso Ohio",
	["creature.orso_ohio.desc"] = "The final-level boss bear of Ohio.",
	["creature.alpaca_assoluta.name"] = "Alpaca Assoluta",
	["creature.alpaca_assoluta.desc"] = "The absolute alpaca. One spit and a meme goes viral.",
	["creature.sei_sette.name"] = "Sei Sette",
	["creature.sei_sette.desc"] = "Six... SEVEN! 🤌 The rarest brainrot in the world.",
	["creature.dottore_sessantasette.name"] = "Dottore Sessantasette",
	["creature.dottore_sessantasette.desc"] = "Holds a PhD in the number 67.",
	["creature.zucchino_ridente.name"] = "Zucchino Ridente",
	["creature.zucchino_ridente.desc"] = "A pumpkin laughing at your memes.",
	["creature.scheletro_mewing.name"] = "Scheletro Mewing",
	["creature.scheletro_mewing.desc"] = "A skeleton with a perfect jawline. Literally.",
	["creature.fantasma_aurino.name"] = "Fantasma Aurino",
	["creature.fantasma_aurino.desc"] = "A ghost farming aura from the other side.",
	["creature.pupazzo_rizz.name"] = "Pupazzo Rizz",
	["creature.pupazzo_rizz.desc"] = "A snowman with carrot rizz.",
	["creature.renna_sigmina.name"] = "Renna Sigmina",
	["creature.renna_sigmina.desc"] = "A reindeer hauling the sleigh at 4 AM.",
	["creature.abete_aurella.name"] = "Abete Aurella",
	["creature.abete_aurella.desc"] = "A fir tree strung with aura lights.",
	["creature.nonno_gelo.name"] = "Nonno Gelo",
	["creature.nonno_gelo.desc"] = "Grandpa Frost from Italy. Only gifts memes.",
	["creature.cuore_rizzone.name"] = "Cuore Rizzone",
	["creature.cuore_rizzone.desc"] = "A little heart with max rizz. Oops.",
	["creature.cupido_sigmino.name"] = "Cupido Sigmino",
	["creature.cupido_sigmino.desc"] = "A Cupid who only shoots at sigmas.",
	["creature.rosalina_aurina.name"] = "Rosalina Aurina",
	["creature.rosalina_aurina.desc"] = "A rose with thorns and infinite aura.",
	["creature.cioccolato_amorele.name"] = "Cioccolato Amore",
	["creature.cioccolato_amorele.desc"] = "A box of chocolates that gifts itself.",
	["creature.anguria_chillino.name"] = "Anguria Chillino",
	["creature.anguria_chillino.desc"] = "A watermelon on chill. The seeds are pure rizz.",
	["creature.granchio_spiaggino.name"] = "Granchio Spiaggino",
	["creature.granchio_spiaggino.desc"] = "A sigma crab. Walks sideways, but always forward.",
	["creature.surfero_aurino.name"] = "Surfero Aurino",
	["creature.surfero_aurino.desc"] = "Catches waves and aura at the same time.",
	["creature.sole_dj.name"] = "Sole DJ",
	["creature.sole_dj.desc"] = "A sun DJ. Summer set 24/7.",
	["creature.vampiro_dj.name"] = "Vampiro DJ",
	["creature.vampiro_dj.desc"] = "A vampire DJ. Only plays at night, but loud.",
	["creature.mutated"] = "{mutation} {name}",

	-- Rarities
	["rarity.normie.name"] = "Normie",
	["rarity.lowkey.name"] = "Low-key",
	["rarity.rizz.name"] = "Rizz",
	["rarity.sigma.name"] = "Sigma",
	["rarity.aura.name"] = "Aura",
	["rarity.skibidi.name"] = "Skibidi",
	["rarity.god.name"] = "Brainrot God",
	["rarity.sixseven.name"] = "SIX SEVEN 🤌",

	-- Mutations
	["mutation.golden.name"] = "Golden",
	["mutation.diamond.name"] = "Diamond",
	["mutation.rainbow.name"] = "Rainbow",
	["mutation.sixseven.name"] = "Mutation 67",
	["mutation.cosmic.name"] = "Cosmic",

	-- Capsules
	["capsule.old_meme.name"] = "Old Meme",
	["capsule.old_meme.desc"] = "A meme from 2016. Cringe, but it works.",
	["capsule.chat_meme.name"] = "Chat Meme",
	["capsule.chat_meme.desc"] = "Someone dropped it in the class chat.",
	["capsule.viral_meme.name"] = "Viral Meme",
	["capsule.viral_meme.desc"] = "Already at 1M views!",
	["capsule.trend_sound.name"] = "Trending Sound",
	["capsule.trend_sound.desc"] = "This sound is in every other video.",
	["capsule.mega_trend.name"] = "Mega Trend",
	["capsule.mega_trend.desc"] = "Even parents talk about this.",
	["capsule.brainrot_core.name"] = "Brainrot Core",
	["capsule.brainrot_core.desc"] = "Pure concentrated brainrot.",
	["capsule.capsule_67.name"] = "Capsule 67",
	["capsule.capsule_67.desc"] = "Six... seven... 🤌",
	["capsule.halloween_capsule.name"] = "🎃 Halloween Capsule",
	["capsule.halloween_capsule.desc"] = "Only until November 6! Exclusive brainrots.",
	["capsule.newyear_capsule.name"] = "🎄 New Year Capsule",
	["capsule.newyear_capsule.desc"] = "Only until January 10! Exclusive brainrots.",
	["capsule.valentine_capsule.name"] = "💘 Valentine",
	["capsule.valentine_capsule.desc"] = "Only until February 15! Exclusive brainrots.",
	["capsule.summer_capsule.name"] = "☀️ Summer Capsule",
	["capsule.summer_capsule.desc"] = "Only until July 10! Exclusive brainrots.",
	["capsule.world_trend.name"] = "World Trend",
	["capsule.world_trend.desc"] = "The whole planet knows this meme.",
	["capsule.ultra_brainrot.name"] = "Ultra Brainrot",
	["capsule.ultra_brainrot.desc"] = "The final form of the internet. 🤌",

	-- Level titles
	["level.1.name"] = "Noob",
	["level.3.name"] = "Schoolkid",
	["level.6.name"] = "Memologist",
	["level.10.name"] = "TikToker",
	["level.15.name"] = "Reels Maker",
	["level.22.name"] = "Viral",
	["level.30.name"] = "Trend Legend",
	["level.40.name"] = "Brainrot Tycoon",
	["level.50.name"] = "Meme Emperor",
	["level.67.name"] = "King 67 🤌",

	-- Floors
	["floor.0.name"] = "Ground",
	["floor.1.name"] = "Floor 1",
	["floor.2.name"] = "Floor 2",

	-- Game passes (ids and prices in Config/Monetization)
	["pass.VIP.name"] = "VIP",
	["pass.VIP.desc"] = "x2 coins forever",
	["pass.LUCKY.name"] = "Lucky",
	["pass.LUCKY.desc"] = "x1.5 luck forever",
	["pass.BIG_BASE.name"] = "Huge Base",
	["pass.BIG_BASE.desc"] = "Floor 1 right away + Floor 2 at half price",
	["pass.AUTO_CRAFT.name"] = "Auto Factory",
	["pass.AUTO_CRAFT.desc"] = "The machine crafts brainrots by itself",
	["pass.FAST_MACHINE.name"] = "Turbo Machine",
	["pass.FAST_MACHINE.desc"] = "The machine runs 2x faster",

	-- One-time purchases
	["product.LUCK_BOOST.name"] = "Luck Boost x2",
	["product.LUCK_BOOST.desc"] = "x2 luck for 15 minutes",
	["product.COINS_SMALL.name"] = "Bag of Coins",
	["product.COINS_SMALL.desc"] = "10 minutes of income (min. 5K)",
	["product.SPINS_3.name"] = "3 Wheel Spins",
	["product.SPINS_3.desc"] = "Spin the lucky wheel 3 more times",
	["product.COINS_BIG.name"] = "Chest of Coins",
	["product.COINS_BIG.desc"] = "1 hour of income (min. 50K)",

	-- Seasons
	["season.halloween.name"] = "🎃 Halloween",
	["season.newyear.name"] = "🎄 New Year",
	["season.valentine.name"] = "💘 Valentine's Day",
	["season.summer.name"] = "☀️ Summer",
}

Strings.Source = Source

local TRANSLATIONS_RETRY = 30 -- seconds until a new attempt if the table has not loaded yet

local translations = {} -- [language] = { [key] = translation }, only loaded tables
local retryAt = {} -- [language] = when to try loading the table again

-- We determine the language once: on the server and in tests there is no player, so English.
local function detectLanguage()
	local ok, language = pcall(function()
		return string.sub(game:GetService("Players").LocalPlayer.LocaleId, 1, 2)
	end)
	return ok and language or "en"
end

-- We read the table ourselves: this way English works even if the translation did not load.
local function translationsFor(language)
	if language == "en" then
		return nil
	end
	if translations[language] or os.clock() < (retryAt[language] or 0) then
		return translations[language]
	end
	local firstTry = retryAt[language] == nil
	retryAt[language] = os.clock() + TRANSLATIONS_RETRY
	local map = {}
	local ok, err = pcall(function()
		local localization = game:GetService("LocalizationService")
		-- We wait only on load: later the request comes from rendering, which must not be stopped.
		local localizationTable = if firstTry
			then localization:WaitForChild("Translations", 5)
			else localization:FindFirstChild("Translations")
		for _, entry in ipairs(localizationTable:GetEntries()) do
			local value = entry.Values[language]
			if value and value ~= "" then
				map[entry.Key] = value
			end
		end
	end)
	if not ok then
		warn("[Strings] Translation table unavailable:", err)
	end
	-- An empty result is not remembered: the table may not have reached the client yet.
	if next(map) then
		translations[language] = map
	end
	return translations[language]
end

-- The notification label fits 79 characters. In these lines {name} next to player names, a reward
-- or a tip may not fit: then we shorten only it, by as much as was missing, in
-- the player's language. The other lines and the brainrot card show the name in full.
local MAX_MESSAGE = 79
local MIN_NAME = 8
local FIT_NAME = {
	["achievement.unlocked"] = true,
	["event.started"] = true,
	["factory.announce"] = true,
	["steal.alarm"] = true,
	["steal.announce"] = true,
	["steal.being_hit"] = true,
	["steal.stunned_owner"] = true,
	["trade.random_them"] = true,
	["wheel.result"] = true,
	["wild.announce"] = true,
}

local function clip(text, limit)
	local cut = string.sub(text, 1, utf8.offset(text, limit) - 1)
	return (string.gsub(cut, "%s+$", "")) .. "…"
end

local function render(language, value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	if value.join then
		local parts = {}
		for index, part in ipairs(value.join) do
			parts[index] = render(language, part)
		end
		return table.concat(parts, value.sep)
	end
	local map = translationsFor(language)
	local text = map and map[value.k] or Source[value.k]
	if not text then
		warn("[Strings] Missing text:", value.k)
		return tostring(value.k)
	end
	if not value.a then
		return text
	end
	local args = {}
	for name, arg in pairs(value.a) do
		args[name] = render(language, arg)
	end
	local filled = string.gsub(text, "{(%w+)}", args)
	if FIT_NAME[value.k] and args.name then
		local length = utf8.len(args.name)
		local limit = math.max(length + MAX_MESSAGE - utf8.len(filled), MIN_NAME)
		if limit < length then
			args.name = clip(args.name, limit)
			filled = string.gsub(text, "{(%w+)}", args)
		end
	end
	return filled
end

function Strings.setLanguage(language)
	Strings.language = language
end

function Strings.m(key, args)
	return { k = key, a = args }
end

function Strings.join(parts, separator)
	return { join = parts, sep = separator }
end

function Strings.text(value)
	return render(Strings.language, value)
end

function Strings.t(key, args)
	return render(Strings.language, Strings.m(key, args))
end

function Strings.forPlayer(player, key, args)
	return render(string.sub(player.LocaleId or "en", 1, 2), Strings.m(key, args))
end

-- Fills a config entry with texts from the dictionary: item.name and item.nameKey = "<prefix>.name".
-- The server sends the client S.m(item.nameKey), the client reads item.name in its own language.
function Strings.fill(item, prefix, ...)
	for _, field in ipairs({ ... }) do
		local key = prefix .. "." .. field
		item[field .. "Key"] = key
		item[field] = Strings.t(key)
	end
end

function Strings.apply(instance, property, value)
	local encoded = game:GetService("HttpService"):JSONEncode({ value })
	local attribute = Strings.ATTRIBUTE_PREFIX .. property
	if instance:GetAttribute(attribute) == encoded then
		return
	end
	instance[property] = Strings.text(value)
	instance:SetAttribute(attribute, encoded)
	game:GetService("CollectionService"):AddTag(instance, Strings.TAG)
end

Strings.setLanguage(detectLanguage())

return Strings
