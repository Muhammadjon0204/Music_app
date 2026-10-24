// SoundCloud's official embedded player for the current platform: a
// system web view on iOS/Android/macOS, an iframe on the web, nothing
// elsewhere (the screen then offers "Open in SoundCloud").
export 'widget_view/widget_view_stub.dart'
    if (dart.library.js_interop) 'widget_view/widget_view_web.dart'
    if (dart.library.io) 'widget_view/widget_view_io.dart';
