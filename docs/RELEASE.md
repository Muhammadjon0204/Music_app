# Выпуск в TestFlight

Сборка и загрузка идут в GitHub Actions на маке GitHub, поэтому свой Mac и
Xcode не нужны. Процесс `.github/workflows/testflight.yml` запускается
вручную: он собирает подписанную release-версию и сам загружает её в
App Store Connect.

Ниже — что нужно сделать один раз. Эти шаги может выполнить только
владелец аккаунта: они требуют входа, оплаты и согласия с условиями Apple.

## 1. Apple Developer Program

Подпишитесь на <https://developer.apple.com/programs/> (99 $ в год).
Без него TestFlight недоступен. Проверка аккаунта может занять до двух
дней.

**Team ID:** developer.apple.com → Account → Membership details →
Team ID (10 символов, например `ABCDE12345`).

## 2. Идентификатор приложения

В проекте стоит **`com.muhammadjon0204.musiclab`**. Его можно поменять до
шага 3: после создания приложения в App Store Connect он закрепляется
навсегда. Менять в `ios/Runner.xcodeproj/project.pbxproj`
(`PRODUCT_BUNDLE_IDENTIFIER`, три места для Runner и три для RunnerTests).

developer.apple.com → Certificates, Identifiers & Profiles → Identifiers →
**+** → App IDs → App → Bundle ID «Explicit»: `com.muhammadjon0204.musiclab`,
описание `MusicLab`. Отдельные возможности (Capabilities) не нужны: фоновое
воспроизведение включено в `Info.plist`.

## 3. Приложение в App Store Connect

<https://appstoreconnect.apple.com> → Apps → **+** → New App:

- Platforms: iOS
- Name: `MusicLab` (имя в App Store должно быть уникальным; если занято,
  например `MusicLab Player` — на телефоне всё равно будет «MusicLab»)
- Primary language: Russian
- Bundle ID: выбрать созданный на шаге 2
- SKU: `musiclab`

## 4. Ключ App Store Connect API

App Store Connect → Users and Access → Integrations → App Store Connect API
→ Team Keys → **+**:

- Name: `GitHub TestFlight`
- Access: **Admin** — нужен, чтобы сборка сама создавала сертификат и
  профиль подписи (облачная подпись).

Скачайте файл `AuthKey_XXXXXXXXXX.p8` — **скачать можно только один раз**.
Запишите **Key ID** и **Issuer ID** (над списком ключей).

Файл `.p8` — секрет: не кладите его в проект, в Git и в чаты.

## 5. Секреты в GitHub

GitHub → репозиторий → Settings → Secrets and variables → Actions →
New repository secret:

| Секрет | Что вставить |
| --- | --- |
| `APPLE_TEAM_ID` | Team ID из шага 1 |
| `ASC_KEY_ID` | Key ID из шага 4 |
| `ASC_ISSUER_ID` | Issuer ID из шага 4 |
| `ASC_API_KEY_P8` | всё содержимое файла `.p8`, включая строки `-----BEGIN PRIVATE KEY-----` и `-----END PRIVATE KEY-----` |
| `JAMENDO_CLIENT_ID` | client_id Jamendo (необязательно: без него каталог Jamendo не подключается) |

## 6. Сборка

GitHub → Actions → **TestFlight** → Run workflow → Run.

Занимает около 20–30 минут. Если какого-то секрета нет, процесс
остановится на первом шаге и назовёт его. Номер сборки — номер запуска,
он всегда растёт; версия (`1.0.0`) берётся из `pubspec.yaml`.

## 7. TestFlight

После загрузки Apple обрабатывает сборку ещё 10–30 минут, затем она
появляется в App Store Connect → приложение → TestFlight. Вопрос о
шифровании задавать не будет: в `Info.plist` указано, что приложение
использует только стандартный HTTPS (`ITSAppUsesNonExemptEncryption`).

- **Себе и команде** (до 100 человек из вашего аккаунта): TestFlight →
  Internal Testing → **+** → добавить себя. Проверка Apple не нужна.
- **Внешним тестировщикам** (по ссылке, до 10 000): External Testing.
  Первую сборку Apple проверяет (обычно до суток).

На iPhone установите приложение TestFlight из App Store и примите
приглашение.

## Что уже сделано в проекте

- Иконка (все размеры iOS и веб) и экран запуска в цветах приложения.
- `PrivacyInfo.xcprivacy`: без слежения и без сбора данных.
- Отображаемое имя `MusicLab`, фоновое воспроизведение, поддержка iPad.
- CI на каждый push собирает release-версию без подписи, чтобы ошибки
  release-сборки были видны до загрузки.

## Если что-то не получилось

- **No signing certificate / profile** — у ключа API не роль Admin, или
  Team ID не тот.
- **No suitable application records were found** — приложение не создано
  в App Store Connect (шаг 3) или Bundle ID отличается.
- **The bundle version must be higher** — такой номер сборки уже загружен;
  просто запустите процесс ещё раз (номер увеличится).
