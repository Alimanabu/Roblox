# 🧠 Brainrot Factory 🤌

Roblox-симулятор: строишь фабрику мемов, кидаешь в машину мем-капсулы и создаёшь
оригинальных брейнрот-существ. Они стоят на твоей базе и приносят монеты.

**Главное правило игры: чем популярнее тренд, тем реже он выпадает.**
Нормис → Лоу-ки → Ризз → Сигма → Аура → Скибиди → Брейнрот Бог → **SIX SEVEN 🤌**

Подробный дизайн игры: [docs/DESIGN.md](docs/DESIGN.md).
Идеи следующих игр: [docs/IDEAS.md](docs/IDEAS.md).
Как проверить игру в Studio: [docs/TESTING.md](docs/TESTING.md).

## Как запустить

1. Установи [Rokit](https://github.com/rojo-rbx/rokit) и выполни `rokit install`, чтобы поставить Rojo.
   Или поставь Rojo любым другим способом.
2. Установи плагин Rojo в Roblox Studio.
3. В папке проекта запусти `rojo serve`.
4. В Studio открой пустой Baseplate, в плагине Rojo нажми **Connect**.
5. Нажми **Play**.

Собрать файл игры без Studio: `rojo build -o BrainrotFactory.rbxl`.

### Перед публикацией

- **Game Settings → Security → Enable Studio Access to API Services**. Без этого в Studio
  прогресс не сохраняется (игра работает, но без сохранений).
- **Max Players = 8**: на карте 8 баз.
- Создай геймпассы и продукты в Creator Dashboard и впиши их ID в
  `src/shared/Config/Monetization.luau`. Пока ID = 0, в магазине кнопка «Скоро».

### Перевод на другие языки 🌍
Вся игра на русском, но Roblox умеет переводить её сам:
1. Creator Dashboard → твоя игра → **Localization** → Settings: исходный язык **Russian**.
2. Включи **Automatic Text Capture** и **Automatic Translation** для нужных языков
   (английский, испанский, португальский — самые большие аудитории Roblox).
3. Тексты интерфейса соберутся сами, пока люди играют. Перевод можно поправить вручную там же.

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
tests/                    проверки баланса и формул
docs/                     DESIGN (дизайн), TESTING (чек-лист), IDEAS (идеи других игр)
```

Почти всё, что хочется поменять (цены, шансы, коды, скины, звуки), лежит в
`src/shared/Config/`. Код трогать не нужно.

## Тесты

Нужен [Luau CLI](https://github.com/luau-lang/luau/releases):

```
python3 tests/run.py path/to/luau
```

Тесты проверяют, что шансы складываются в 100% и редкие тренды действительно реже.
Ещё они симулируют 6 часов игры и печатают, когда игрок открывает капсулы, редкости
и перерождения.
