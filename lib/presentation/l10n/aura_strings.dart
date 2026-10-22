/// User-facing Russian strings in one place, ready to move to ARB files when
/// a second language is added.
abstract final class AuraStrings {
  static const appName = 'AURA';

  static const tabHome = 'Главная';
  static const tabSearch = 'Поиск';
  static const tabLibrary = 'Библиотека';

  static const greetingMorning = 'Доброе утро';
  static const greetingDay = 'Добрый день';
  static const greetingEvening = 'Добрый вечер';
  static const greetingNight = 'Доброй ночи';
  static const homeSubtitle = 'Включи что-нибудь классное';

  static const demoBadge = 'Демо-данные';
  static const demoBadgeHint =
      'Пример оформления. Ваша музыка появится после импорта.';

  static const searchPlaceholder = 'Поиск музыки, исполнителей, альбомов';

  static const homeRecentlyAdded = 'Недавно добавленные';
  static const homeAlbums = 'Альбомы';
  static const homePlaylists = 'Плейлисты';
  static const homeEmptyTitle = 'Здесь появится ваша музыка';
  static const homeEmptyMessage =
      'Импортируйте свои аудиофайлы в разделе «Библиотека».';

  static const playlist = 'Плейлист';
  static const unknownArtist = 'Неизвестный исполнитель';

  static String trackCount(int count) =>
      '$count ${pluralRu(count, 'трек', 'трека', 'треков')}';

  static const loading = 'Загрузка…';
  static const retry = 'Повторить';

  static const searchHintTitle = 'Найдите музыку';
  static const searchHintMessage =
      'Поиск по вашей библиотеке заработает, когда в ней появится музыка.';
  static const searchHintMessageReady =
      'Ищите по названию трека, исполнителю или альбому.';
  static String searchNoResultsTitle(String query) =>
      'По запросу «$query» ничего не найдено';
  static const searchNoResultsMessage = 'Ваша библиотека пока пуста.';
  static const searchNoResultsInLibrary =
      'Попробуйте другое название, исполнителя или альбом.';

  static const libraryEmptyTitle = 'Библиотека пуста';
  static const libraryEmptyMessage =
      'Добавьте свои аудиофайлы из приложения «Файлы»: MP3, M4A, AAC, '
      'FLAC, WAV, AIFF. Файлы копируются в AURA и работают без интернета.';
  static const libraryEmptyMessageNoImport =
      'В этой версии нельзя добавить свои файлы: у браузера нет постоянного '
      'доступа к ним. Попробуйте демо-треки.';
  static const importMusic = 'Импортировать музыку';
  static const addDemoTracks = 'Добавить демо-треки';
  static String importProgress(int done, int total) =>
      'Импорт: $done из $total';
  static String importAdded(int count) => 'Добавлено: ${trackCount(count)}';
  static String importDuplicates(int count) =>
      'Уже были в библиотеке: ${trackCount(count)}';
  static String importFailed(int count) =>
      'Не удалось добавить: $count '
      '${pluralRu(count, 'файл', 'файла', 'файлов')}';
  static const importUnsupportedHint =
      'Поддерживаются MP3, M4A, AAC, FLAC, WAV, AIFF и CAF.';
  static const importNothingAdded = 'Новых треков нет';
  static const dismiss = 'Закрыть';
  static const libraryStorageWarning =
      'Не удалось открыть библиотеку на устройстве. Изменения не сохранятся '
      'после перезапуска.';

  static const favorites = 'Любимые треки';
  static const playlists = 'Плейлисты';
  static const albums = 'Альбомы';
  static const artists = 'Исполнители';
  static const allTracks = 'Вся музыка';
  static const recentlyAdded = 'Недавно добавленные';
  static const playAll = 'Слушать';
  static const shuffleAll = 'Перемешать';
  static const sortBy = 'Сортировка';
  static const sortTitle = 'По названию';
  static const sortArtist = 'По исполнителю';
  static const sortRecent = 'Сначала новые';
  static const cancel = 'Отмена';
  static const more = 'Ещё';
  static const favoriteTrack = 'Любимый трек';
  static const addToFavorites = 'Добавить в любимые';
  static const removeFromFavorites = 'Убрать из любимых';
  static const addToPlaylist = 'Добавить в плейлист';
  static const removeFromPlaylist = 'Убрать из плейлиста';
  static const removeFromLibrary = 'Удалить из библиотеки';
  static const removeFromLibraryConfirm =
      'Трек будет удалён из AURA вместе с копией файла. Оригинал в «Файлах» '
      'не затрагивается.';
  static const remove = 'Удалить';
  static const newPlaylist = 'Новый плейлист';
  static const playlistName = 'Название плейлиста';
  static const create = 'Создать';
  static const rename = 'Переименовать';
  static const save = 'Сохранить';
  static const deletePlaylist = 'Удалить плейлист';
  static const deletePlaylistConfirm =
      'Плейлист будет удалён. Треки останутся в библиотеке.';
  static const playlistNameInvalid =
      'Название не может быть пустым или длиннее 100 символов.';
  static const missingFile = 'Файл недоступен';
  static const missingFileMessage =
      'Копия этого трека больше не найдена на устройстве. Удалите его из '
      'библиотеки и импортируйте заново.';
  static const unknownAlbum = 'Неизвестный альбом';
  static const notFoundTitle = 'Не найдено';
  static const notFoundMessage = 'Возможно, это было удалено.';
  static const favoritesEmptyTitle = 'Нет любимых треков';
  static const favoritesEmptyMessage =
      'Нажмите на сердечко в плеере или в меню трека.';
  static const playlistEmptyTitle = 'Плейлист пуст';
  static const playlistEmptyMessage =
      'Добавьте треки через меню «Ещё» у любого трека.';
  static const playlistsEmptyTitle = 'Плейлистов пока нет';
  static const playlistsEmptyMessage =
      'Плейлисты хранятся только на этом устройстве.';
  static const albumsEmptyTitle = 'Альбомов пока нет';
  static const albumsEmptyMessage =
      'Альбомы появляются у треков с тегом «альбом».';
  static const artistsEmptyTitle = 'Исполнителей пока нет';
  static const artistsEmptyMessage =
      'Исполнители появляются у треков с тегом «исполнитель».';
  static const searchSectionTracks = 'Треки';
  static String playlistsCount(int count) =>
      '$count ${pluralRu(count, 'плейлист', 'плейлиста', 'плейлистов')}';
  static String artistsCount(int count) =>
      '$count ${pluralRu(count, 'исполнитель', 'исполнителя', 'исполнителей')}';
  static String albumsCount(int count) =>
      '$count ${pluralRu(count, 'альбом', 'альбома', 'альбомов')}';

  static const play = 'Воспроизвести';
  static const pause = 'Пауза';
  static const nextTrack = 'Следующий трек';
  static const previousTrack = 'Предыдущий трек';
  static const shuffle = 'Перемешать';
  static const repeatOff = 'Повтор: выключен';
  static const repeatAll = 'Повтор: вся очередь';
  static const repeatOne = 'Повтор: один трек';
  static const openPlayer = 'Открыть плеер';
  static const closePlayer = 'Свернуть плеер';
  static const queue = 'Очередь';
  static const nowPlaying = 'Сейчас играет';
  static const upNext = 'Далее';
  static const queueEnd = 'Больше треков в очереди нет';
  static const nothingPlayingTitle = 'Ничего не играет';
  static const nothingPlayingMessage = 'Выберите музыку, чтобы начать.';
  static const silentPlayback = 'Без звука';
  static const silentPlaybackHint =
      'Без звука: на этой платформе нет аудиодвижка, плеер только '
      'показывает интерфейс.';
  static const playbackPosition = 'Позиция воспроизведения';
  static String positionOf(String position, String total) =>
      '$position из $total';
  static String playPlaylist(String name) => 'Слушать «$name»';

  static const devGallery = 'Каталог компонентов (только для разработки)';
  static const back = 'Назад';

  static const failureFileTitle = 'Файл недоступен';
  static const failureFileMessage = 'Возможно, он был перемещён или удалён.';
  static const failureMediaTitle = 'Формат не поддерживается';
  static const failureMediaMessage = 'Этот файл не удаётся воспроизвести.';
  static const failurePermissionTitle = 'Нет доступа';
  static const failurePermissionMessage =
      'Разрешите доступ в настройках устройства.';
  static const failureNetworkTitle = 'Нет соединения';
  static const failureNetworkMessage =
      'Проверьте подключение к интернету и попробуйте снова.';
  static const failureStorageTitle = 'Ошибка хранилища';
  static const failureStorageMessage =
      'Не удалось прочитать или сохранить данные на устройстве.';
  static const failurePlaybackTitle = 'Не удалось воспроизвести';
  static const failurePlaybackMessage = 'Попробуйте другой трек.';
  static const failureUnexpectedTitle = 'Что-то пошло не так';
  static const failureUnexpectedMessage = 'Попробуйте ещё раз.';
}

/// Russian plural form: 1 трек, 2 трека, 5 треков, 11 треков, 21 трек.
String pluralRu(int count, String one, String few, String many) {
  final mod10 = count.abs() % 10;
  final mod100 = count.abs() % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
