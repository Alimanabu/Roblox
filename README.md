# 🧠 Brainrot Factory 🤌

Roblox-симулятор: строишь фабрику мемов, кидаешь в машину мем-капсулы и создаёшь
оригинальных брейнрот-существ. Они стоят на твоей базе и приносят монеты.

**Главное правило игры: чем популярнее тренд, тем реже он выпадает.**
Нормис → Лоу-ки → Ризз → Сигма → Аура → Скибиди → Брейнрот Бог → **SIX SEVEN 🤌**

Подробный дизайн игры: [docs/DESIGN.md](docs/DESIGN.md).
Идеи следующих игр: [docs/IDEAS.md](docs/IDEAS.md).

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

## Структура

```
src/
  shared/                 -> ReplicatedStorage.Shared (общий код)
    Config/               все цифры игры: редкости, брейнроты, капсулы, уровни...
    Util/Formulas.luau    вся игровая математика (шансы, доход, удача)
    Util/Format.luau      красивые числа ($1.5K, 2.3M)
    Remotes.luau          сетевые события
  server/                 -> ServerScriptService.Server
    Main.server.luau      запуск сервера
    Services/             данные, фабрика, доход, уровни, базы, донат
  client/                 -> StarterPlayerScripts.Client
    Main.client.luau      запуск клиента, анимации
    Ui/                   интерфейс (создаётся кодом)
tests/                    проверки баланса и формул
```

Чтобы поменять баланс, достаточно править файлы в `src/shared/Config/`.

## Тесты

Нужен [Luau CLI](https://github.com/luau-lang/luau/releases):

```
python3 tests/run.py path/to/luau
```

Тесты проверяют, что шансы складываются в 100% и редкие тренды действительно реже.
Ещё они симулируют 6 часов игры и печатают, когда игрок открывает капсулы, редкости
и перерождения.
