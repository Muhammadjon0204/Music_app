/// Audius API track JSON in the shape the real API returns (checked
/// against api.audius.co responses), with only the fields AURA reads plus
/// a few it must ignore. Names are invented.
Map<String, Object?> audiusTrackJson({
  String id = 'D7KyD',
  String? title = 'Ночной город',
  String? userName = 'Исполнитель',
  String handle = 'artist',
  int? duration = 185,
  bool streamable = true,
  bool accessStream = true,
  Object? streamConditions,
  bool deleted = false,
  bool deactivated = false,
  bool? available = true,
  String? permalink = '/artist/nochnoy-gorod-123',
  String? license = 'All rights reserved',
  Object? artwork = const {
    '150x150': 'https://node.example/content/abc/150x150.jpg',
    '480x480': 'https://node.example/content/abc/480x480.jpg',
    '1000x1000': 'https://node.example/content/abc/1000x1000.jpg',
    'mirrors': ['https://mirror.example'],
  },
  String? releaseDate = '2025-05-01T10:00:00Z',
}) => {
  'id': id,
  'title': title,
  'duration': duration,
  'permalink': permalink,
  'is_streamable': streamable,
  'is_delete': deleted,
  'is_available': available,
  'is_stream_gated': streamConditions != null,
  'stream_conditions': streamConditions,
  'access': {'stream': accessStream, 'download': false},
  'license': license,
  'release_date': releaseDate,
  'genre': 'Electronic',
  'play_count': 1234,
  'artwork': artwork,
  // Signed and short-lived: must never be used or stored.
  'stream': {
    'url': 'https://node.example/tracks/cidstream/x?signature=SECRET',
    'mirrors': <String>[],
  },
  'user': {
    'id': 'u1',
    'name': userName,
    'handle': handle,
    'is_deactivated': deactivated,
  },
};
