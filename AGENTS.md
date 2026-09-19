# Проект «Танчики» (tanks)

GitHub: https://github.com/aesblaze/tanks

Flutter-игра: танковая аркада-лабиринт с бесконечными уровнями.
Основной код лежит в `lib\` (`main.dart`, `game.dart`, `gamepad.dart`,
`records.dart`, `save.dart`).

## Как запустить

- На Windows: `flutter run -d windows`
- На Android: `flutter run` (телефон определится сам)

## Как собрать

- Windows: `flutter build windows --release`
  готовый файл: `build\windows\x64\runner\Release\tanks.exe`
- Android APK: `flutter build apk --release` (отладочный — `--debug`)
  готовый файл: `build\app\outputs\flutter-apk\app-release.apk`

## Проверка проекта

- `flutter analyze` — без ошибок;
- `flutter test` — тесты проходят;
- `flutter build apk --debug` — APK собирается.

## Android-окружение

- Android SDK, platform-tools и NDK настроены, лицензии приняты.
- Java и Gradle версии совместимы, проект собирается без правок.
- Если Gradle ругается на путь с русскими буквами, в `android\gradle.properties`
  нужна строка `android.overridePathCheck=true`.

## Скриншоты для README

Лежат в `screenshots\` (`menu.png`, `game.png`). Делаются запуском игры
и снятием окна, в код игры не входят.
