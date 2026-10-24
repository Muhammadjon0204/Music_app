import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_player_controller.dart';
import 'package:music_app/integrations/soundcloud/widget_view/bridge_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// iOS, Android and macOS have a system web view; Windows and Linux do not.
bool get soundCloudWidgetSupported =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.android ||
      TargetPlatform.macOS => true,
      _ => false,
    };

Widget buildSoundCloudWidget({
  required SoundCloudLink link,
  required SoundCloudPlayerController controller,
}) => _WebViewWidget(link: link, controller: controller);

class _WebViewWidget extends StatefulWidget {
  const _WebViewWidget({required this.link, required this.controller});

  final SoundCloudLink link;
  final SoundCloudPlayerController controller;

  @override
  State<_WebViewWidget> createState() => _WebViewWidgetState();
}

class _WebViewWidgetState extends State<_WebViewWidget> {
  late final WebViewController _web = _create();

  WebViewController _create() {
    // Inline playback that AURA's own buttons may start (no extra tap
    // inside the web view).
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    final web = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'AuraBridge',
        onMessageReceived: (m) => widget.controller.handleMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          // The page stays on the widget; links inside it do not take
          // over the app (AURA offers "Open in SoundCloud" instead).
          onNavigationRequest: (request) =>
              request.isMainFrame && !request.url.startsWith('about:')
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
        ),
      );
    if (web.platform case final AndroidWebViewController android) {
      unawaited(android.setMediaPlaybackRequiresUserGesture(false));
    }
    return web;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.send = (command) => unawaited(
      _web.runJavaScript('window.auraCommand(${jsonEncode(command)})'),
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    final page = await loadBridgePage(widget.link);
    await _web.loadHtmlString(page, baseUrl: 'https://aura.invalid/');
  }

  @override
  void dispose() {
    widget.controller.send = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
