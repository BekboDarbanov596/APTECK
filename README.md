# Аптека рядом

Мобильное приложение (Flutter) для граждан: где в Бишкеке есть лекарство и сколько оно стоит.

## Что есть

- Карта на весь экран (OpenStreetMap) с аптеками; метки «падают» с 3D-переворотом,
  камера плавно перелетает к результатам.
- Поиск лекарства: по названию, действующему веществу, латиницей, с опечатками и падежами;
  голосовой ввод.
- Шторка со списком аптек: цена, расстояние, открыто/закрыто, сортировка «Ближе / Дешевле».
- Фильтры: «только открытые», по аптечной сети.
- Карточка аптеки: часы, адрес, «Позвонить», «Маршрут», что ещё есть в наличии.
- Ассистент: где есть лекарство, где дешевле, аналоги. По симптомам не советует.
- Избранное и история поиска (хранятся на телефоне).

## Данные — демо

`assets/demo_data.json` генерирует `tool/generate_demo_data.js`:
названия, МНН и рецептурность настоящие; цены и наличие — примерные; координаты аптек — приблизительные;
телефонов нет (чтобы не звонить чужим людям). В приложении это помечено «Демо-данные».

Firebase пока не подключён: экраны берут данные через `CatalogRepository`
(`lib/data/catalog_repository.dart`). Для Firebase нужно создать проект, выполнить
`flutterfire configure` и добавить `FirestoreCatalogRepository` с тем же интерфейсом.

## Запуск

```bash
flutter pub get
flutter run
```

Пересобрать демо-данные: `node tool/generate_demo_data.js`.

### Если путь содержит кириллицу или пробелы (Windows)

`flutter analyze` падает на кириллице в пути, а `flutter test` и сборка — на пробеле в пути к SDK.
Обход: открыть проект через ссылку и короткие пути, например

```powershell
New-Item -ItemType Junction -Path C:\Users\<user>\apteka_dev -Target "<путь к apteka_ryadom>"
cd C:\Users\BEKBOO~1\APTEKA~1
C:\Users\BEKBOO~1\develop\flutter\bin\flutter.bat test
```

Надёжнее — перенести проект и Flutter SDK в папки без пробелов и кириллицы (например `C:\dev`).

Если после `flutter build web` открывается белый экран — в `build/web` пропали файлы
(сбой кэша инкрементальной сборки). Помогает `flutter clean`, затем снова `flutter build web`.

### Показ в рамке телефона

После `flutter build web` запустите `node tool/serve_web.js` и откройте
http://localhost:8091/phone.html — приложение внутри макета телефона (удобно для встреч).

## Проверки

```bash
flutter analyze
flutter test
```


### Ознакомительное видео

Блок на главном экране: `lib/ui/widgets/intro_video_card.dart`.
Пока ролик не задан, кнопка открывает краткую инструкцию из трёх шагов.
Для своего MP4 положите файл в `web/videos/intro.mp4` и соберите:

```powershell
flutter build web --dart-define=INTRO_VIDEO_URL=videos/intro.mp4
```

Можно передать полный HTTPS URL вместо пути. В веб-версии видео открывается
в модальном окне с управлением, звуком и полноэкранным режимом браузера,
без автозапуска. На мобильных платформах используйте полный HTTPS URL:
ролик открывается системным приложением. Сам видеофайл в проект не включён.

## Вход и регистрация (Firebase Authentication)

Экраны: `lib/ui/auth/` (вход, регистрация, карточка «Аккаунт» в профиле),
логика: `lib/auth/auth_service.dart`. Способы входа: почта + пароль и Google.

Пока Firebase-проект не подключён, `lib/firebase_options.dart` — заглушка:
приложение работает, а экраны входа показывают «Вход пока не подключён».

### Подключение (один раз)

1. https://console.firebase.google.com → создать проект.
2. Authentication → Sign-in method → включить **Email/Password** и **Google**.
3. Установить инструменты и войти в свой аккаунт Google:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
4. В папке проекта: `flutterfire configure` → выбрать проект и платформы
   android, ios, web. Команда перезапишет `lib/firebase_options.dart`
   и добавит `android/app/google-services.json`.
5. Для Google-входа на Android добавить SHA-1 ключа подписи:
   `cd android && ./gradlew signingReport` → Firebase → Настройки проекта →
   Android-приложение → «Добавить отпечаток», затем снова `flutterfire configure`.
6. Веб: `localhost` разрешён по умолчанию; для своего домена —
   Authentication → Settings → Authorized domains.
