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

  static const homeRecentlyPlayed = 'Недавно прослушанное';
  static const homeAlbums = 'Альбомы';
  static const homePlaylists = 'Плейлисты';
  static const homeEmptyTitle = 'Здесь появится ваша музыка';
  static const homeEmptyMessage =
      'Импорт музыки будет добавлен в следующей версии приложения.';

  static const playlist = 'Плейлист';
  static const unknownArtist = 'Неизвестный исполнитель';

  static String trackCount(int count) =>
      '$count ${pluralRu(count, 'трек', 'трека', 'треков')}';

  static const loading = 'Загрузка…';
  static const retry = 'Повторить';

  static const searchHintTitle = 'Найдите музыку';
  static const searchHintMessage =
      'Поиск по вашей библиотеке заработает, когда в ней появится музыка.';
  static String searchNoResultsTitle(String query) =>
      'По запросу «$query» ничего не найдено';
  static const searchNoResultsMessage = 'Ваша библиотека пока пуста.';

  static const libraryEmptyTitle = 'Библиотека пуста';
  static const libraryEmptyMessage =
      'Здесь появятся ваши треки, альбомы и плейлисты. '
      'Импорт музыки будет добавлен в следующей версии.';

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
  static const demoPlayback = 'Демо · без звука';
  static const demoPlaybackHint =
      'Демо-плеер без звука: показывает интерфейс до подключения '
      'аудиодвижка.';
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
