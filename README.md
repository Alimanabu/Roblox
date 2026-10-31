# 🧠 Brainrot Factory 🤌

Roblox-симулятор: строишь фабрику мемов, кидаешь в машину мем-капсулы и создаёшь
оригинальных брейнрот-существ. Они стоят на твоей базе и приносят монеты.

**Главное правило игры: чем популярнее тренд, тем реже он выпадает.**
Нормис → Лоу-ки → Ризз → Сигма → Аура → Скибиди → Брейнрот Бог → **SIX SEVEN 🤌**

Подробный дизайн игры: [docs/DESIGN.md](docs/DESIGN.md).
Идеи следующих игр: [docs/IDEAS.md](docs/IDEAS.md).
Как проверить игру в Studio: [docs/TESTING.md](docs/TESTING.md).
Как опубликовать (описание, коды, иконка, геймпассы): [docs/LAUNCH.md](docs/LAUNCH.md).

## Как запустить

1. Установи [Rokit](https://github.com/rojo-rbx/rokit) и выполни `rokit install`, чтобы поставить Rojo.
   Или поставь Rojo любым другим способом.
2. Установи плагин Rojo в Roblox Studio.
3. В папке проекта запусти `rojo serve`.
4. В Studio открой пустой Baseplate, в плагине Rojo нажми **Connect**.
5. Нажми **Play**.

Собрать файл игры без Studio: `rojo build -o BrainrotFactory.rbxl`.

**Без установки Rojo:** при каждом пуше GitHub сам проверяет код и собирает игру.
Открой на GitHub вкладку **Actions** → последний зелёный запуск → внизу **Artifacts** →
скачай `BrainrotFactory`, распакуй и открой `BrainrotFactory.rbxl` в Roblox Studio.

### Перед публикацией

- **Game Settings → Security → Enable Studio Access to API Services**. Без этого в Studio
  прогресс не сохраняется (игра работает, но без сохранений).
- **Max Players = 8**: на карте 8 баз.
- Создай геймпассы и продукты в Creator Dashboard и впиши их ID в
  `src/shared/Config/Monetization.luau`. Пока ID = 0, в магазине кнопка «Скоро».

### Языки 🌍
Основной язык игры английский, все тексты лежат в одном словаре `src/shared/Strings.luau`.
Русский живёт в таблице локализации Roblox `src/localization/Translations.csv` (колонка `ru`),
Rojo кладёт её в `LocalizationService`. Автоперевод для русского не нужен.
- Новый текст: строка в словаре и строка в таблице, в коде только ключ. `tests/run.py` падает,
  если они разошлись или текст написан мимо словаря.
- Новый язык: колонка с кодом языка в таблице (например, `es`).
- Сервер не собирает готовый текст: он шлёт ключ (`S.m`), клиент показывает его на языке игрока.
  Надписи в мире сервер ставит через `S.apply`, клиент заменяет их в `client/WorldText.luau`.

## Структура

```
src/
  shared/                 -> ReplicatedStorage.Shared (общий код)
    Config/               все цифры и списки игры:
                          Rarities, Creatures, Capsules, Mutations, Levels, Upgrades,
                          Rebirths, Events, Daily (награды/задания/подарки), Achievements,
                          Codes, Skins, Sounds, Music, Tutorial, Monetization, Admins
    Util/Formulas.luau    вся игровая математика (шансы, доход, удача)
    Util/CreatureModel.luau  сборка моделей брейнротов из деталей
    Util/Format.luau      красивые числа ($1.5K, 2.3M)
    Remotes.luau          сетевые события
  server/                 -> ServerScriptService.Server
    Main.server.luau      запуск сервера
    Services/             Data, Factory, Income, Plot, Steal, Trade, Quest, Gift, Code,
                          Achievement, Skin, Event, Leaderboard, Tutorial, Settings,
                          Monetization, Admin, Reward, Progression, Actions (шина событий)
  client/                 -> StarterPlayerScripts.Client
    Main.client.luau      запуск клиента, анимации
    Ui/                   интерфейс (создаётся кодом)
    Sfx.luau, Music.luau  звуки и музыка
tests/                    проверки баланса, формул и покупок за Robux
docs/                     DESIGN (дизайн), TESTING (чек-лист), IDEAS (идеи других игр)
```

Почти всё, что хочется поменять (цены, шансы, коды, скины, звуки), лежит в
`src/shared/Config/`. Код трогать не нужно.

## Тесты

Нужен [Luau CLI](https://github.com/luau-lang/luau/releases):

```
python tests/run.py path/to/luau.exe
```

Вместо `path/to/luau.exe` укажи полный путь к скачанному `luau.exe`.

Тесты проверяют, что шансы складываются в 100% и редкие тренды действительно реже.
Ещё они симулируют 6 часов игры и печатают, когда игрок открывает капсулы, редкости
и перерождения. Отдельно проверяются покупки за Robux на заглушках Roblox
(`tests/purchases.spec.luau`): выдача, повтор чека, сбой сохранения, запись без ответа,
недоступный DataStore, выключение сервера, сбой запроса геймпасса. Если Roblox не ответил,
сервер ждёт до 9 с на геймпасс (паузы 1,5 / 3 / 4,5 с), потом проверяет его в фоне раз в 60 с.

`tests/world.luau` запускает настоящие сервер и клиент вместе на заглушке мира. На ней:
- `screens.spec.luau`: новичок и богатый игрок нажимают все кнопки всех окон на английском и русском;
- `steal.spec.luau`: честная кража, телепорт, спидхак, отлёт от удара, забор замка, дикие брейнроты;
- `rejoin.spec.luau`: игрок купил VIP и 2 этаж, ушёл, вернулся, всё на месте;
- `frames.spec.luau`: работа клиента за кадр при 160 моделях;
- `strings.spec.luau`: словарь, русская таблица, надписи в мире.
