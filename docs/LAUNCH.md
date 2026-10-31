# 🚀 Запуск Brainrot Factory

Всё, что нужно, чтобы опубликовать игру: описание, промокоды, иконка и обложка,
геймпассы и продукты, бейджи, группа, музыка, настройки.

---

## 1. Название

**🧠 Brainrot Factory 🤌 [SIX SEVEN]**

Запасные варианты: «Brainrot Factory 67», «Steal & Craft Brainrot».
Русское название для перевода: «Брейнрот Фабрика 🤌» (Localization → Game Information).
В квадратных скобках в начале названия принято писать про обновления, например
`[🎃 HALLOWEEN] Brainrot Factory 🤌`, когда идёт сезон.

## 2. Описание игры (вставить в Creator Dashboard → Basic Info → Description)

### English (основное, поле Description)
```
🧠 Craft brainrots in your own meme factory! 🤌

🏭 Drop meme capsules into the machine and get brainrots: from Normie to the legendary SIX SEVEN!
💰 Brainrots earn coins every second, even while you're away.
🦹 Steal brainrots from other bases! Defend yours with a lock and the Slapper.
⚔️ Aura battles: whose aura is stronger?
🦎 Catch wild brainrots on the map!
👹 A boss on the plaza every hour. 🤌 MINUTE 67 with a disco every hour!
🐾 Pick your favorite brainrot as a pet and give it a name.
🎃 Seasonal brainrots you can't get later!

🎟️ CODES (enter them in 🎁 Rewards):
SIXSEVEN — x2 luck for 30 minutes
BRAINROT — 10 minutes of income
RIZZ — free Rizz brainrot
SIGMA — coins + luck
RELEASE — coins + luck
SKIN67 — secret Skin 67

👍 Like and favorite the game: a new code every 1000 likes!
```

### Русский перевод (Localization → Game Information → Russian)
```
🧠 Создавай брейнротов на своей фабрике мемов! 🤌

🏭 Кидай мем-капсулы в машину и получай брейнротов: от Нормиса до легендарного SIX SEVEN!
💰 Брейнроты приносят монеты каждую секунду — даже пока тебя нет.
🦹 Кради брейнротов с чужих баз! Защищай свою замком и Шлёпалкой.
⚔️ Аура-баттлы: чья аура сильнее?
🦎 Лови диких брейнротов на карте!
👹 Каждый час — босс на площади. 🤌 Каждый час — МИНУТА 67 с дискотекой!
🐾 Бери любимого брейнрота в питомцы и давай ему имя.
🎃 Сезонные брейнроты, которых потом не достать!

🎟️ КОДЫ (вводи в 🎁 Награды):
SIXSEVEN — x2 удачи на 30 минут
BRAINROT — 10 минут дохода
RIZZ — бесплатный брейнрот «Ризз»
SIGMA — монеты + удача
RELEASE — монеты + удача
SKIN67 — секретный «Скин 67»

👍 Ставь лайк и добавляй в избранное — за каждые 1000 лайков новый код!
```

Совет: добавляй новые коды на 1K / 5K / 10K лайков и пиши их в описании и в группе.
Код добавляется одной строкой в `src/shared/Config/Codes.luau`.

## 3. Иконка (512×512) и обложки (1920×1080)

Нужна яркая картинка, понятная за полсекунды на маленьком экране телефона.

**Иконка:** крупно один брейнрот (например, Сей Сетте — жёлтый, с руками «6-7»,
нимбом и очками) на ярком фиолетово-розовом фоне с лучами. Сверху крупно «67» или «🤌».
Минимум текста. Лицо брейнрота — с широкими глазами, удивлённое или довольное.

**Обложка 1 (главная):** база с рядами светящихся брейнротов, в центре огромный
легендарный брейнрот со столбом света, вокруг персонажи Roblox в шоке.
Текст: «BRAINROT FACTORY 🤌».

**Обложка 2:** вор бежит с брейнротом над головой, за ним хозяин со Шлёпалкой.
Текст: «STEAL THE BRAINROT!».

**Обложка 3:** диско-шар над площадью, все танцуют. Текст: «MINUTE 67 🤌».

Как сделать:
- Проще всего: зайти в игру в Studio, расставить сцену (через 🛠 Тест выдать брейнротов,
  включить «Минуту 67» или «Брейнрот Бог»), сделать скриншоты и добавить текст в любом
  редакторе.
- Можно заказать у художника по этому описанию.

Правила Roblox: на иконке и обложках нельзя чужих персонажей и брендов, нельзя обещать
то, чего нет в игре, нельзя кликбейт с Robux.

## 4. Геймпассы и продукты (Robux)

Где: **create.roblox.com → Creations → твоя игра → Monetization**.
Геймпассы — раздел **Passes**, разовые покупки — **Developer Products**.
Для каждого: создать, загрузить картинку, задать цену, включить продажу (On Sale),
скопировать **ID** и вписать в `src/shared/Config/Monetization.luau` вместо `id = 0`.

### Геймпассы (покупаются навсегда)
Название и описание в Creator Dashboard пиши по-английски: их показывает окно покупки Roblox.

| key в конфиге | Name | Description | Цена |
|---|---|---|---|
| `VIP` | VIP | x2 coins forever | 199 R$ |
| `LUCKY` | Lucky | x1.5 luck forever | 249 R$ |
| `BIG_BASE` | Huge Base | Floor 1 right away + Floor 2 at half price | 149 R$ |
| `AUTO_CRAFT` | Auto Factory | The machine crafts brainrots by itself | 299 R$ |
| `FAST_MACHINE` | Turbo Machine | The machine runs 2x faster | 99 R$ |

Если при входе игрока Roblox не ответил на проверку, сервер ждёт до 9 с на геймпасс
(паузы 1,5 / 3 / 4,5 с), потом проверяет геймпасс в фоне раз в 60 с. Перезаход не нужен.

### Разовые покупки (Developer Products)
| key в конфиге | Name | Description | Цена |
|---|---|---|---|
| `LUCK_BOOST` | Luck Boost x2 | x2 luck for 15 minutes | 49 R$ |
| `COINS_SMALL` | Bag of Coins | 10 minutes of income (min. 5K) | 29 R$ |
| `SPINS_3` | 3 Wheel Spins | Spin the lucky wheel 3 more times | 39 R$ |
| `COINS_BIG` | Chest of Coins | 1 hour of income (min. 50K) | 129 R$ |

Пример: создал геймпасс VIP, его ID `123456789` → в конфиге
`{ key = "VIP", id = 123456789, ... }`. Пока `id = 0`, в магазине кнопка «Soon».

Шансы капсул и колеса удачи показаны в игре — Roblox требует раскрывать шансы случайных
наград, которые прямо или косвенно (через монеты) можно получить за Robux.

## 4.5. Анкета рейтинга и кому видна игра (Audience → Reach → View questionnaire)
Для выхода на игроков 16+ достаточно первого вопроса анкеты, для аудитории младше 16 нужна
вся анкета (см. ниже). Честные ответы для нашей игры:
- **Violence: Yes** — мультяшное: Шлёпалка отталкивает, удар босса, баттлы брейнротов.
  Без крови, ранений и смертей → самые мягкие варианты (нереалистичное/мультяшное).
- **Blood: No. Fear: No** (хэллоуинские брейнроты милые). **Crude Humor: No.**
- **Gambling:** казино/ставок нет. Если спрашивают про платные случайные награды —
  **Yes** (капсулы/колесо; монеты и вращения продаются за Robux), шансы показаны.
- **Social:** стандартный чат Roblox; имена брейнротов проходят фильтр Roblox.
- Алкоголь, наркотики, романтика, ругательства, политика, религия — **No**.
- **Paid Random Items: Yes**, respects ArePaidRandomItemsRestricted: **Yes** (там, где запрещено,
  игра не продаёт монеты и вращения колеса — `PolicyService`).
- **Paid Item Trading: Yes**, respects IsPaidItemTradingAllowed: **Yes** (там обмен отключён).
- **Media Sharing: No. AI Interaction: No. Cross-Experience: No.**

**Кому видна игра (правила Roblox 2026, проверено 31.10.2026).** Источники:
[Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select),
[Publish games](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places),
[анонс RDC26](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880).

- **Сразу после публикации** игру видят только пользователи 16+, прошедшие проверку возраста.
  От создателя нужно: аккаунт без нарушений и старше 2 дней, проверка возраста, ответ на первый
  вопрос анкеты. Взноса за этот этап нет.
- **Младше 16** (Select 9–15 лет и Kids 5–8 лет) игра откроется после оценки Roblox. Нужно:
  проверка возраста создателя, 2FA, вся анкета с рейтингом Minimal, Mild или Moderate (9+),
  взнос 1000 Robux за игру (возвращается) или подписка Roblox Plus или Premium 2 месяца подряд.
- **Порог младшей аудитории:** 250 уникальных запусков игроками «высокой вовлечённости» с
  проверкой возраста за 60 дней. Прогресс виден в Creator Hub → Audience Reach. Такой игрок
  подходит по стажу аккаунта, времени в нашей игре и покупке на Roblox за последние 60 дней
  (покупать именно у нас не обязательно).
- **Анонс RDC26 (11.09.2026) обещает снизить порог с 250 до 100 в ноябре 2026.** На официальной
  странице на дату проверки ещё 250. Перед запуском посмотри, какое число действует.
- **Для теста до публикации:** до 10 друзей похожего возраста (вкладка Playtest, у них будет
  метка предпросмотра). Кнопка Playtesters оставляет доступ только им и тем, у кого есть Edit
  или Playtest.

## 5. Бейджи (по желанию)

Где: Creations → игра → **Associated Items → Badges**. Создание бейджа может стоить Robux.
Лучше сделать 5–6 главных, а не все 30+:
- First Brainrot (`first`), SIX SEVEN!!! (`sixseven`), Meeting God (`god`),
  Master Thief (`thief10`), Boss Hunter (`boss`), Walking Index (`indexAll`).

ID бейджа вписать в `src/shared/Config/Achievements.luau`, добавив к нужному достижению
`badgeId = 123456789`.

## 6. Группа

Создай группу на Roblox (например, «Brainrot Factory Fans»), впиши её ID в
`src/shared/Config/Social.luau` (`GroupId = ...`). Участники группы получают +10% дохода.
В группе публикуй новые коды и анонсы обновлений.

## 7. Музыка и звуки

Creator Store → **Audio** → ищи бесплатную музыку (у Roblox есть лицензированные треки).
Подойдёт весёлое, энергичное: «fun», «upbeat», «funky», «arcade».
ID треков → `src/shared/Config/Music.luau` (`"rbxassetid://ID"`).
Звуки (крафт, кража, шлепок, уровень) можно заменить в `src/shared/Config/Sounds.luau`.

## 8. Свой UserId для панели «🛠 Test»

Свой UserId видно в адресе профиля: `roblox.com/users/ЭТО_ЧИСЛО/profile`.
Впиши в `src/shared/Config/Admins.luau`. Только админы видят панель в опубликованной игре.

## 9. Настройки игры перед публикацией

- **Game Settings → Security → Enable Studio Access to API Services** — включить.
- **Places → Max Players = 8** (на карте 8 баз).
- **Genre:** Simulator / Tycoon. **Devices:** компьютер, телефон, планшет, консоль.
- **Localization:** исходный язык **English**. Русский уже в игре (таблица `Translations.csv`),
  для него автоперевод не нужен. Описание и название на русском впиши вручную.
  Automatic Translation для других языков можно включить: основа теперь английская.
- **Questionnaire / Maturity:** честно заполнить анкету возрастного рейтинга
  (в игре мультяшное «шлёпанье» без крови и урона).
- Опубликовать: File → Publish to Roblox.

## 10. После запуска

- Смотри **Analytics** в Creator Dashboard: воронку обучения (где уходят новички),
  экономику монет, удержание (D1/D7).
- Сезоны уже настроены: Хэллоуин с 15 октября, Новый год с 20 декабря. Перед сезоном
  поменяй название игры (`[🎃 HALLOWEEN] ...`) и обложку.
- Новый код на каждые 1000 лайков — дети любят коды и сами разносят игру.
