# Публикация приложения через сайт GitHub

GitHub Actions автоматически собирает установочные файлы после публикации Release. Локально собирать приложение и загружать файлы релиза вручную не требуется.

## 1. Создание репозитория

1. Откройте <https://github.com/new>.
2. Введите имя `Alweng-Spotlight`.
3. Выберите **Public**.
4. Не включайте создание README, `.gitignore` и License — эти файлы уже есть в проекте.
5. Нажмите **Create repository**.
6. На странице пустого репозитория выберите **uploading an existing file**.
7. В Finder нажмите **Command–Shift–.**, чтобы увидеть скрытые файлы. Загрузите содержимое папки проекта, обязательно включая `.github`, `.gitattributes` и `.gitignore`. Не загружайте `.git`, `.build`, `dist` и `.DS_Store`.
8. В поле commit message укажите `Initial release` и сохраните изменения в ветку `main`.

После загрузки откройте вкладку **Actions**. Workflow **Build and release** должен завершиться зелёной отметкой.

## 2. Создание Release 1.0.0

1. Откройте справа **Releases** → **Draft a new release**.
2. Нажмите **Choose a tag** → **Create new tag**.
3. Введите тег `v1.0.0`, target — `main`.
4. Название релиза: `Spotlight English 1.0.0`.
5. Нажмите **Generate release notes** и при необходимости поправьте текст.
6. Нажмите **Publish release**.
7. Перейдите во вкладку **Actions** и дождитесь завершения **Build and release**.

Workflow автоматически прикрепит к опубликованному Release:

- `Spotlight-English-v1.0.0.dmg` — основная установка перетаскиванием в Applications;
- `Spotlight-English-v1.0.0.zip` — альтернативный архив;
- `SHA256SUMS.txt` — контрольные суммы файлов.

## 3. Что увидит пользователь

1. Скачать `.dmg` из раздела Releases.
2. Открыть образ и перетащить **Spotlight English.app** в **Applications**.
3. При первом запуске нажать приложение с удержанием Control, выбрать **Open** и подтвердить запуск.
4. Разрешить приложение в **System Settings → Privacy & Security → Accessibility**.
5. При необходимости добавить приложение в **System Settings → General → Login Items**.

Шаг с Control-click требуется потому, что бесплатная сборка не notarized. Полностью обычный запуск двойным кликом без предупреждения Gatekeeper требует участия в Apple Developer Program, сертификата Developer ID и notarization через Apple.

## Следующие версии

Перед следующим релизом измените версию в `Resources/Info.plist`, обновите `CHANGELOG.md` и создайте на GitHub соответствующий тег. Например, версии `1.1.0` соответствует тег `v1.1.0`.
